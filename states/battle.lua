-- Battle state: reached when the player engages a combat encounter on the overworld
-- (states/game.lua -> game:openEncounter). It builds an 8x8 arena from the quest's
-- biome (models/arena.lua), placing the party on the near side and the encounter's
-- prestige-scaled enemy roster on the far side, then drives a live models/combat.lua
-- timeline: units act in turn order (lowest `time` first), the player moves/acts the
-- current party unit, and enemies act via Combat.planEnemyAction. Victory/defeat come
-- from Combat.evaluate, firing the overworld-supplied onWin/onLoss.
--
-- Player interaction (mouse + keyboard + gamepad, per the project standard):
--   * A party unit's turn defaults to MOVE mode: blue reachable tiles are shown; picking
--     one moves the unit and ends its turn. Hovering a tile previews the turn order.
--   * Selecting an item (click a slot / number key / gamepad Y) ARMS it: its range is shown
--     in red. Confirming on a valid target resolves it; re-selecting the item cancels.
--   * Forfeit button / Esc / gamepad B (when not armed) = concede the battle (a loss).
--   * F5 saves the current arena to data/arenas/ for hand-editing (dev only).

local Scale = require("scale")
local InputMode = require("input_mode")
local Arena = require("models.arena")
local BattleMap = require("ui.battle_map")
local CombatPanel = require("ui.combat_panel")
local CombatFx = require("ui.combat_fx")
local CombatLog = require("ui.combat_log")
local StatusTooltip = require("ui.status_tooltip")
local ItemTooltip = require("ui.item_tooltip")
local TileTooltip = require("ui.tile_tooltip")
local ActionPreview = require("ui.action_preview")
local Character = require("models.character")
local Combat = require("models.combat")
local Trap = require("models.trap")
local Hazard = require("models.hazard")
local Status = require("models.status")
local EncounterModel = require("models.encounter")

local battle = {}

local titleFont = love.graphics.newFont(22)
local hudFont = love.graphics.newFont(16)
local hintFont = love.graphics.newFont(13) -- control hint: smaller so it fits on one line above the board

local PANEL_W = CombatPanel.WIDTH
-- A left column, mirroring the right combat panel, that houses the buttons and the docked
-- tooltips (see drawLeftColumn). The board is centred in the gap between the two columns.
-- Slimmer than the right panel (it only holds buttons + a tooltip), to give the board room.
local LEFT_W = 264
local BOARD_TILE = 60 -- on-screen tile size (< the arena's logical 64), for breathing room
local BOARD_TOP = 104 -- fixed board top (below the 3-line HUD); the freed bottom holds the log
local AI_DELAY = 0.35 -- seconds between enemy actions, so each move is watchable
-- Seconds a walking unit rests on every tile it steps onto, the destination included. A move is
-- played out one tile at a time (see startWalk) rather than teleporting, so the route a unit takes
-- is visible -- and so is what it walks into, since a trap springs or a hazard bites on the very
-- beat the unit lands on that tile. Applies to both sides.
local MOVE_STEP = 0.25
-- Minimum beat held after an action that actually landed a hit (dealt damage, healed, or felled a
-- unit) before the turn hands off, so the strike and its aftermath read. The hold runs until BOTH
-- this has elapsed AND the sprite reactions have finished (battle.fx:busy); a turn that changed
-- nothing visible (a bare move, a wait) skips it entirely and hands off at once.
local IMPACT_PAUSE = 0.5

-- Clickable "Forfeit" button so a mouse-only player can bail out (counts as a loss). Wait/Focus/
-- Defend is not here: it lives in a long button under the item grid (ui/combat_panel.lua).
local forfeitButton = { x = 16, y = 16, w = 130, h = 36 }
-- Toggles the combat-log panel on the left (also L / gamepad left-shoulder).
local logButton = { x = 16, y = 60, w = 130, h = 36 }
-- Toggles the danger overlay that paints EVERY enemy's reach-and-strike range purple across the
-- whole board (also T / gamepad left-stick), so the player can survey all threats at once.
local rangesButton = { x = 16, y = 104, w = 130, h = 36 }

-- The 3x3 item grid mapped onto the number KEYPAD by physical position: kp7 is the top-left slot,
-- kp3 the bottom-right, matching the grid's row-major layout so the keys sit where the slots do.
-- kp0, the top-row 0, and Space are all the Wait action. (The top-row 1-9 keys still arm slots 1-9 in order.)
local KEYPAD_SLOT = {
    kp7 = 1, kp8 = 2, kp9 = 3,
    kp4 = 4, kp5 = 5, kp6 = 6,
    kp1 = 7, kp2 = 8, kp3 = 9,
}

local function pointIn(btn, x, y)
    return x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h
end

-- Whether an item carries a given tag (Combat's own hasTag is private). Used by the context cursor
-- to tell a physical strike ("physical") from a spell ("magical").
local function itemHasTag(item, want)
    local tags = item and item.tags
    if not tags then return false end
    for _, t in ipairs(tags) do
        if t == want then return true end
    end
    return false
end

local function charName(id)
    local def = id and Character.defs[id]
    return (def and def.name) or id or "the target"
end

-- Human-readable objective line for the HUD. `protect` is a loss condition layered over
-- whatever the win type is, so it reads as a second clause rather than replacing the first.
local function objectiveText(obj)
    local text
    if obj.type == "survive" then
        text = "Objective: survive " .. (obj.turns or "?") .. " turns"
    elseif obj.type == "assassinate" then
        text = "Objective: defeat " .. charName(obj.target)
    else
        text = "Objective: defeat all enemies"
    end
    if obj.protect then
        text = text .. " -- " .. charName(obj.protect) .. " must survive"
    end
    return text
end

-- Resolve the encounter's composition spec + objective. Placed encounters read their
-- blueprint; the objective tile reads the quest's `map.objective`.
local function specFor(opts, partyIds, seed)
    local spec = { biome = opts.biome, party = partyIds, seed = seed }
    local enc = opts.encounter or {}
    if enc.kind == "objective" then
        local obj = (opts.quest and opts.quest.map and opts.quest.map.objective) or {}
        spec.composition = obj.composition
        spec.allies = obj.allies -- AI-run escorts fighting on the party's side
        spec.objective = obj.win -- { type, target, protect } win condition; nil -> killAll
    else
        local def = enc.id and EncounterModel.get(enc.id)
        spec.composition = def and def.composition
        spec.allies = def and def.allies
        spec.objective = def and def.objective
    end
    return spec
end

-- ---------------------------------------------------------------------------
-- Combat controller (all module-level locals so they close over `battle`; declared
-- before battle.enter so its panel callbacks can reference them as upvalues).
-- ---------------------------------------------------------------------------

-- Release the between-battle leftovers every surviving party member carries out of the fight (mana
-- reservations, summon claims), so the overworld reads a clean roster: no item tooltip still crying
-- "is still on the field" over a creature that left with the battlefield. Combat.new does this too as
-- it rebuilds the grid, but that only fires when the NEXT battle opens -- too late for the hub in
-- between. Both sides do it on the way out so a loss (a forfeit, a wipe of all but a summon) is clean too.
local function releaseParty()
    for _, unit in ipairs(battle.combat.units) do
        if unit.side == "party" then Combat.releaseClaims(unit.char) end
    end
end

local function win()
    battle.over = true
    battle.walk = nil -- nobody finishes their stroll once the battle is decided
    Combat.logEvent(battle.combat, "system", "Victory!")
    releaseParty()
    if battle.onWin then battle.onWin() end
end

local function lose()
    battle.over = true
    battle.walk = nil
    Combat.logEvent(battle.combat, "system", "Defeat.")
    releaseParty()
    if battle.onLoss then battle.onLoss() end
end

-- Reachable tiles for the current unit (blue move highlights + move validity). A rooted unit
-- (a movement-blocking status) can't move this turn, so its reachable set is empty -- it can
-- still attack from where it stands.
local function computeReachable(unit)
    if Status.blocksMove(unit) then
        battle.reachable, battle.moveCells = {}, {}
        battle.blinking = false
        return
    end
    -- An armed, affordable Blink turns the move set into a teleport diamond (ignoring terrain and
    -- obstacles); otherwise it is the ordinary walk. battle.blinking drives the confirm/preview path
    -- and lets the overlay read as a jump rather than a stroll.
    local blink = Combat.blinkReady(unit)
    if blink then
        battle.blinking = true
        battle.reachable = Combat.teleportCells(battle.combat, unit, blink.movement)
    else
        battle.blinking = false
        battle.reachable = Combat.reachable(battle.combat, unit)
    end
    local cells = {}
    for _, node in pairs(battle.reachable) do
        cells[#cells + 1] = { x = node.x, y = node.y }
    end
    battle.moveCells = cells
end

-- The route the current unit will walk to the cursor tile: `battle.movePath = { cells, cost }`, or
-- nil when the cursor isn't a plain walk target. Built Advance-Wars style so the player can STEER
-- among the many routes to a tile: as the cursor steps to a reachable neighbour of the route's end
-- the route extends onto it (the "last touched tile" becomes a waypoint), and stepping back onto an
-- earlier tile trims the route to there. A deliberate detour is allowed as far as the movement budget
-- stretches (Combat.planMoveVia caps it) and is charged its full cost. Anything the trail can't
-- absorb -- a cursor JUMP (fast mouse flick, non-adjacent), an over-budget extension, a revisit --
-- rebuilds the plain shortest path (Combat.planMove), so the preview always shows a legal walk.
local function updateMovePath(unit)
    local cx, cy = battle.map.cursor.x, battle.map.cursor.y
    -- Only a walked move draws a route: not a blink (a teleport has none), and standing still isn't
    -- a move.
    if battle.blinking or (cx == unit.x and cy == unit.y) then
        battle.movePath = nil
        return
    end
    -- The cursor must be a reachable tile to STEER the route to it. When it isn't: in armed mode the
    -- player has steered the approach and moved the cursor onto a foe to aim (or onto a tile out of
    -- move range) -- keep the drawn route so its endpoint stays the tile the strike fires from. In
    -- move mode an off-set cursor just clears the route.
    if not (battle.reachable and battle.reachable[cx .. "," .. cy]) then
        if battle.mode ~= "armed" then battle.movePath = nil end
        return
    end

    -- Try to reuse the existing route: trim if the cursor is on it, extend if it's adjacent to the end.
    local prev = battle.movePath and battle.movePath.cells
    local candidate
    if prev then
        local hit
        for i, c in ipairs(prev) do if c.x == cx and c.y == cy then hit = i break end end
        if hit then
            candidate = {}
            for i = 1, hit do candidate[i] = prev[i] end
        else
            local last = prev[#prev]
            if math.abs(last.x - cx) + math.abs(last.y - cy) == 1 then
                candidate = {}
                for i = 1, #prev do candidate[i] = prev[i] end
                candidate[#candidate + 1] = { x = cx, y = cy }
            end
        end
    end

    local plan = candidate and Combat.planMoveVia(battle.combat, unit, candidate)
    plan = plan or Combat.planMove(battle.combat, unit, cx, cy)
    battle.movePath = plan and { cells = plan.path, cost = plan.cost } or nil
end

-- The steered route, only when it actually ends on (x, y) -- so a caller reading it for a specific
-- cell (confirm, the action preview) never picks up a route built for a different tile.
local function movePathTo(x, y)
    local mp = battle.movePath
    if not mp then return nil end
    local last = mp.cells[#mp.cells]
    if last.x == x and last.y == y then return mp end
    return nil
end

-- The tile a steered route commits the unit to standing on -- the end of the drawn move route
-- (battle.movePath) plus that route, or nil when none is drawn. In armed mode this is the tile the
-- player has steered to, and the one an ensuing strike should fire FROM (see armedActionAt).
local function steeredStand()
    local mp = battle.movePath
    if not mp then return nil end
    return mp.cells[#mp.cells], mp
end

-- Can `unit`, standing on (sx, sy), legally land `ab` / `item` on the target cell (tx, ty)? The same
-- per-stand-tile test Combat.attackReach applies -- base range + the item's grid-adjacency bonus +
-- the stand tile's own field range bonus, clamped below by the ability's min range and gated on line
-- of sight when it needs it -- pulled out so a SPECIFIC stand tile (the steered route's endpoint) can
-- be checked, not just the cheapest one attackReach records. Combat.useItem re-validates on confirm.
local function standCanHit(unit, ab, item, sx, sy, tx, ty)
    local r = (ab.range or 1) + Combat.adjacencyRangeBonus(unit.char, item)
        + (Combat.fieldBonus(battle.combat, sx, sy).range or 0)
    local d = math.abs(sx - tx) + math.abs(sy - ty)
    if d < Combat.abilityMinRange(ab) or d > r then return false end
    if ab.requiresSight and not Combat.hasLineOfSight(battle.combat, sx, sy, tx, ty) then return false end
    return true
end

-- The armed ability's valid-to-hit AREA (red for offensive, green for support): every tile the
-- ability could legally land on this turn -- moving first if needed, so the reach is the WALK-AND-
-- STRIKE band (Combat.attackReach), not just what it hits from the tile it stands on now. In range
-- from some reachable stand tile, walkable (never a wall), and in line of sight (from that stand
-- tile) when the ability needs it. A tile it CAN'T validly hit is dropped, so the highlight stops at
-- cover and never falls on a unit of the wrong kind (an ally under an enemy strike, a foe under a
-- support cast). A tile-target ability (e.g. summoning a trap) additionally needs an empty cell; a
-- self-only ability can land only on the caster's own tile. `battle.rangeReach` records the cheapest
-- stand tile per cell (like the default action's attackReach) so confirm can walk there and cast.
-- Combat.useItem re-checks all of this on confirm.
local function computeRange(unit, item)
    local ab = item.activeAbility
    local target = ab and ab.target
    battle.rangeReach = {}
    -- A self-only ability can only ever land on the caster's own tile (no walk).
    if target == "self" then
        battle.rangeCells = { { x = unit.x, y = unit.y } }
        battle.rangeReach[unit.x .. "," .. unit.y] =
            { x = unit.x, y = unit.y, fromX = unit.x, fromY = unit.y, moveCost = 0 }
        return
    end
    -- Base range (grid-adjacency bonus folded in); attackReach adds each stand tile's own terrain
    -- range bonus, so pass the raw base rather than Combat.abilityRange (which bakes in the CURRENT
    -- tile's field bonus and would double-count it). Blink is a teleport, not a walk-and-strike set,
    -- so it reaches only from the current tile.
    local range = ((ab and ab.range) or 1) + Combat.adjacencyRangeBonus(unit.char, item)
    local minRange = Combat.abilityMinRange(ab)
    local requiresSight = ab and ab.requiresSight
    local reachForRange = battle.blinking and {} or battle.reachable
    local reach = Combat.attackReach(battle.combat, unit, range, reachForRange, requiresSight, minRange)
    local cells = {}
    for k, cell in pairs(reach) do
        -- Drop cells the ability can't validly land on: a tile cast needs an empty cell; a unit-target
        -- cast can't hit a unit of the wrong side (an empty tile still shows, so the reach reads even
        -- with no one standing in it).
        local occ = Combat.unitAt(battle.combat, cell.x, cell.y)
        local valid
        if target == "tile" then valid = occ == nil or ab.allowOccupied == true
        elseif occ and target == "enemy" then valid = occ.side ~= unit.side
        elseif occ and target == "ally" then valid = occ.side == unit.side
        else valid = true end
        if valid then
            cells[#cells + 1] = { x = cell.x, y = cell.y }
            battle.rangeReach[k] = cell
        end
    end
    battle.rangeCells = cells
end

-- The blast footprint an AoE ability would cover if fired at cell (cx, cy): the cells
-- Combat.aoeCells returns for the armed/hovered ability, or nil for a single-target ability or a
-- cell that isn't a legal aim point. Drives the brighter red/green area highlight (ui/battle_map)
-- that previews exactly what an AoE cast sweeps as the cursor moves over the board.
local function aoeFootprint(item, cx, cy)
    local ab = item and item.activeAbility
    if not (ab and ab.aoe) then return nil end
    -- Only preview the blast on a legal aim cell (membership in the pre-computed valid range set),
    -- so the footprint never implies a shot the unit can't actually take.
    local onTarget = false
    for _, c in ipairs(battle.rangeCells or {}) do
        if c.x == cx and c.y == cy then onTarget = true break end
    end
    if not onTarget then return nil end
    return Combat.aoeCells(battle.combat, ab, cx, cy, battle.current)
end

-- The default-ACTION reach: every cell the unit could use its default action on this turn (the
-- player-chosen action, Combat.defaultAction -- a strike, a heal, a summon), moving first if needed.
-- Stores `battle.defaultAction` + `battle.attackReach` (cell -> cheapest stand tile, which spans the
-- whole reach and drives click-to-use pathing), `battle.defaultSupport` (a friendly action, so the
-- band reads green not red), and `battle.threatCells`, the highlight = the reach band beyond movement,
-- keeping only cells the action can VALIDLY land on: for a strike, drop the caster's own tile and any
-- ally; for a support action, drop the caster and any foe (empty cells in range still show either way,
-- so the reach reads even with no target on it). Tiles inside the blue move band are left to the blue
-- overlay so the two never stack into a muddy overlap. Reads the live `battle.reachable`, so once the
-- unit has moved (reachable cleared) only what it can reach from where it now stands shows.
local function computeThreat(unit)
    local action = Combat.defaultAction(unit.char)
    battle.defaultAction = action
    local ab = action and action.activeAbility
    local support = ab ~= nil and Combat.isSupportAbility(ab)
    battle.defaultSupport = support
    local range = ((ab and ab.range) or 1) + Combat.adjacencyRangeBonus(unit.char, action)
    -- While Blink is armed the move set is a teleport diamond, which is NOT a set of walk-and-strike
    -- stand tiles (click-to-use folds a WALK into the approach). So reach only from the current tile:
    -- the mage blinks OR acts from where it stands, it does not walk-then-act.
    local reachForThreat = battle.blinking and {} or battle.reachable
    battle.attackReach = Combat.attackReach(battle.combat, unit, range, reachForThreat,
        ab and ab.requiresSight, Combat.abilityMinRange(ab))

    local moveKeys = {}
    for _, c in ipairs(battle.moveCells) do moveKeys[c.x .. "," .. c.y] = true end

    local cells = {}
    for k, cell in pairs(battle.attackReach) do
        -- Show the reach, minus tiles already lit blue (the move band), the caster's own tile, and any
        -- occupant of the wrong side for this action (a friend can't be struck; a foe can't be healed).
        if not moveKeys[k] and not (cell.x == unit.x and cell.y == unit.y) then
            local occ = Combat.unitAt(battle.combat, cell.x, cell.y)
            local wrongSide = occ and (support and occ.side ~= unit.side or not support and occ.side == unit.side)
            if not wrongSide then
                cells[#cells + 1] = { x = cell.x, y = cell.y }
            end
        end
    end
    battle.threatCells = cells
end

-- The reach a single unit threatens THIS turn with its default weapon: its walk-and-strike band,
-- split (like computeThreat) into the movement tiles and the attack tiles beyond them. Powers the
-- "hover a unit to read its range" preview (Fire Emblem / Triangle Strategy): the inspected unit's
-- own movement (orange) + attack reach (crimson), computed on demand and cached against the unit it
-- was built for (battle.inspectFor) so it isn't rebuilt every frame. Pass nil to clear.
local function computeInspect(unit)
    battle.inspectFor = unit
    battle.inspectMoveCells = {}
    battle.inspectRangeCells = {}
    if not unit then return end
    local reachable = Status.blocksMove(unit) and {} or Combat.reachable(battle.combat, unit)
    local moveKeys = {}
    for k, node in pairs(reachable) do
        battle.inspectMoveCells[#battle.inspectMoveCells + 1] = { x = node.x, y = node.y }
        moveKeys[k] = true
    end
    local weapon = Combat.defaultWeapon(unit.char)
    local ab = weapon and weapon.activeAbility
    local range = (ab and ab.range) or 1
    local reach = Combat.attackReach(battle.combat, unit, range, reachable,
        ab and ab.requiresSight, Combat.abilityMinRange(ab))
    for k, cell in pairs(reach) do
        -- The attack band is what it can hit BEYOND where it can stand -- the move tiles are their
        -- own overlay, and its own tile isn't a strike target.
        if not moveKeys[k] and not (cell.x == unit.x and cell.y == unit.y) then
            battle.inspectRangeCells[#battle.inspectRangeCells + 1] = { x = cell.x, y = cell.y }
        end
    end
end

-- The unit whose range the board is currently previewing: the one hovered on the turn-order strip
-- (an explicit "look at this" gesture) or, failing that, the one under the board cursor -- as long
-- as it isn't the acting unit itself and we're in plain MOVE mode (not aiming an armed ability).
--
-- DISABLED for now: hovering a foe to preview its reach clashed with the click-to-attack preview on
-- the same hover. Returning nil keeps the actor's own move/danger overlays up at all times; delete
-- the early return to bring the feature back (the compute/draw path below is intact).
local function desiredInspectUnit()
    do return nil end
    if battle.mode ~= "move" or battle.over then return nil end
    local cur = battle.current
    local h = battle.hoverUnit
    if h and h.alive and h ~= cur then return h end
    local u = Combat.unitAt(battle.combat, battle.map.cursor.x, battle.map.cursor.y)
    if u and u.alive and u ~= cur then return u end
    return nil
end

-- The party's danger zone: every tile any living hostile unit could reach-and-strike this turn with
-- its default weapon, unioned across the enemies. `battle.dangerCells` is the keyed set ("x,y" ->
-- {x,y}) the purple overlay reads; `battle.dangerSources` maps each threatened tile to the list of
-- enemy POSITIONS that threaten it, so a tile the cursor lands on can trace a red line back to each
-- foe. Recomputed on turn hand-off and after any walk (an enemy's reachable set shifts as units
-- move) -- never per frame. Decoys (control "none") never advance, so they raise no threat.
local function computeDanger()
    local cells, sources = {}, {}
    for _, u in ipairs(battle.combat.units) do
        if u.alive and u.side ~= "party" and u.control ~= "none" then
            local weapon = Combat.defaultWeapon(u.char)
            local ab = weapon and weapon.activeAbility
            local range = (ab and ab.range) or 1
            local reach = Combat.attackReach(battle.combat, u, range,
                Combat.reachable(battle.combat, u), ab and ab.requiresSight, Combat.abilityMinRange(ab))
            for k, cell in pairs(reach) do
                if not cells[k] then cells[k] = { x = cell.x, y = cell.y } end
                local src = sources[k]
                if not src then src = {} sources[k] = src end
                src[#src + 1] = { x = u.x, y = u.y }
            end
        end
    end
    battle.dangerCells = cells
    battle.dangerSources = sources
    battle.inspectFor = nil -- board changed: a lingering hover preview is rebuilt on the next frame
end

-- Auto-arm the unit's default action at the start of its turn, so its effective range shows by
-- default (the player pins WHICH action in the Loadout screen). This is exactly the state clicking
-- the item would arm -- armed mode, its walk-and-strike range lit -- so the player can immediately
-- act, click the item (or Esc) to disarm and move freely, or click a different item to switch. Reads
-- battle.defaultAction/defaultSupport (computeThreat set them just before). A default the unit can't
-- afford right now, or a bare-handed unit with no ability at all, simply starts disarmed (move mode).
local function armDefaultAction(current)
    local action = battle.defaultAction
    if not (action and action.activeAbility) then return end
    if Combat.itemBlockReason(current, action) then return end
    battle.armedItem = action
    battle.mode = "armed"
    battle.armedSupport = battle.defaultSupport
    battle.armedTile = action.activeAbility.target == "tile"
    computeRange(current, action)
end

-- Start the current unit's turn: MOVE mode + reachable set for a unit the player commands, or an
-- AI delay for anyone else (an enemy, or a summon fighting for them). Control -- not side -- picks
-- the branch, so a player's summon takes an interactive turn and an inert decoy does not.
local function beginTurn()
    local current = Combat.startTurn(battle.combat)
    battle.current = current
    battle.mode = "move"
    battle.armedItem = nil
    battle.hoverItem = nil
    battle.notice = nil -- a refusal belonged to the turn it was refused on
    battle.rangeCells = {}
    battle.rangeReach = {}
    battle.moveCells = {}
    battle.threatCells = {}
    battle.attackReach = {}
    battle.movePath = nil
    if not current then return end
    computeDanger() -- every turn, so the "Threats" survey toggle stays fresh on enemy turns too
    -- A unit surfacing mid-channel doesn't take an interactive turn -- its slot IS the spell resolving.
    -- Hold a beat on the telegraphed tiles (like the AI's think-pause) so the blast reads, then
    -- battle.update fires resolveChannel. Works for both sides: an enemy Meteor Storm resolves itself,
    -- with no player-vs-AI branch involved.
    if current.channel then
        battle.resolveTimer = AI_DELAY
        return
    end
    if Combat.isPlayerControlled(current) then
        computeReachable(current)
        computeThreat(current)
        armDefaultAction(current) -- start with the default action armed (its range shown by default)
        -- Snap the cursor to the new actor for keyboard/pad play. But if the mouse is the live device
        -- and still resting on a board cell, keep the cursor under it instead -- so a target the player
        -- was already hovering stays aimed and its action preview appears at once, without a mouse jiggle.
        local hoverX, hoverY
        if battle.mouseX and InputMode.isMouse() then
            hoverX, hoverY = battle.map:cellAt(battle.mouseX, battle.mouseY)
        end
        if hoverX then
            battle.map.cursor.x, battle.map.cursor.y = hoverX, hoverY
        else
            battle.map.cursor.x, battle.map.cursor.y = current.x, current.y
        end
    else
        battle.aiTimer = AI_DELAY
    end
end

-- The real hand-off, run once an action's reactions have played: resolve the objective, else start
-- the next unit's turn.
local function resolveAdvance()
    battle.pendingAdvance = nil
    local result = Combat.evaluate(battle.combat)
    if result == "win" then win() return
    elseif result == "loss" then lose() return end
    beginTurn()
end

-- End of an action. Drain the model's animation cues (damage/heal/death) into the fx controller, then
-- hold the hand-off while those reactions read (battle.update runs resolveAdvance once the beat and
-- battle.fx:busy both clear). An action that raised no cues and left nothing animating -- a bare move,
-- a wait, a pass -- resolves at once, so non-combat turns stay snappy.
local function advanceTurn()
    local events = Combat.drainFx(battle.combat)
    if events then battle.fx:ingest(events, battle.current) end
    if events or battle.fx:busy() then
        battle.pendingAdvance = { hold = IMPACT_PAUSE }
    else
        resolveAdvance()
    end
end

-- ---------------------------------------------------------------------------
-- Walking. A move is played out one tile at a time rather than teleporting, so the route a unit
-- takes is legible -- and so is what it walks into, since the model springs each tile's trap and
-- hazard on the very beat the unit lands there (Combat.stepMove). Both sides walk.
-- ---------------------------------------------------------------------------

-- Is a unit mid-walk? The board is mid-animation, so player input and the AI clock both hold.
local function walking()
    return battle.walk ~= nil
end

-- How long a refusal notice stays up, in seconds.
local NOTICE_LIFE = 2.2

-- Say why an action was refused. Every path that turns a player's activation down -- an arm, a
-- number-key, a click-to-strike -- routes its Combat.itemBlockReason here instead of returning
-- silently, so a dead click always explains itself (a grayed slot only reads once you go looking for
-- the tooltip). Drawn over the board by drawNotice and fading on its own timer.
local function notify(text)
    if not text then return end
    battle.notice = { text = text, life = NOTICE_LIFE }
end

-- Refuse `item` for `unit` if anything blocks it, announcing the reason. Returns true when the
-- action was blocked (the caller should bail), false when it may proceed.
local function refuseIfBlocked(unit, item)
    local blocked = Combat.itemBlockReason(unit, item)
    if not blocked then return false end
    notify(string.format("%s: %s", item.name or "That item", blocked.text or blocked.reason))
    return true
end

-- Should player input be held right now? True mid-walk, and also while the current unit is resolving
-- a channel -- a channeling caster (even a player one) doesn't get an interactive turn; its slot IS
-- the spell going off, and letting the player arm a second action then would double-cast. The input
-- guards below test this instead of raw walking().
local function busy()
    return walking() or battle.pendingAdvance ~= nil
        or (battle.current ~= nil and battle.current.channel ~= nil)
end

-- Send `unit` walking to (x, y), calling `onDone` once it comes to rest -- on the destination, or
-- on the tile it died on. Returns false, having changed nothing, if the move is illegal. The move
-- is spent the instant the walk starts: the blue reachable band and the red threat band both clear,
-- so nothing on the board invites a second move while the unit is still on its feet.
-- `cells`, when given, is a player-steered route (see updateMovePath): the walk follows it exactly
-- rather than the shortest path, as long as Combat.planMoveVia accepts it. Any failure (or no route)
-- falls back to the shortest path to (x, y) -- so the walk is never worse than the direct one.
local function startWalk(unit, x, y, onDone, cells)
    local plan = cells and Combat.planMoveVia(battle.combat, unit, cells)
    plan = plan or Combat.planMove(battle.combat, unit, x, y)
    if not plan then return false end
    battle.walk = { handle = Combat.beginMove(battle.combat, plan), timer = 0, onDone = onDone, unit = unit }
    battle.reachable, battle.moveCells = {}, {}
    battle.threatCells, battle.attackReach = {}, {}
    battle.movePath = nil
    return true
end

-- One tile per MOVE_STEP seconds, then hand off to the walk's onDone. The first step lands at once
-- (the unit is already standing on the origin); every step after rests on the tile it just entered,
-- so a trap that fires or a hazard that bites is on screen long enough to see.
local function updateWalk(dt)
    local w = battle.walk
    w.timer = w.timer - dt
    if w.timer > 0 then return end
    local u = w.unit
    local fromX, fromY = u.x, u.y -- cell the unit is leaving, captured before the step commits
    if Combat.stepMove(battle.combat, w.handle) then
        w.timer = MOVE_STEP
        -- Slide the sprite across the tile it just entered rather than snapping (a surviving unit).
        if u.alive then battle.fx:setSlide(u, fromX, fromY, MOVE_STEP) end
        -- A trap that sprang, a hazard that bit, an overwatch shot -- float its number on arrival.
        -- No actor leans in: this is damage taken while walking, not a strike the unit made.
        battle.fx:ingest(Combat.drainFx(battle.combat), nil)
        return
    end
    battle.walk = nil
    if w.onDone then w.onDone() end
end

local function cancelArm()
    battle.mode = "move"
    battle.armedItem = nil
end

-- Toggle a Blink (moveBehavior) item on or off for `unit`. A free, turn-neutral flip: it spends
-- nothing and ends no turn -- mana is paid per jump, at move time (Combat.blink). Flipping it
-- recomputes the move overlay so the blue band switches between walk and teleport at once. If the
-- unit cannot afford even one jump, computeReachable simply keeps showing the walk (a silent
-- fallback), so arming it is never a trap.
local function toggleBlink(unit)
    if battle.mode == "armed" then cancelArm() end
    unit.blinkArmed = not unit.blinkArmed
    computeReachable(unit)
    computeThreat(unit)
end

-- Arm an ability item (or toggle it off if already armed). A Blink item toggles teleport movement
-- instead of arming a cast (it has a moveBehavior, not an activeAbility).
local function armItem(item)
    local current = battle.current
    if battle.over or busy() or not current or not Combat.isPlayerControlled(current) then return end
    if item and item.moveBehavior and item.moveBehavior.mode == "teleport" then
        toggleBlink(current)
        return
    end
    if not (item and item.activeAbility) then return end
    if battle.armedItem == item then cancelArm() return end
    -- Anything that would make useItem reject the cast -- an unpayable cost, a spent stack, a
    -- missing adjacent item (Rain of Arrows without its bow) -- leaves it disarmed, and says so.
    -- The grayed slot and its tooltip carry the same reason, but only for a player who goes looking:
    -- an outright click on the slot has to answer for itself.
    if refuseIfBlocked(current, item) then return end
    battle.armedItem = item
    battle.mode = "armed"
    -- Friendly abilities (heal / buff) highlight green; offensive strikes and trap placements red.
    battle.armedSupport = Combat.isSupportAbility(item.activeAbility)
    battle.armedTile = item.activeAbility.target == "tile" -- tile-target (e.g. summon a trap)
    computeRange(current, item)
end

local function armSlot(n)
    local current = battle.current
    if not current or not Combat.isPlayerControlled(current) then return end
    armItem(current.char.inventory[n])
end

-- Gamepad Y cycles through the current unit's ability items (past the end -> back to move).
-- Items that can't be activated right now are skipped rather than landed on -- armItem would
-- refuse them, leaving Y with nothing to advance to.
local function cycleAbilityItem()
    local current = battle.current
    if battle.over or busy() or not current or not Combat.isPlayerControlled(current) then return end
    local items = Combat.abilityItems(current.char)
    if #items == 0 then return end
    local idx = 0
    for i, it in ipairs(items) do
        if it == battle.armedItem then idx = i break end
    end
    for i = idx + 1, #items do
        if not Combat.itemBlockReason(current, items[i]) then armItem(items[i]) return end
    end
    cancelArm()
end

-- Use the current unit's default ACTION on cell (tx, ty) -- a strike on a foe, or a heal/buff on an
-- ally: if the cheapest stand tile for that cell isn't where the unit already is, move there first
-- (only if it hasn't moved yet), then act -- a click-to-use that folds an approach into one action.
-- No-op if the target is out of this turn's reach, or the default action can't resolve (e.g. an
-- ability the unit can't afford -- unarmed itself is always free). Combat.useItem re-checks the
-- target side, so a mistargeted click simply does nothing.
local function tryDefaultAction(unit, tx, ty)
    local entry = battle.attackReach and battle.attackReach[tx .. "," .. ty]
    local weapon = battle.defaultAction
    if not entry or not weapon then return end
    -- Don't reposition for a strike useItem would refuse: a cost the unit can't pay, an unmet grid
    -- requirement. Bail before moving (unarmed is free and requires nothing, so this only guards
    -- real weapons), and say why -- this click aimed at a foe, so a silent no-op reads as a bug.
    if refuseIfBlocked(unit, weapon) then return end
    local function strike()
        if Combat.useItem(battle.combat, unit, weapon, tx, ty) then advanceTurn() end
    end
    if entry.fromX ~= unit.x or entry.fromY ~= unit.y then
        if Combat.hasMoved(battle.combat) then return end -- can't move twice in a turn
        -- Walk into reach first, then strike from where the approach left off. A unit cut down on
        -- the way in (a trap it stepped on) never gets to swing.
        return startWalk(unit, entry.fromX, entry.fromY, function()
            if unit.alive then strike() else advanceTurn() end
        end)
    end
    strike()
end

-- Strike a revealed enemy trap on (tx, ty) with the default action, folding an approach move
-- into the strike exactly like tryDefaultAction (attackReach records the cheapest stand tile).
-- Combat.strikeTrap re-checks range/visibility/cost; this just handles the click-to-destroy UX.
local function tryDamageTrap(unit, tx, ty)
    local entry = battle.attackReach and battle.attackReach[tx .. "," .. ty]
    local weapon = battle.defaultAction
    if not entry or not weapon then return end
    if refuseIfBlocked(unit, weapon) then return end
    local function strike()
        if Combat.strikeTrap(battle.combat, unit, weapon, tx, ty) then advanceTurn() end
    end
    if entry.fromX ~= unit.x or entry.fromY ~= unit.y then
        if Combat.hasMoved(battle.combat) then return end
        return startWalk(unit, entry.fromX, entry.fromY, function()
            if unit.alive then strike() else advanceTurn() end
        end)
    end
    strike()
end

-- A revealed enemy trap on (x, y), or nil. `battle.trapCells` is the per-frame lookup of traps
-- the party can currently see (refreshView), keyed "x,y".
local function revealedEnemyTrapAt(unit, x, y)
    local trap = battle.trapCells and battle.trapCells[x .. "," .. y]
    if trap and trap.side ~= unit.side then return trap end
    return nil
end

-- A living wall on (x, y), or nil. Walls are always visible to both sides, so unlike traps there is
-- no per-side filter -- any wall in reach can be struck down (your own, to open a path; the enemy's,
-- to break through). `battle.wallCells` is the per-frame "x,y" lookup built in refreshView.
local function wallAt(x, y)
    return battle.wallCells and battle.wallCells[x .. "," .. y]
end

-- Strike a wall on (tx, ty) with the default action, folding an approach move into the strike
-- exactly like tryDamageTrap. Combat.strikeWall re-checks range/cost; this handles the click UX.
local function tryDamageWall(unit, tx, ty)
    local entry = battle.attackReach and battle.attackReach[tx .. "," .. ty]
    local weapon = battle.defaultAction
    if not entry or not weapon then return end
    if refuseIfBlocked(unit, weapon) then return end
    local function strike()
        if Combat.strikeWall(battle.combat, unit, weapon, tx, ty) then advanceTurn() end
    end
    if entry.fromX ~= unit.x or entry.fromY ~= unit.y then
        if Combat.hasMoved(battle.combat) then return end
        return startWalk(unit, entry.fromX, entry.fromY, function()
            if unit.alive then strike() else advanceTurn() end
        end)
    end
    strike()
end

-- What an armed click on (cx, cy) resolves to, for the currently armed item (the turn-start default
-- or an explicitly armed one):
--   { kind = "act",  entry, cells }  -- a valid target here (a foe/ally to hit, a legal tile to
--                                 place): walk to the stand tile (entry.fromX/fromY), then use the
--                                 item. `cells`, when set, is the player-steered route to that stand
--                                 tile so the approach follows the drawn path, not the shortest one.
--   { kind = "move", x, y, cells }  -- no valid target, but the cell is a reachable tile: a single-
--                                 target strike/heal aimed at empty air is a REPOSITION, so walk onto
--                                 it (following the steered `cells` when a route ends there).
--   nil                        -- nothing to do here.
-- The move case is what lets an armed unit still walk freely (like move mode) by clicking an empty
-- tile: without it, aiming empty air would walk to the adjacent stand tile to "strike" nothing --
-- the movement stopping a tile short. Tile/self-target abilities never take the move branch (an empty
-- tile IS their target -- an AoE placement, a self-cast), so aiming them still places/casts.
-- The stand tile a strike fires from is the steered route's endpoint whenever that tile can legally
-- reach the target (so the player picks WHERE to attack from); otherwise the cheapest tile
-- attackReach recorded in rangeReach.
local function armedActionAt(cx, cy)
    local item = battle.armedItem
    local ab = item and item.activeAbility
    if not ab then return nil end
    local occ = Combat.unitAt(battle.combat, cx, cy)
    local support = battle.armedSupport
    local needsOccupant = ab.target == "enemy" or ab.target == "ally"
    local hasTarget = occ and occ.alive and (support and occ.side == battle.current.side
        or not support and occ.side ~= battle.current.side)
    if needsOccupant and not hasTarget then
        if battle.reachable and battle.reachable[cx .. "," .. cy] then
            local mp = movePathTo(cx, cy)
            return { kind = "move", x = cx, y = cy, cells = mp and mp.cells or nil }
        end
        return nil
    end
    local entry = battle.rangeReach and battle.rangeReach[cx .. "," .. cy]
    if not entry then return nil end
    -- The steered route only decides the stand tile when the actor CAN'T already hit from where it
    -- stands. Otherwise the route is ignored and the strike fires in place: the trail extends itself
    -- across every reachable tile the cursor crosses, so merely sweeping the mouse onto a foe drew a
    -- route and silently turned an in-place attack into a walk-and-strike. Steering still picks the
    -- firing tile for anything out of reach, which is the case it exists for.
    -- The endpoint must not BE the target cell: a tile-target cast (summon / AoE placement) steers its
    -- route right onto the target -- the cursor tile is the target -- so honouring that as the stand
    -- tile would walk the caster onto the very cell it means to place on, and the cast then rejects it
    -- as occupied (the caster is now standing there). Excluding it falls back to the cheapest in-range
    -- stand tile, so the placement fires in place instead of turning into a bare move.
    local stand, mp = steeredStand()
    local inPlace = standCanHit(battle.current, ab, item, battle.current.x, battle.current.y, cx, cy)
    if stand and not inPlace and not (stand.x == cx and stand.y == cy)
        and standCanHit(battle.current, ab, item, stand.x, stand.y, cx, cy) then
        return { kind = "act", cells = mp.cells,
                 entry = { x = cx, y = cy, fromX = stand.x, fromY = stand.y, moveCost = mp.cost } }
    end
    return { kind = "act", entry = entry }
end

-- What confirming on cell (cx, cy) would DO right now, as a descriptor the action-preview tooltip
-- (ui/action_preview.lua) renders beside the character/tile tooltip. Mirrors confirm()'s branching
-- so the preview always names the very action a click would take:
--   { kind = "attack",     item, target, entry }  -- default-weapon strike on a foe
--   { kind = "strikeTrap", item, trap, trapDamage, trapLethal }  -- destroy a revealed enemy trap
--   { kind = "move",       moveCost, steps }       -- step to a reachable tile
--   { kind = "ability",    item, target, support, entry }  -- armed unit/self cast (heal/strike/...)
--   { kind = "place",      item }                  -- armed tile cast (summon a trap / a creature)
-- Returns nil when a click on this cell would do nothing (not the player's turn, out of reach, an
-- invalid target), so the tooltip only appears on an actionable hover. `entry` is the dry-run effect
-- on the target unit (Combat.previewAbility); `support` tints the panel green for a friendly cast.
-- Every item-driven action also carries `spend` (Combat.abilitySpend): what the cast would take out
-- of the actor's own pools -- the resource cost AND a summon's reservation -- which the preview
-- panel lists and the actor's turn-strip bars project as a red loss slice.
local function actionPreviewFor(cx, cy)
    local current = battle.current
    if battle.over or busy() or not current or not Combat.isPlayerControlled(current) then return nil end
    local unit = Combat.unitAt(battle.combat, cx, cy)

    if battle.mode == "armed" and battle.armedItem then
        local item = battle.armedItem
        if not item.activeAbility then return nil end
        local plan = armedActionAt(cx, cy)
        if not plan then return nil end
        -- Aiming empty air with a single-target ability is a reposition (walk onto the tile). A
        -- steered detour ending here is priced by its own (longer) route, not the shortest one's.
        if plan.kind == "move" then
            local mp = movePathTo(cx, cy)
            local node = battle.reachable[cx .. "," .. cy]
            local cost = mp and mp.cost or node.cost
            local steps = mp and (#mp.cells - 1) or node.steps
            return { kind = "move", actor = current, steps = steps,
                     moveCost = Combat.moveInitiative(current, cost) }
        end
        local preview = Combat.previewAbility(battle.combat, current, item, cx, cy)
        local entry = preview and unit and preview.entries[unit] or nil
        return {
            kind = (item.activeAbility.target == "tile") and "place" or "ability",
            item = item, actor = current, target = unit, support = battle.armedSupport,
            spend = Combat.abilitySpend(current, item.activeAbility),
            entry = entry,
            -- Weighed from the tile the cast fires from -- the plan's stand tile, which a steered
            -- approach may have moved off the actor's own square.
            counters = Combat.previewCounters(battle.combat, current, item, unit,
                { entry = entry, fromX = plan.entry.fromX, fromY = plan.entry.fromY }),
            entries = preview and preview.entries or nil, -- every affected unit (AoE), for banner preview
            order = preview and preview.order or nil, -- ordered affected units, for the AoE summary
        }
    end

    if battle.mode == "move" then
        local action = battle.defaultAction
        local support = battle.defaultSupport
        local inReach = battle.attackReach and battle.attackReach[cx .. "," .. cy]
        -- A valid default-action target on this cell, in reach -> click-to-use (moving into reach
        -- first): a foe to strike with an offensive default, an ally to support with a friendly one.
        if unit and unit.alive and action and action.activeAbility then
            local validTarget = support and unit.side == current.side
                or not support and unit.side ~= current.side
            if validTarget and inReach then
                local preview = Combat.previewAbility(battle.combat, current, action, cx, cy)
                local entry = preview and preview.entries[unit] or nil
                return { kind = support and "ability" or "attack", item = action, actor = current,
                         target = unit, support = support,
                         entry = entry,
                         -- Click-to-use walks into reach first, so the answer is weighed from the
                         -- stand tile the strike fires from, not the tile the actor stands on now.
                         counters = Combat.previewCounters(battle.combat, current, action, unit,
                             { entry = entry, fromX = inReach.fromX, fromY = inReach.fromY }),
                         spend = Combat.abilitySpend(current, action.activeAbility),
                         entries = preview and preview.entries or nil,
                         order = preview and preview.order or nil }
            end
            return nil -- an occupied cell that isn't a valid default target: nothing to preview
        end
        -- A revealed enemy trap in reach -> click-to-destroy with an offensive default (a support
        -- default doesn't strike). A wall in reach breaks the same way (reuses the preview shape).
        local trap = not support and (revealedEnemyTrapAt(current, cx, cy) or wallAt(cx, cy))
        if trap and inReach then
            local dmg = action and Combat.computeTrapDamage(current, action) or 0
            return { kind = "strikeTrap", item = action, actor = current, trap = trap,
                     support = false, trapDamage = dmg, trapLethal = dmg >= (trap.health or 0),
                     spend = action and Combat.abilitySpend(current, action.activeAbility) or nil }
        end
        -- An empty reachable tile -> move (or blink) there.
        local node = battle.reachable and battle.reachable[cx .. "," .. cy]
        if node then
            if battle.blinking then
                -- A blink owes no move initiative; its price is the mana it spends per jump.
                local mb = Combat.blinkReady(current)
                return { kind = "move", actor = current, steps = node.steps, moveCost = 0, blink = true,
                         spend = mb and mb.cost and { { kind = "cost", stat = mb.cost.stat, amount = mb.cost.amount } } or nil }
            end
            -- The initiative the walk charges, not the raw path cost: a hasted unit pays half. A
            -- steered detour ending here costs its own (longer) route, not the shortest one's.
            local mp = movePathTo(cx, cy)
            local cost = mp and mp.cost or node.cost
            local steps = mp and (#mp.cells - 1) or node.steps
            return { kind = "move", actor = current, steps = steps,
                     moveCost = Combat.moveInitiative(current, cost) }
        end
    end

    return nil
end

-- Confirm on the cursor cell: move there (does NOT end the turn -- the unit can still act or
-- wait), use the default action on it (a strike on a foe, a heal on an ally -- moving into reach
-- first), strike a trap/wall with an offensive default, or use the armed item on it (ends the turn).
local function confirm()
    local current = battle.current
    if battle.over or busy() or not current or not Combat.isPlayerControlled(current) then return end
    local cx, cy = battle.map.cursor.x, battle.map.cursor.y
    if battle.mode == "move" then
        local action, support = battle.defaultAction, battle.defaultSupport
        local target = Combat.unitAt(battle.combat, cx, cy)
        local validTarget = target and target.alive and action and action.activeAbility
            and (support and target.side == current.side or not support and target.side ~= current.side)
        if validTarget then
            tryDefaultAction(current, cx, cy)
        elseif not support and revealedEnemyTrapAt(current, cx, cy) then
            tryDamageTrap(current, cx, cy)
        elseif not support and wallAt(cx, cy) and battle.attackReach and battle.attackReach[cx .. "," .. cy] then
            tryDamageWall(current, cx, cy)
        elseif battle.reachable[cx .. "," .. cy] then
            if battle.blinking then
                -- A blink is instant (no walk animation): jump, spend mana, then recompute the threat
                -- band from where it landed. Blinking onto a lethal trap/hazard ends the turn.
                if Combat.blink(battle.combat, current, cx, cy) then
                    battle.reachable, battle.moveCells = {}, {}
                    battle.threatCells, battle.attackReach = {}, {}
                    if current.alive then computeThreat(current) computeDanger() else advanceTurn() end
                end
            else
                -- Walk there (startWalk already cleared the move band -- only one move per turn),
                -- following the player-steered route when one ends on this tile. Once the unit
                -- arrives, recompute the threat band from the tile it actually stopped on and stay in
                -- this turn so the player can still arm an item or wait. A unit that walked into a
                -- lethal trap has no turn left to take.
                local mp = movePathTo(cx, cy)
                startWalk(current, cx, cy, function()
                    if current.alive then computeThreat(current) computeDanger() else advanceTurn() end
                end, mp and mp.cells)
            end
        end
    elseif battle.mode == "armed" and battle.armedItem then
        local item = battle.armedItem
        local plan = armedActionAt(cx, cy)
        if not plan then return end
        -- Aiming an empty reachable tile is a reposition, not an attack on empty air: walk onto it and
        -- stay armed, refreshing the range from the tile it now stands on (one move per turn).
        if plan.kind == "move" then
            if Combat.hasMoved(battle.combat) then return end
            startWalk(current, plan.x, plan.y, function()
                if not current.alive then advanceTurn() return end
                computeThreat(current) computeDanger() computeRange(current, item)
            end, plan.cells)
            return
        end
        -- Walk-and-strike: if the stand tile for this target -- the steered route's endpoint, or the
        -- cheapest tile attackReach found -- isn't where the unit is, walk there first (only if it
        -- hasn't moved yet), following the steered route when one is drawn, then cast from where the
        -- approach left off. rangeReach spans the whole armed reach.
        local entry = plan.entry
        local function cast()
            if Combat.useItem(battle.combat, current, item, cx, cy) then advanceTurn() end
        end
        if entry.fromX ~= current.x or entry.fromY ~= current.y then
            if Combat.hasMoved(battle.combat) then return end -- can't move twice in a turn
            startWalk(current, entry.fromX, entry.fromY, function()
                if current.alive then cast() else advanceTurn() end
            end, plan.cells)
        else
            cast()
        end
    end
end

-- End the current party unit's turn without acting. The default is a delay (Combat.wait), but an
-- item may swap this into Focus (restore mana) or Defend (a defensive stance) -- see
-- Combat.waitBehavior. Available whether or not the unit moved.
local function waitTurn()
    local current = battle.current
    if battle.over or busy() or not current or not Combat.isPlayerControlled(current) then return end
    local kind = Combat.waitBehavior(current).kind
    local action = (kind == "focus" and Combat.focus)
        or (kind == "defend" and Combat.defend)
        or (kind == "overwatch" and Combat.overwatch)
        or Combat.wait
    if action(battle.combat, current) then advanceTurn() end
end

-- Resolve a turn the player doesn't drive: an AI unit plans and acts, while an inert one (a decoy,
-- control "none") simply holds position -- it still occupies the turn order and burns a tick, so
-- from the far side of the board it is indistinguishable from a real, cautious unit.
local function executeEnemyAction()
    local current = battle.current
    if not current or Combat.isPlayerControlled(current) then return end
    if current.control == "none" then
        Combat.pass(battle.combat, current)
        advanceTurn()
        return
    end
    local act = Combat.planEnemyAction(battle.combat, current)
    -- The plan aims from the tile the unit walks to, so the action waits for the walk to finish.
    local function act_()
        if not current.alive then advanceTurn() return end -- cut down on the approach
        local acted = false
        if act.item then acted = Combat.useItem(battle.combat, current, act.item, act.tx, act.ty) end
        -- Reposition-only, nothing to do, or an item use that unexpectedly failed: pass so the
        -- turn always ends (paying the real move cost) and never soft-locks on this unit.
        if not acted then Combat.pass(battle.combat, current) end
        advanceTurn()
    end
    if act.move and startWalk(current, act.move.x, act.move.y, act_) then return end
    act_()
end

-- The timeline ghost(s) for aiming ability `item` from the current stand tile (with `pendingMove`
-- already spent this turn folded in). A plain cast lands ONE ghost at its action slot. A channeled
-- cast lands TWO: the slot the spell RESOLVES at (the wind-up, ab.channel) and, past that, the slot
-- the caster next acts at (resolution + the cast's own speed, the initiative resolveCast charges when
-- the wind-up finishes) -- so the player reads both when the spell fires and when they regain control.
--
-- A channel resolves `ab.channel` ticks out NO MATTER how far the caster walked first: the wind-up is
-- the spell's own, and the move cost is deferred past the resolution (models/combat.lua useItem's
-- channel branch). So `pendingMove` sits out of the resolve slot and lands in the follow-up instead --
-- walking moves the ghost the player regains control at, never the one the blast lands at.
local function abilityGhosts(unit, item, pendingMove)
    local a = item.activeAbility
    if a.channel then
        local resolve = a.channel
        return {
            { initiative = resolve, label = "channel resolves here" },
            { initiative = resolve + pendingMove + Combat.actionSpeed(unit, a, item),
                label = "then acts here" },
        }
    end
    return { { initiative = pendingMove + Combat.actionSpeed(unit, a, item) } }
end

-- The reposition timeline ghost for a walk to the cursor tile: where the unit's NEXT turn lands if
-- it repositions there, following the steered route's own cost when one is set, else the cheapest
-- path's. nil when the cursor isn't a reachable tile (nothing to walk to, so no ghost). Shared by
-- move mode and an armed reposition.
--
-- A bare move never ends the turn -- the unit still has to act or wait -- so a move-ONLY slot is a
-- position it can never actually rest on. With no action aimed, the honest landing slot is a move
-- THEN a wait/defend (its wait speed folded onto the move cost); aiming a real target replaces this
-- ghost with the action's own slot. Without the wait, the ghost under-reads and the card visibly
-- jumps later the moment the unit waits.
local function moveGhostInitiative(unit)
    local cost = battle.movePath and battle.movePath.cost
    if not cost then
        local node = battle.reachable and battle.reachable[battle.map.cursor.x .. "," .. battle.map.cursor.y]
        cost = node and node.cost
    end
    if not cost then return nil end
    return Combat.waitInitiative(battle.combat, unit, Combat.moveInitiative(unit, cost))
end

-- Compute the turn-order preview + battlefield overlays and hand them to the widgets.
local function refreshView()
    local current = battle.current
    if not current then return end
    local isParty = Combat.isPlayerControlled(current) and not battle.over

    -- Keep the steerable move-route preview fresh. It runs in move mode AND armed mode: while an
    -- item is armed the player steers the same Advance-Wars route to a chosen stand tile, then aims
    -- the strike, which fires from that tile (see armedActionAt). Cleared otherwise (a hovered-slot
    -- preview, an enemy turn) so a stale route never lingers. Must run before the initiative preview
    -- below, which prices a detour off the route's own cost.
    if isParty and not busy() and (battle.mode == "move" or battle.mode == "armed") then
        updateMovePath(current)
    else
        battle.movePath = nil
    end

    -- Preview the projected initiative the pending action would give the actor. The actor
    -- sits at initiative 0; a move already taken this turn is folded in via the pending move
    -- cost, and a wait previews the delay slot (next unit's initiative + 1). A channeled ability
    -- yields TWO ghosts (resolution + follow-up turn); everything else yields one. See abilityGhosts.
    local ghosts
    local pendingMove = (battle.combat.turn and battle.combat.turn.moveCost) or 0
    if isParty then
        if battle.hoverWait then
            -- Whatever the Wait button actually runs -- a plain delay, or a Focus/Defend/Overwatch
            -- swap with its own speed cost -- so the ghost lands on the same slot the action will.
            ghosts = { { initiative = Combat.waitInitiative(battle.combat, current) } }
        elseif battle.hoverItem and battle.hoverItem.activeAbility then
            ghosts = abilityGhosts(current, battle.hoverItem, pendingMove)
        elseif battle.mode == "armed" and battle.armedItem then
            -- Project a landing slot only when the cursor is actually aimed at a cell the armed item
            -- can act on: a valid cast target lands the ability's time-cost ghost(s); a reachable tile
            -- lands a reposition ghost. Aiming empty / out-of-range air commits to nothing, so no ghost
            -- shows -- arming an item alone must not paint a timeline slot before a target is aimed.
            local plan = armedActionAt(battle.map.cursor.x, battle.map.cursor.y)
            if plan and plan.kind == "act" then
                -- A walk-and-strike fires from a stand tile the actor must walk to first, so the
                -- landing slot owes that approach's initiative on top of any move already spent this
                -- turn (plan.entry.moveCost is a raw path cost -- convert it, don't add it straight).
                local approach = Combat.moveInitiative(current, (plan.entry and plan.entry.moveCost) or 0)
                ghosts = abilityGhosts(current, battle.armedItem, pendingMove + approach)
            elseif plan and plan.kind == "move" then
                local w = moveGhostInitiative(current)
                if w then ghosts = { { initiative = w } } end
            end
        elseif battle.mode == "move" then
            local w = moveGhostInitiative(current)
            if w then ghosts = { { initiative = w } } end
        end
    end
    -- Once a move is committed its speed cost is locked in (turn.moveCost), so a ghost stays on the
    -- timeline at that slot -- for the PLAYER between the move and choosing an action, and for an ENEMY
    -- the moment it finishes walking. That committed re-entry is where the actor's card solidifies when
    -- the turn hands off, so the current-turn card fades in place instead of sweeping up out of the
    -- frame. The player-preview branches above override it whenever a specific action/aim is shown.
    -- For the deciding PLAYER with nothing aimed, land the ghost where a move-then-wait actually ends
    -- up (its wait speed folded on), not the bare move slot the turn can never rest on -- so the card
    -- doesn't jump later the instant they wait. An enemy just re-enters at its committed move slot.
    if not ghosts and pendingMove > 0 then
        local slot = isParty and Combat.waitInitiative(battle.combat, current) or pendingMove
        ghosts = { { initiative = slot } }
    end
    -- An action that has committed and is holding for its impact beat (pendingAdvance) already charged
    -- the actor forward, so keep a ghost at that now-real slot -- overriding any move-only ghost above.
    -- Without this the aim preview blinks out the instant the swing lands and only reappears when the
    -- card solidifies at hand-off; instead the ghost stays on the strip through the hit and then morphs
    -- into the actor's real card when the turn ends (the solidify path in ui/combat_panel.lua). A
    -- channeling caster is left to Combat.channelGhosts, which owns the resolve/follow-up picture.
    if isParty and battle.pendingAdvance and current.initiative > 0 and not current.channel then
        ghosts = { { initiative = current.initiative } }
    end
    -- Timeline entries for the panel: the live order, plus a ghost of the actor at each projected
    -- slot while a move/item/wait is being previewed, plus a "then acts here" ghost for every unit
    -- still winding up a channel -- so the resolution + follow-up the aim preview showed stay on the
    -- strip once the cast is committed (Combat.channelGhosts). Both kinds of ghost feed one build.
    local specs = Combat.channelGhosts(battle.combat)
    for _, g in ipairs(ghosts or {}) do
        specs[#specs + 1] = { unit = current, initiative = g.initiative, label = g.label }
    end
    local entries = Combat.buildTimeline(battle.combat, specs)
    -- Anchor the acting unit at rank 1 on the strip until the UI actually hands off. The model charges
    -- its initiative and rebases the instant it acts (endTurn, inside useItem) -- a beat before
    -- resolveAdvance switches battle.current -- so buildTimeline would otherwise re-rank the current card
    -- and slide it upward mid-attack, while its damage still reads. Move its real entry to the front.
    for i, e in ipairs(entries) do
        if e.unit == current and not e.preview then
            table.remove(entries, i); table.insert(entries, 1, e); break
        end
    end

    -- Board highlights: the acting unit always, plus whichever unit the timeline is hovering.
    local overlays = { move = {}, range = {} }
    local hoverAbility = battle.hoverItem and battle.hoverItem.activeAbility
    if isParty and (battle.mode == "armed" or hoverAbility) then
        -- Armed (the turn-start default, or an explicitly armed item), or previewing a hovered ability
        -- slot: show the EFFECTIVE range -- the movement band PLUS the action's reach beyond it, so the
        -- player reads where the unit can step and where it can act from there. Aiming a cell that needs
        -- an approach previews the walk-and-strike route to the stand tile the action fires from.
        local armed = battle.mode == "armed"
        local previewItem = armed and battle.armedItem or battle.hoverItem
        local support = armed and battle.armedSupport or Combat.isSupportAbility(hoverAbility)
        -- The hovered (not-yet-armed) item's reach is computed on the fly; an armed item's was computed
        -- when it was armed and holds until the turn acts (the board doesn't shift on the player's turn).
        if hoverAbility and not armed then computeRange(current, battle.hoverItem) end

        -- Movement band, split by danger (blue safe / purple risky) exactly like move mode.
        local danger = battle.dangerCells or {}
        local moveKeys, safe, risky = {}, {}, {}
        for _, c in ipairs(battle.moveCells) do
            local k = c.x .. "," .. c.y
            moveKeys[k] = true
            if danger[k] then risky[#risky + 1] = c else safe[#safe + 1] = c end
        end
        overlays.move = safe
        overlays.moveDanger = risky

        -- The action's reach BEYOND the move band, plus any occupied target cell -- the move band
        -- already colours the reachable empty tiles, so this is just the extra tiles a move-then-act
        -- reaches (and the foe/ally you would hit). Green for support, red for a strike.
        local band = {}
        for _, c in ipairs(battle.rangeCells or {}) do
            if not moveKeys[c.x .. "," .. c.y] then band[#band + 1] = c end
        end
        overlays.range = band
        overlays.rangeSupport = support

        -- An AoE ability paints its blast footprint around the aimed cell, brighter than the wash.
        overlays.aoe = aoeFootprint(previewItem, battle.map.cursor.x, battle.map.cursor.y)
        overlays.aoeSupport = support

        -- Preview the move to reach the aimed cell, drawn as the same arrow move mode uses: onto the
        -- cell when it's a reposition (empty reachable tile), or to the stand tile the action fires
        -- from when hitting a target there. Nil when the unit is already in place or there's nothing
        -- to do. Only for the armed item (a hovered-slot preview isn't committing to a move).
        if armed then
            local plan = armedActionAt(battle.map.cursor.x, battle.map.cursor.y)
            local tx, ty, cells
            if plan and plan.kind == "move" then
                tx, ty, cells = plan.x, plan.y, plan.cells
            elseif plan and plan.kind == "act"
                and (plan.entry.fromX ~= current.x or plan.entry.fromY ~= current.y) then
                tx, ty, cells = plan.entry.fromX, plan.entry.fromY, plan.cells
            end
            if tx then
                -- Draw the steered route to the stand tile when the player has one; otherwise the
                -- shortest approach.
                local route = cells
                if not route then
                    local r = Combat.planMove(battle.combat, current, tx, ty)
                    route = r and r.path or nil
                end
                overlays.path = route
                -- If a walk-and-strike steps the actor onto a tile some foe can reach-and-strike,
                -- pulse a red line from each threatening foe to that projected stand tile -- the same
                -- "here is who could hit me there" read move mode gives, now for an armed attack that
                -- moves into the line of fire before it swings.
                local from = battle.dangerSources and battle.dangerSources[tx .. "," .. ty]
                if from then
                    overlays.threatLine = { to = { x = tx, y = ty }, from = from }
                end
            end
        end
    elseif isParty then
        -- Hovering a unit previews ITS reach instead of the actor's (Fire Emblem / Triangle
        -- Strategy): the hovered unit's own movement (orange) + attack range (crimson) REPLACE the
        -- actor's blue/red/purple overlays until the cursor leaves it. Cached against the unit it was
        -- built for (battle.inspectFor) so it rebuilds only when the hovered unit changes.
        local inspect = desiredInspectUnit()
        if inspect ~= battle.inspectFor then computeInspect(inspect) end
        if inspect then
            overlays.inspectMove = battle.inspectMoveCells
            overlays.inspectRange = battle.inspectRangeCells
        else
            -- Plain move mode (the unit's default action has been disarmed to move freely): no action
            -- band -- the range is shown while an action is armed, which is the turn-start default. Just
            -- the movement overlay here.
            -- Split the reachable move band by danger: a tile the actor could step to that a foe
            -- could ALSO strike this turn turns purple (the intersection of your movement and an
            -- enemy's attack range), so a step into the line of fire reads; the rest stay blue.
            local danger = battle.dangerCells or {}
            local safe, risky, riskyKeys = {}, {}, {}
            for _, c in ipairs(battle.moveCells) do
                local k = c.x .. "," .. c.y
                if danger[k] then risky[#risky + 1] = c riskyKeys[k] = true else safe[#safe + 1] = c end
            end
            overlays.move = safe
            overlays.moveDanger = risky
            -- The route the actor will walk to the cursor tile, drawn as an arrow over the move wash
            -- (nil unless the cursor is a plain walk target -- see updateMovePath).
            overlays.path = battle.movePath and battle.movePath.cells or nil
            -- A red line pulses from each foe that threatens the tile under the cursor toward it, so
            -- the move being weighed reads as "here is who could hit me there". Only the purple
            -- movement tiles (a step the actor can actually take into a foe's range) draw it -- not
            -- every threatened tile on the board.
            local ck = battle.map.cursor.x .. "," .. battle.map.cursor.y
            local from = riskyKeys[ck] and battle.dangerSources and battle.dangerSources[ck]
            if from then
                overlays.threatLine = { to = { x = battle.map.cursor.x, y = battle.map.cursor.y }, from = from }
            end
        end
    end
    overlays.current = { x = current.x, y = current.y, unit = current }
    local hover = battle.hoverUnit
    if hover and hover.alive then overlays.hover = { x = hover.x, y = hover.y } end

    -- "Threats" survey (the left-column toggle): wash EVERY tile any enemy could reach-and-strike
    -- this turn in purple, so the whole danger picture reads at once. During the actor's own move
    -- turn its reachable tiles are left to the move overlay (blue / move-danger purple), so the
    -- survey only fills in the danger BEYOND where the actor can step.
    if battle.showEnemyRanges then
        local moveKeys = {}
        if isParty and battle.mode == "move" then
            for _, c in ipairs(battle.moveCells or {}) do moveKeys[c.x .. "," .. c.y] = true end
        end
        local ranges = {}
        for k, c in pairs(battle.dangerCells or {}) do
            if not moveKeys[k] then ranges[#ranges + 1] = c end
        end
        overlays.enemyRanges = ranges
    end

    -- Traps the party can currently see (its own + detected enemy traps): a per-frame lookup for
    -- click-to-damage (revealedEnemyTrapAt) and the list the renderer draws.
    battle.revealedTraps = Trap.revealedTo(battle.combat, "party")
    battle.trapCells = {}
    for _, t in ipairs(battle.revealedTraps) do battle.trapCells[t.x .. "," .. t.y] = t end
    overlays.traps = battle.revealedTraps

    -- Hazards (fire/rain/sanctuary) are always visible to both sides, so the renderer draws the whole
    -- live list -- no per-side visibility filter like traps have.
    overlays.hazards = battle.combat.hazards

    -- Walls (conjured blockers) are always visible to both sides too. Keep a per-frame "x,y" lookup
    -- for click-to-strike (wallAt), mirroring battle.trapCells.
    overlays.walls = battle.combat.walls
    battle.wallCells = {}
    for _, w in ipairs(battle.combat.walls or {}) do
        if w.alive then battle.wallCells[w.x .. "," .. w.y] = w end
    end

    -- Preview resources lost / damage dealt on the turn-order banners: the action under the mouse
    -- (the same one the tile tooltip shows) projects its damage/heal onto every affected unit's
    -- banner and its whole spend -- cost plus a summon's reservation -- onto the actor's banner.
    -- Computed after the range/reach overlays so actionPreviewFor sees the current valid-target sets.
    local bannerPreview
    -- Also the source of truth for the context cursor (battle.cursorKind): the descriptor of what a
    -- click on the hovered cell would do, or nil when nothing is aimed. Cleared each frame so it can't
    -- go stale on the enemy's turn or once the mouse leaves the board.
    battle.hoverAction = nil
    if isParty and battle.mouseX then
        local cx, cy = battle.map:cellAt(battle.mouseX, battle.mouseY)
        local action = cx and actionPreviewFor(cx, cy)
        battle.hoverAction = action or nil
        if action then
            bannerPreview = {}
            if action.entries then
                for tgt, e in pairs(action.entries) do
                    bannerPreview[tgt] = { damage = e.damage, heal = e.heal, lethal = e.lethal }
                end
            end
            if action.actor and action.spend and #action.spend > 0 then
                local a = bannerPreview[action.actor] or {}
                a.spend = action.spend
                bannerPreview[action.actor] = a
            end
        end
    end
    -- Hovering an ability SLOT (the cursor is on the panel, so there's no aimed board action) prices
    -- the same spend onto the actor's bars, beside the range it already previews -- so what a cast
    -- would take reads before committing to arm it, not only once it's aimed.
    if isParty and not bannerPreview and hoverAbility then
        local spend = Combat.abilitySpend(current, hoverAbility)
        if #spend > 0 then bannerPreview = { [current] = { spend = spend } } end
    end

    battle.panel:setView({
        order = entries, current = current, isPartyTurn = isParty,
        items = Combat.isPlayerControlled(current) and current.char.inventory or {},
        itemOwner = Combat.isPlayerControlled(current) and current.char or nil, -- for adjacency link lines
        armedItem = battle.armedItem,
        showInitiative = battle.showInitiative,
        preview = bannerPreview,
    })

    -- Telegraph every in-progress channel's blast on the board -- not just the local armed preview, so
    -- an ENEMY winding up Meteor Storm paints the tiles it will hit, and the player can step clear.
    -- Read from unit.channel (the pending payload), independent of whose turn it is.
    local channelAoe
    for _, u in ipairs(battle.combat.units) do
        local ch = u.alive and u.channel
        if ch then
            channelAoe = channelAoe or {}
            -- Call Combat.aoeCells directly rather than aoeFootprint: the footprint helper gates on the
            -- ACTING unit's range set, but this is the channeler's own stored aim, cast turns ago.
            for _, c in ipairs(Combat.aoeCells(battle.combat, ch.ab, ch.tx, ch.ty, u)) do
                channelAoe[#channelAoe + 1] = c
            end
        end
    end
    overlays.channelAoe = channelAoe

    overlays.hpPreview = bannerPreview -- per-unit incoming damage/heal, for on-board HP bars
    battle.map:setOverlays(overlays)
end

-- ---------------------------------------------------------------------------
-- State callbacks
-- ---------------------------------------------------------------------------

function battle.enter(self, opts)
    opts = opts or {}
    battle.onWin = opts.onWin
    battle.onLoss = opts.onLoss
    battle.encounter = opts.encounter or { kind = "combat", name = "Battle" }
    battle.over = false
    battle.showInitiative = true -- initiative numbers on the turn order (F6 toggles)

    -- Active party instances (from the player), keyed by id for spawn lookup.
    local party = opts.party or {}
    local partyIds, partyById = {}, {}
    for i, char in ipairs(party) do
        partyIds[i] = char.id
        partyById[char.id] = char
    end

    local seed = os.time() + math.floor(((love.timer and love.timer.getTime()) or 0) * 1000) % 100000
    local ctx = { prestige = opts.prestige or 1, biome = opts.biome, quest = opts.quest }
    battle.arena = Arena.build(ctx, specFor(opts, partyIds, seed))

    -- Combat unit lists: { char = <instance>, x, y }.
    battle.partyUnits, battle.enemyUnits = {}, {}
    for _, u in ipairs(battle.arena.party) do
        battle.partyUnits[#battle.partyUnits + 1] = { char = partyById[u.id], x = u.x, y = u.y }
    end
    -- Escorted allies fight on the party's side but are not the player's characters (they
    -- are not in partyById), so they get fresh instances and run themselves. A `protect`
    -- objective points at one of these; see Arena.build and Combat.evaluate.
    for _, u in ipairs(battle.arena.allies or {}) do
        battle.partyUnits[#battle.partyUnits + 1] =
            { char = Character.instantiate(u.id), x = u.x, y = u.y, control = "ai" }
    end
    for _, u in ipairs(battle.arena.enemies) do
        battle.enemyUnits[#battle.enemyUnits + 1] =
            { char = Character.instantiate(u.id), x = u.x, y = u.y }
    end

    battle.combat = Combat.new(battle.arena, battle.partyUnits, battle.enemyUnits)
    -- The player's stash, by reference: Combat.steal appends here when a party thief's own 3x3 grid
    -- has no room, so the item is the player's the moment it's lifted, win or lose.
    battle.combat.stash = opts.stash
    -- One animation controller for the battle, shared into the board and the turn strip so damage
    -- floaters, HP drain, sprite reactions and card jiggle/fade all read the same state.
    battle.fx = CombatFx.new()
    battle.pendingAdvance = nil
    battle.map = BattleMap.new(battle.arena,
        { combat = battle.combat, leftMargin = LEFT_W, rightMargin = PANEL_W,
          tileSize = BOARD_TILE, topMargin = BOARD_TOP })
    battle.map.fx = battle.fx
    battle.panel = CombatPanel.new(battle.combat, {
        onActivateItem = function(item) armItem(item) end,
        onHoverItem = function(item) battle.hoverItem = item end,
        onHoverUnit = function(unit) battle.hoverUnit = unit end,
        onWait = function() waitTurn() end, -- the long Wait button under the item grid
    })
    battle.panel.fx = battle.fx
    -- The log toggles into a thin, board-width strip in the bottom gutter, directly under the
    -- board (derived from the map so it stays aligned no matter the arena size).
    local m = battle.map
    local logY = m.originY + battle.arena.rows * m.size + 8
    battle.log = CombatLog.new(battle.combat, {
        x = m.originX,
        y = logY,
        w = battle.arena.cols * m.size,
        h = Scale.HEIGHT - logY - 8,
    })

    beginTurn()
    refreshView()
end

function battle.update(dt)
    battle.map:update(dt)
    battle.fx:update(dt)
    -- Age out a refusal notice. Independent of the turn/animation clock: it is UI chrome about a
    -- click that never became an action, so nothing on the board waits on it.
    if battle.notice then
        battle.notice.life = battle.notice.life - dt
        if battle.notice.life <= 0 then battle.notice = nil end
    end
    if walking() then
        updateWalk(dt) -- a walk holds the AI clock: whoever is on their feet finishes first
    elseif battle.pendingAdvance then
        -- An action just resolved: hold until the reaction beat elapses AND the sprite reactions finish
        -- AND the HP bars stop draining AND the damage numbers have floated away, then hand off (or fire
        -- win/loss). Holding the WHOLE damage animation keeps it from bleeding into the turn-order
        -- restage, so the hit reads fully and THEN the turn moves as its own beat. Checked before the
        -- channel/AI branches so the just-acted unit can't take a second action while its hit still reads.
        battle.pendingAdvance.hold = battle.pendingAdvance.hold - dt
        if battle.pendingAdvance.hold <= 0 and not battle.fx:busy()
            and battle.fx:hpSettled() and battle.fx:floatersDone() then
            resolveAdvance()
        end
    elseif not battle.over and battle.current and battle.current.channel then
        -- The current unit is mid-channel: once the timeline has finished reshuffling into the new
        -- order, count the think-pause down, then detonate the spell and hand off. Checked before the
        -- AI branch so a player's own channel resolves too (a player channeler is player-controlled,
        -- so the AI branch below would skip it).
        if battle.panel:cardsSettled() then
            battle.resolveTimer = (battle.resolveTimer or 0) - dt
            if battle.resolveTimer <= 0 then
                Combat.resolveChannel(battle.combat, battle.current)
                advanceTurn()
            end
        end
    elseif not battle.over and battle.current and not Combat.isPlayerControlled(battle.current) then
        -- Hold the enemy's think-pause until the turn-strip cards have settled, so a fast chain of
        -- AI turns never resolves out from under the card animation (the card would otherwise pop to
        -- full size mid-slide). The player's own turn isn't gated -- input is already held elsewhere.
        if battle.panel:cardsSettled() then
            battle.aiTimer = (battle.aiTimer or 0) - dt
            if battle.aiTimer <= 0 then executeEnemyAction() end
        end
    end
    refreshView()
    -- After refreshView so the strip sees THIS turn's order: the new acting card snaps into the
    -- framed slot (no tall card left mid-pile) and the rest slide from where they were.
    battle.panel:update(dt)
end

function battle.draw()
    love.graphics.setColor(0.04, 0.05, 0.07)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    battle.drawLeftColumn()
    battle.map:draw()
    battle.fx:drawFloaters(battle.map) -- damage / heal numbers, above the board
    battle.panel:draw()
    battle.drawHud()
    battle.log:draw()
    battle.drawNotice()

    -- Status tooltip, drawn last so it sits above both the board and the panel. The panel is on
    -- top where the two overlap, so it wins the hit-test; its tooltip may extend to the screen
    -- edge, while a board tooltip is kept clear of the panel (rightMargin).
    local mx, my = battle.mouseX, battle.mouseY
    if mx then
        local st = battle.panel:statusAt(mx, my)
        local boardSt = not st and battle.map:statusAt(mx, my)
        local item = not st and not boardSt and battle.panel:itemAt(mx, my)
        if st then
            StatusTooltip.draw(st, mx, my, Scale.WIDTH)
        elseif boardSt then
            StatusTooltip.draw(boardSt, mx, my, Scale.WIDTH - PANEL_W)
        elseif item then
            -- A panel item slot under the cursor shows its details tooltip. Pass the acting unit
            -- so the tooltip can flag an ability it can't currently afford.
            ItemTooltip.draw(item, mx, my, Scale.WIDTH, battle.current)
        else
            -- A turn-order strip entry shows that unit's stats tooltip; otherwise a battlefield
            -- tile under the cursor shows its terrain + occupant tooltip.
            local stripUnit = battle.panel:unitAt(mx, my)
            if stripUnit and stripUnit.alive then
                battle.drawUnitTooltip(stripUnit, mx, my, Scale.WIDTH)
            else
                battle.drawTileTooltip(mx, my)
            end
        end
    end
end

-- The refusal notice: why the last activation was turned down (see notify). A red-rimmed banner
-- centred low over the board -- under the units, clear of the HUD text up top and of both side
-- columns -- that fades out over its final half-second. Nothing to click: it is a message, not a
-- prompt, so it never takes input away from the turn underneath it.
function battle.drawNotice()
    local notice = battle.notice
    if not notice then return end
    local alpha = math.min(1, notice.life / 0.5) -- hold full, then fade over the last half-second
    local boardX = LEFT_W
    local boardW = Scale.WIDTH - LEFT_W - PANEL_W

    love.graphics.setFont(hudFont)
    local w = math.min(boardW - 40, hudFont:getWidth(notice.text) + 32)
    local h = 34
    local x = boardX + (boardW - w) / 2
    local y = Scale.HEIGHT - 96

    love.graphics.setColor(0.20, 0.08, 0.10, 0.92 * alpha)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(0.85, 0.35, 0.35, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 0.88, 0.88, alpha)
    love.graphics.printf(notice.text, x, y + h / 2 - 8, w, "center")
    love.graphics.setColor(1, 1, 1)
end

-- Terrain + occupant tooltips for the battlefield tile under (mx, my). No-op when the mouse is off
-- the board. Docked into the left column as SEPARATE stacked boxes so the terrain reads on its own,
-- distinct from whatever stands on it: the terrain box sits at the bottom, the occupant (a unit's
-- side + pools + stats, or a revealed trap's owner + HP) in its own box above it, and the action
-- preview above that. All span the column's full width. Kept clear of the combat panel (maxRight).
function battle.drawTileTooltip(mx, my)
    local cx, cy = battle.map:cellAt(mx, my)
    if not cx then return end
    local cell = battle.arena.tiles[cy] and battle.arena.tiles[cy][cx]
    if not cell then return end
    local unit = Combat.unitAt(battle.combat, cx, cy)
    local trap = battle.trapCells and battle.trapCells[cx .. "," .. cy]
    -- Whatever a click here would do (attack / move / place a trap / strike a trap) is named by a
    -- companion panel on top, and its damage/heal is previewed on the occupant's resource bars
    -- (a unit's HP for a strike/heal, or a trap's HP for a trap strike).
    local action = actionPreviewFor(cx, cy)
    local preview
    if action then
        if action.kind == "strikeTrap" then
            preview = { damage = action.trapDamage, lethal = action.trapLethal }
        else
            preview = action.entry
        end
    end

    local maxRight = Scale.WIDTH - PANEL_W
    local W = LEFT_W - 32 -- full column width (16px margins each side)
    local dockTop, gap, exGap = 150, 8, 4

    local terrainInfo = { cell = cell, bonus = Combat.fieldBonus(battle.combat, cx, cy),
                          hazards = Hazard.allAt(battle.combat, cx, cy) }
    local objInfo
    if unit and unit.char then objInfo = { unit = unit, preview = preview }
    elseif trap then objInfo = { trap = trap, preview = preview } end

    -- The EXCHANGE, in resolution order (bottom-up, so the list reads last-beat-first): the counters
    -- that answer after the blow, then the blow, then any reflex that answers BEFORE it (Keen Senses).
    -- Stacked upward, reading the column downward reads the beats in the order they play out. Each is
    -- its own box: an answer is a second action in the trade, not a footnote on yours.
    local exchange = {}
    if action then
        local before, after = {}, {}
        for _, c in ipairs(action.counters or {}) do
            if c.first then before[#before + 1] = c else after[#after + 1] = c end
        end
        for i = #after, 1, -1 do exchange[#exchange + 1] = ActionPreview.counterAction(after[i], action) end
        exchange[#exchange + 1] = action
        for i = #before, 1, -1 do exchange[#exchange + 1] = ActionPreview.counterAction(before[i], action) end
    end

    -- The column is a fixed height and the content isn't: a wordy terrain box, a long status list and
    -- a two-reflex exchange together overrun it, and boxes clamped at dockTop would then draw over
    -- each other. So measure first and let the REFERENCE boxes yield -- the exchange is what the click
    -- commits to, and it always gets its room. Terrain goes first (the board itself shows the tile),
    -- then the occupant (whose bars are on its board token too). Both almost always fit; this is the
    -- valve for when they don't.
    local budget = Scale.HEIGHT - 8 - dockTop
    for _, a in ipairs(exchange) do budget = budget - ActionPreview.measure(a) - exGap end
    local objH = objInfo and (TileTooltip.measure(objInfo, W) + gap) or 0
    local terrainH = TileTooltip.measure(terrainInfo, W) + gap
    local showObj = objInfo ~= nil and objH <= budget
    local showTerrain = terrainH + (showObj and objH or 0) <= budget

    -- Terrain box at the very bottom of the column. Any hazards on the tile ride along on the same
    -- info so they read as a section directly above the terrain (and below the occupant box).
    local topBox
    if showTerrain then
        topBox = TileTooltip.draw(terrainInfo, mx, my, maxRight,
            { dock = true, dockX = 16, dockTop = dockTop, width = W })
    end

    -- Occupant (unit or trap) in its own box, separated from the terrain by a gap.
    if showObj then
        local objBox = TileTooltip.draw(objInfo, mx, my, maxRight,
            { dock = true, dockX = 16, dockTop = dockTop, width = W,
              dockBottom = (topBox and topBox.y or Scale.HEIGHT - 8) - gap })
        if objBox then topBox = objBox end
    end

    -- Then the exchange, each box anchored above the last. A tighter gap than the one between the
    -- reference boxes below: these are beats of a single trade and read as one unit.
    local exOpts = { placement = "above", dockTop = dockTop, width = W, gap = exGap }
    -- With every reference box dropped there is nothing to anchor to: start from the column floor.
    topBox = topBox or { x = 16, y = Scale.HEIGHT - 8 + exGap, w = W, h = 0 }
    for _, a in ipairs(exchange) do
        topBox = ActionPreview.draw(a, topBox, maxRight, exOpts) or topBox
    end
end

-- Stats tooltip for a unit hovered on the turn-order strip: the same widget as the tile hover, but
-- fed only the unit (no tile), so it shows the character's stats alone without terrain. `maxRight`
-- is the full screen width since a strip hover sits over the panel (the tooltip flips left of the
-- cursor to stay on-screen).
function battle.drawUnitTooltip(unit, mx, my, maxRight)
    TileTooltip.draw({ unit = unit }, mx, my, maxRight or Scale.WIDTH)
end

-- Backdrop for the left column (mirrors the right combat panel). The buttons and the docked
-- tile/action tooltips render on top of it; the board is centred in the gap to its right.
function battle.drawLeftColumn()
    love.graphics.setColor(0.10, 0.11, 0.15, 0.86)
    love.graphics.rectangle("fill", 0, 0, LEFT_W, Scale.HEIGHT)
    love.graphics.setColor(0.30, 0.33, 0.42)
    love.graphics.setLineWidth(1)
    love.graphics.line(LEFT_W, 0, LEFT_W, Scale.HEIGHT)
    love.graphics.setColor(1, 1, 1)
end

function battle.drawHud()
    -- Centre the HUD text over the board region (the gap between the two side columns), not the
    -- whole window, so title/objective/hint sit squarely above the battlefield.
    local boardX = LEFT_W
    local boardW = Scale.WIDTH - LEFT_W - PANEL_W

    -- Forfeit button.
    love.graphics.setColor(0.28, 0.18, 0.20)
    love.graphics.rectangle("fill", forfeitButton.x, forfeitButton.y, forfeitButton.w, forfeitButton.h, 6, 6)
    love.graphics.setColor(0.7, 0.4, 0.4)
    love.graphics.rectangle("line", forfeitButton.x, forfeitButton.y, forfeitButton.w, forfeitButton.h, 6, 6)
    love.graphics.setColor(0.95, 0.9, 0.9)
    love.graphics.setFont(hudFont)
    love.graphics.printf("Forfeit", forfeitButton.x, forfeitButton.y + forfeitButton.h / 2 - 8,
        forfeitButton.w, "center")

    -- Combat-log toggle: brighter when the panel is open so its state reads at a glance.
    local logOn = battle.log and battle.log.visible
    if logOn then love.graphics.setColor(0.20, 0.26, 0.22) else love.graphics.setColor(0.15, 0.17, 0.16) end
    love.graphics.rectangle("fill", logButton.x, logButton.y, logButton.w, logButton.h, 6, 6)
    if logOn then love.graphics.setColor(0.55, 0.80, 0.55) else love.graphics.setColor(0.35, 0.40, 0.38) end
    love.graphics.rectangle("line", logButton.x, logButton.y, logButton.w, logButton.h, 6, 6)
    if logOn then love.graphics.setColor(0.85, 0.98, 0.85) else love.graphics.setColor(0.6, 0.66, 0.62) end
    love.graphics.setFont(hudFont)
    love.graphics.printf(logOn and "Log ✓" or "Log", logButton.x, logButton.y + logButton.h / 2 - 8,
        logButton.w, "center")

    -- All-enemy-ranges toggle: brighter (purple) when the danger overlay is on, matching the
    -- purple the threatened tiles are washed in.
    local rangesOn = battle.showEnemyRanges
    if rangesOn then love.graphics.setColor(0.26, 0.18, 0.30) else love.graphics.setColor(0.16, 0.15, 0.18) end
    love.graphics.rectangle("fill", rangesButton.x, rangesButton.y, rangesButton.w, rangesButton.h, 6, 6)
    if rangesOn then love.graphics.setColor(0.72, 0.45, 0.92) else love.graphics.setColor(0.40, 0.36, 0.44) end
    love.graphics.rectangle("line", rangesButton.x, rangesButton.y, rangesButton.w, rangesButton.h, 6, 6)
    if rangesOn then love.graphics.setColor(0.90, 0.80, 0.98) else love.graphics.setColor(0.62, 0.60, 0.66) end
    love.graphics.setFont(hudFont)
    love.graphics.printf(rangesOn and "Threats ✓" or "Threats",
        rangesButton.x, rangesButton.y + rangesButton.h / 2 - 8, rangesButton.w, "center")

    -- Encounter name + objective, centred over the battlefield region.
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(battle.encounter.name or "Battle", boardX, 20, boardW, "center")

    love.graphics.setFont(hudFont)
    love.graphics.setColor(0.85, 0.85, 0.9)
    love.graphics.printf(objectiveText(battle.arena.objective), boardX, 52, boardW, "center")

    -- Contextual control hint, worded for the device last used: mouse/keyboard phrasing ("Click...")
    -- by default, pad-button phrasing (D-pad cursor + face buttons: A confirm, Y switch, X wait,
    -- B cancel) in gamepad mode, so the gamepad player never reads a "Click" they can't do.
    local pad = InputMode.isGamepad()
    local hint
    if battle.current and Combat.isPlayerControlled(battle.current) and not battle.over then
        if battle.mode == "armed" then
            local verb
            -- A tile cast places something -- a trap, a summoned creature -- so name it rather than
            -- calling everything a trap.
            if battle.armedTile then
                local name = (battle.armedItem and battle.armedItem.name) or "it"
                verb = pad and ("Aim a tile, A to place " .. name) or ("Click a tile to place " .. name)
            elseif battle.armedSupport then
                verb = pad and "A on an ally to support" or "Click an ally to support"
            else
                verb = pad and "A on a target to strike" or "Click a target to strike"
            end
            hint = pad and (verb .. "  ·  Y to switch  ·  B to cancel")
                or (verb .. "  ·  click the item / Esc to cancel")
        elseif Combat.hasMoved(battle.combat) then
            hint = pad and "A on a foe in range to attack  ·  Y to switch item  ·  X to hold this turn"
                or "Click a foe in range to attack  ·  click an item  ·  Wait to hold this turn"
        else
            hint = pad and "A on a blue tile to move  ·  a foe in red range to attack  ·  Y to arm  ·  X to delay"
                or "Click a blue tile to move  ·  a foe in red range to attack  ·  an item  ·  Wait to delay"
        end
    else
        hint = "Enemy acting..."
    end
    -- Hint sits just under the objective (a third top line) so the bottom gutter is free for
    -- the toggle-able combat log. Small font so the longest hint stays on one line, clear of the
    -- board top.
    love.graphics.setFont(hintFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.printf(hint, boardX, 82, boardW, "center")
    love.graphics.setColor(1, 1, 1)
end

function battle.keypressed(key)
    if key == "f5" then
        Arena.save(battle.arena, (battle.arena.biome or "arena") .. "_" .. os.time())
        return
    end
    if key == "f6" then -- debug: toggle initiative (timeline) numbers on the turn order
        battle.showInitiative = not battle.showInitiative
        return
    end
    if key == "l" then -- toggle the combat log (works whether or not the battle is over)
        battle.log:toggle()
        return
    end
    if key == "t" then -- toggle the all-enemy-attack-ranges danger overlay
        battle.showEnemyRanges = not battle.showEnemyRanges
        return
    end
    -- Scroll the turn-order strip toward later / earlier turns (read-only, so allowed once the
    -- battle is over too).
    if key == "pageup" then
        battle.panel:scrollBy(1)
        return
    elseif key == "pagedown" then
        battle.panel:scrollBy(-1)
        return
    end
    if battle.over then return end
    if key == "return" or key == "kpenter" then
        confirm()
    elseif key == "tab" or key == "kp0" or key == "0" or key == "space" then
        waitTurn()
    elseif key == "escape" then
        if battle.mode == "armed" then cancelArm() else lose() end
    elseif KEYPAD_SLOT[key] then
        armSlot(KEYPAD_SLOT[key]) -- numpad, mapped by physical position to the 3x3 item grid
    elseif key:match("^[1-9]$") then
        armSlot(tonumber(key))
    else
        battle.map:keypressed(key)
    end
end

function battle.gamepadpressed(joystick, button)
    if button == "leftshoulder" then -- toggle the combat log (allowed even when the battle is over)
        battle.log:toggle()
        return
    end
    if button == "rightshoulder" then -- page the turn-order strip, wrapping back to the actor
        battle.panel:cyclePage()
        return
    end
    if button == "leftstick" then -- toggle the all-enemy-attack-ranges danger overlay
        battle.showEnemyRanges = not battle.showEnemyRanges
        return
    end
    if battle.over then return end
    if button == "a" or button == "start" then
        confirm()
    elseif button == "x" then
        waitTurn()
    elseif button == "b" then
        if battle.mode == "armed" then cancelArm() else lose() end
    elseif button == "back" then
        lose()
    elseif button == "y" then
        cycleAbilityItem()
    else
        battle.map:gamepadpressed(joystick, button)
    end
end

function battle.mousemoved(x, y, dx, dy)
    battle.mouseX, battle.mouseY = x, y -- drives the status tooltip (board + panel hit-tests)
    -- Hovering the panel's Wait button previews the delay slot on the timeline.
    local overPanel = battle.panel:mousemoved(x, y)
    battle.hoverWait = battle.panel.waitHover and battle.current
        and Combat.isPlayerControlled(battle.current) and not battle.over and not walking() or false
    if overPanel then return end
    battle.map:mousemoved(x, y)
end

-- The wheel scrolls the turn-order strip from anywhere it makes sense: over the right panel OR over
-- the board (the two places the player watches the timeline from). The open combat log claims it
-- first when the cursor is inside it, so its own history still scrolls; contains() is false while
-- the log is closed, so a wheel over the board falls through to the strip.
function battle.wheelmoved(dx, dy)
    if battle.mouseX and battle.log:contains(battle.mouseX, battle.mouseY) then
        battle.log:wheelmoved(dx, dy)
        return
    end
    battle.panel:wheelmoved(dx, dy)
end

function battle.mousepressed(x, y, button)
    if button == 1 and pointIn(forfeitButton, x, y) then
        lose()
        return
    end
    if button == 1 and pointIn(logButton, x, y) then
        battle.log:toggle()
        return
    end
    if button == 1 and pointIn(rangesButton, x, y) then
        battle.showEnemyRanges = not battle.showEnemyRanges
        return
    end
    -- A click inside the open log panel is consumed by it (it must not fall through to a
    -- move/attack on the battlefield beneath).
    if battle.log:contains(x, y) then return end
    if battle.panel:mousepressed(x, y, button) then return end
    if battle.map:mousepressed(x, y, button) then confirm() end
end

-- Which context cursor to show under the mouse (see ui/cursor.lua). Mirrors mousepressed's region
-- precedence: a hand over the clickable UI (the left-column buttons, the open log, the right combat
-- panel), then the board -- where the stashed hoverAction (what a click would DO, from refreshView)
-- picks the glyph. While it's not the player's turn, the board reads "wait". Only consulted when the
-- mouse is the active device (main.lua gates on InputMode.isMouse()).
function battle.cursorKind()
    local mx, my = battle.mouseX, battle.mouseY
    if not mx then return "arrow" end
    -- Off the board: the clickable UI wants a pointing hand.
    if pointIn(forfeitButton, mx, my) or pointIn(logButton, mx, my) or pointIn(rangesButton, mx, my)
        or battle.log:contains(mx, my) or battle.panel:contains(mx, my) then
        return "hand"
    end
    if battle.over then return "arrow" end
    -- Enemy turn, a walk animation, or a channel resolving: a board click does nothing.
    if busy() or (battle.current and not Combat.isPlayerControlled(battle.current)) then
        return battle.map:cellAt(mx, my) and "wait" or "arrow"
    end
    local a = battle.hoverAction
    if not a then return "arrow" end -- a board tile with no valid action
    if a.kind == "move" then return a.blink and "blink" or "move" end
    if a.kind == "strikeTrap" then return "break" end
    if a.kind == "place" then return "target" end
    -- Striking or offensively casting on a foe: a sword for a physical hit, a wand for a magical
    -- one. The turn auto-arms the actor's default action, so an ordinary weapon attack arrives as
    -- an armed "ability" too -- the tag, not the kind, is what tells a sword swing from a spell.
    if a.kind == "attack" or (a.kind == "ability" and not a.support) then
        return itemHasTag(a.item, "magical") and "cast" or "attack"
    end
    if a.kind == "ability" and a.support then return "heal" end
    return "arrow"
end

return battle
