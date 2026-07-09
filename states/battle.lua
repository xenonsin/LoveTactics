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
local Arena = require("models.arena")
local BattleMap = require("ui.battle_map")
local CombatPanel = require("ui.combat_panel")
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

-- Clickable "Forfeit" button so a mouse-only player can bail out (counts as a loss), plus a
-- "Wait" button so a mouse-only player can end a turn without acting (a delay).
local forfeitButton = { x = 16, y = 16, w = 130, h = 36 }
local waitButton = { x = 16, y = 60, w = 130, h = 36 }
-- Toggles the combat-log panel on the left (also L / gamepad left-shoulder).
local logButton = { x = 16, y = 104, w = 130, h = 36 }

local function pointIn(btn, x, y)
    return x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h
end

-- Human-readable objective line for the HUD.
local function objectiveText(obj)
    if obj.type == "survive" then
        return "Objective: survive " .. (obj.turns or "?") .. " turns"
    elseif obj.type == "assassinate" then
        local target = obj.target and Character.defs[obj.target]
        return "Objective: defeat " .. ((target and target.name) or obj.target or "the target")
    end
    return "Objective: defeat all enemies"
end

-- Resolve the encounter's composition spec + objective. Placed encounters read their
-- blueprint; the objective tile reads the quest's `map.objective`.
local function specFor(opts, partyIds, seed)
    local spec = { biome = opts.biome, party = partyIds, seed = seed }
    local enc = opts.encounter or {}
    if enc.kind == "objective" then
        local obj = (opts.quest and opts.quest.map and opts.quest.map.objective) or {}
        spec.composition = obj.composition
        spec.objective = obj.win -- { type, target } win condition; nil -> killAll
    else
        local def = enc.id and EncounterModel.get(enc.id)
        spec.composition = def and def.composition
        spec.objective = def and def.objective
    end
    return spec
end

-- ---------------------------------------------------------------------------
-- Combat controller (all module-level locals so they close over `battle`; declared
-- before battle.enter so its panel callbacks can reference them as upvalues).
-- ---------------------------------------------------------------------------

local function win()
    battle.over = true
    Combat.logEvent(battle.combat, "system", "Victory!")
    if battle.onWin then battle.onWin() end
end

local function lose()
    battle.over = true
    Combat.logEvent(battle.combat, "system", "Defeat.")
    if battle.onLoss then battle.onLoss() end
end

-- Reachable tiles for the current unit (blue move highlights + move validity). A rooted unit
-- (a movement-blocking status) can't move this turn, so its reachable set is empty -- it can
-- still attack from where it stands.
local function computeReachable(unit)
    if Status.blocksMove(unit) then
        battle.reachable, battle.moveCells = {}, {}
        return
    end
    battle.reachable = Combat.reachable(battle.combat, unit)
    local cells = {}
    for _, node in pairs(battle.reachable) do
        cells[#cells + 1] = { x = node.x, y = node.y }
    end
    battle.moveCells = cells
end

-- The armed ability's valid-to-hit AREA (red for offensive, green for support): every tile the
-- ability could legally land on from where the unit stands -- in range, walkable (never a wall),
-- and in line of sight when the ability needs it. A tile it CAN'T validly hit is dropped, so the
-- highlight stops at cover and never falls on a unit of the wrong kind (an ally under an enemy
-- strike, a foe under a support cast). A tile-target ability (e.g. summoning a trap) additionally
-- needs an empty cell; a self-only ability can land only on the caster's own tile. Combat.useItem
-- re-checks all of this on confirm.
local function computeRange(unit, item)
    local ab = item.activeAbility
    local target = ab and ab.target
    -- A self-only ability can only ever land on the caster's own tile.
    if target == "self" then
        battle.rangeCells = { { x = unit.x, y = unit.y } }
        return
    end
    local range = Combat.abilityRange(battle.combat, unit, ab)
    local minRange = Combat.abilityMinRange(ab)
    local requiresSight = ab and ab.requiresSight
    local cells = {}
    for dx = -range, range do
        for dy = -range, range do
            local d = math.abs(dx) + math.abs(dy)
            if d <= range and d >= minRange then
                local x, y = unit.x + dx, unit.y + dy
                if x >= 1 and x <= battle.arena.cols and y >= 1 and y <= battle.arena.rows
                    and battle.arena.tiles[y][x].walkable
                    and (not requiresSight
                         or Combat.hasLineOfSight(battle.combat, unit.x, unit.y, x, y)) then
                    -- Drop cells the ability can't validly land on: a tile cast needs an empty
                    -- cell; a unit-target cast can't hit a unit of the wrong side (an empty tile
                    -- still shows, so the reach reads even with no one standing in it).
                    local occ = Combat.unitAt(battle.combat, x, y)
                    local valid
                    if target == "tile" then valid = occ == nil or ab.allowOccupied == true
                    elseif occ and target == "enemy" then valid = occ.side ~= unit.side
                    elseif occ and target == "ally" then valid = occ.side == unit.side
                    else valid = true end
                    if valid then cells[#cells + 1] = { x = x, y = y } end
                end
            end
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
    return Combat.aoeCells(battle.combat, ab, cx, cy)
end

-- The default-attack (threat) reach: where the unit could strike this turn with its default
-- weapon (first inventory weapon, else the hidden unarmed weapon), moving first if needed. Stores
-- `battle.defaultWeapon` + `battle.attackReach` (cell -> cheapest stand tile, which spans the whole
-- reach and drives click-to-attack pathing) and `battle.threatCells`, the RED highlight = the reach
-- band beyond movement, minus tiles that aren't valid to hit (the unit's own tile and any ally --
-- you can't strike a friend). Tiles inside the blue move band are left to the blue overlay so the
-- two never stack into a muddy overlap. Reads the live `battle.reachable`, so once the unit has
-- moved (reachable cleared) only what it can hit from where it now stands shows.
local function computeThreat(unit)
    local weapon = Combat.defaultWeapon(unit.char)
    battle.defaultWeapon = weapon
    local ab = weapon and weapon.activeAbility
    local range = (ab and ab.range) or 1
    battle.attackReach = Combat.attackReach(battle.combat, unit, range, battle.reachable,
        ab and ab.requiresSight, Combat.abilityMinRange(ab))

    local moveKeys = {}
    for _, c in ipairs(battle.moveCells) do moveKeys[c.x .. "," .. c.y] = true end

    local cells = {}
    for k, cell in pairs(battle.attackReach) do
        -- Show the reach, minus what can't be hit: the caster's own tile, tiles already lit blue
        -- (the move band), and any tile an ally occupies (a friendly unit is never a valid target).
        if not moveKeys[k] and not (cell.x == unit.x and cell.y == unit.y) then
            local occ = Combat.unitAt(battle.combat, cell.x, cell.y)
            if not (occ and occ.side == unit.side) then
                cells[#cells + 1] = { x = cell.x, y = cell.y }
            end
        end
    end
    battle.threatCells = cells
end

-- Start the current unit's turn: MOVE mode + reachable set for a party unit, or an AI
-- delay for an enemy.
local function beginTurn()
    local current = Combat.startTurn(battle.combat)
    battle.current = current
    battle.mode = "move"
    battle.armedItem = nil
    battle.hoverItem = nil
    battle.rangeCells = {}
    battle.moveCells = {}
    battle.threatCells = {}
    battle.attackReach = {}
    if not current then return end
    if current.side == "party" then
        computeReachable(current)
        computeThreat(current)
        battle.map.cursor.x, battle.map.cursor.y = current.x, current.y
    else
        battle.aiTimer = AI_DELAY
    end
end

-- Resolve the objective after an action; otherwise hand off to the next unit.
local function advanceTurn()
    local result = Combat.evaluate(battle.combat)
    if result == "win" then win() return
    elseif result == "loss" then lose() return end
    beginTurn()
end

local function cancelArm()
    battle.mode = "move"
    battle.armedItem = nil
end

-- Arm an ability item (or toggle it off if already armed).
local function armItem(item)
    local current = battle.current
    if battle.over or not current or current.side ~= "party" then return end
    if not (item and item.activeAbility) then return end
    if battle.armedItem == item then cancelArm() return end
    -- Can't afford it, or a consumable stack is spent: leave it disarmed (the slot is grayed out
    -- and the tooltip says why), so a number-key / gamepad arm can't silently fail on confirm the
    -- way a click already can't.
    if not Combat.canAfford(current.char, item.activeAbility) then return end
    if Combat.isDepleted(item) then return end
    -- An ability that needs a specific neighbor (e.g. Rain of Arrows requires an adjacent bow)
    -- stays disarmed until that neighbor is in place -- the slot is grayed and useItem would
    -- reject it anyway, so keep number-key / gamepad arming from silently failing on confirm.
    if not Combat.adjacencyMet(current.char, item) then return end
    battle.armedItem = item
    battle.mode = "armed"
    -- Friendly abilities (heal / buff) highlight green; offensive strikes and trap placements red.
    battle.armedSupport = Combat.isSupportAbility(item.activeAbility)
    battle.armedTile = item.activeAbility.target == "tile" -- tile-target (e.g. summon a trap)
    computeRange(current, item)
end

local function armSlot(n)
    local current = battle.current
    if not current or current.side ~= "party" then return end
    armItem(current.char.inventory[n])
end

-- Gamepad Y cycles through the current unit's ability items (past the end -> back to move).
local function cycleAbilityItem()
    local current = battle.current
    if battle.over or not current or current.side ~= "party" then return end
    local items = Combat.abilityItems(current.char)
    if #items == 0 then return end
    local idx = 0
    for i, it in ipairs(items) do
        if it == battle.armedItem then idx = i break end
    end
    if idx + 1 > #items then cancelArm() else armItem(items[idx + 1]) end
end

-- Basic attack on the enemy at (tx, ty) with the current unit's default weapon: if the
-- cheapest stand tile for that cell isn't where the unit already is, move there first (only if
-- it hasn't moved yet), then strike -- a click-to-attack that folds an approach into one action.
-- No-op if the target is out of this turn's threat reach, or the default weapon can't resolve
-- (e.g. an inventory weapon the unit can't afford -- unarmed itself is always free).
local function tryDefaultAttack(unit, tx, ty)
    local entry = battle.attackReach and battle.attackReach[tx .. "," .. ty]
    local weapon = battle.defaultWeapon
    if not entry or not weapon then return end
    -- Don't reposition for a strike we can't pay for: if the default weapon carries a cost the
    -- unit can't afford, bail before moving (unarmed is free, so this only guards real weapons).
    local ab = weapon.activeAbility
    if ab and ab.cost then
        local res = unit.char.stats[ab.cost.stat]
        local cur = (type(res) == "table" and res.current) or res or 0
        if cur < ab.cost.amount then return end
    end
    if entry.fromX ~= unit.x or entry.fromY ~= unit.y then
        if Combat.hasMoved(battle.combat) then return end -- can't move twice in a turn
        if not Combat.moveUnit(battle.combat, unit, entry.fromX, entry.fromY) then return end
        battle.reachable, battle.moveCells = {}, {}
    end
    if Combat.useItem(battle.combat, unit, weapon, tx, ty) then advanceTurn() end
end

-- Strike a revealed enemy trap on (tx, ty) with the default weapon, folding an approach move
-- into the strike exactly like tryDefaultAttack (attackReach records the cheapest stand tile).
-- Combat.strikeTrap re-checks range/visibility/cost; this just handles the click-to-destroy UX.
local function tryDamageTrap(unit, tx, ty)
    local entry = battle.attackReach and battle.attackReach[tx .. "," .. ty]
    local weapon = battle.defaultWeapon
    if not entry or not weapon then return end
    local ab = weapon.activeAbility
    if ab and ab.cost then
        local res = unit.char.stats[ab.cost.stat]
        local cur = (type(res) == "table" and res.current) or res or 0
        if cur < ab.cost.amount then return end
    end
    if entry.fromX ~= unit.x or entry.fromY ~= unit.y then
        if Combat.hasMoved(battle.combat) then return end
        if not Combat.moveUnit(battle.combat, unit, entry.fromX, entry.fromY) then return end
        battle.reachable, battle.moveCells = {}, {}
    end
    if Combat.strikeTrap(battle.combat, unit, weapon, tx, ty) then advanceTurn() end
end

-- A revealed enemy trap on (x, y), or nil. `battle.trapCells` is the per-frame lookup of traps
-- the party can currently see (refreshView), keyed "x,y".
local function revealedEnemyTrapAt(unit, x, y)
    local trap = battle.trapCells and battle.trapCells[x .. "," .. y]
    if trap and trap.side ~= unit.side then return trap end
    return nil
end

-- What confirming on cell (cx, cy) would DO right now, as a descriptor the action-preview tooltip
-- (ui/action_preview.lua) renders beside the character/tile tooltip. Mirrors confirm()'s branching
-- so the preview always names the very action a click would take:
--   { kind = "attack",     item, target, entry }  -- default-weapon strike on a foe
--   { kind = "strikeTrap", item, trap, trapDamage, trapLethal }  -- destroy a revealed enemy trap
--   { kind = "move",       moveCost, steps }       -- step to a reachable tile
--   { kind = "ability",    item, target, support, entry }  -- armed unit/self cast (heal/strike/...)
--   { kind = "place",      item }                  -- armed tile cast (summon a trap)
-- Returns nil when a click on this cell would do nothing (not the player's turn, out of reach, an
-- invalid target), so the tooltip only appears on an actionable hover. `entry` is the dry-run effect
-- on the target unit (Combat.previewAbility); `support` tints the panel green for a friendly cast.
local function actionPreviewFor(cx, cy)
    local current = battle.current
    if battle.over or not current or current.side ~= "party" then return nil end
    local unit = Combat.unitAt(battle.combat, cx, cy)

    if battle.mode == "armed" and battle.armedItem then
        local item = battle.armedItem
        if not item.activeAbility then return nil end
        -- Legal target cell = membership in the pre-computed valid range set (it already drops
        -- wrong-side occupants, non-empty tile casts, and out-of-sight cells).
        local valid = false
        for _, c in ipairs(battle.rangeCells or {}) do
            if c.x == cx and c.y == cy then valid = true break end
        end
        if not valid then return nil end
        local preview = Combat.previewAbility(battle.combat, current, item, cx, cy)
        return {
            kind = (item.activeAbility.target == "tile") and "place" or "ability",
            item = item, actor = current, target = unit, support = battle.armedSupport,
            entry = preview and unit and preview.entries[unit] or nil,
            entries = preview and preview.entries or nil, -- every affected unit (AoE), for banner preview
            order = preview and preview.order or nil, -- ordered affected units, for the AoE summary
        }
    end

    if battle.mode == "move" then
        -- A foe in the default-weapon threat reach -> click-to-attack (moving into reach first).
        if unit and unit.side ~= current.side and unit.alive then
            local weapon = battle.defaultWeapon
            if weapon and weapon.activeAbility
                and battle.attackReach and battle.attackReach[cx .. "," .. cy] then
                local preview = Combat.previewAbility(battle.combat, current, weapon, cx, cy)
                return { kind = "attack", item = weapon, actor = current, target = unit,
                         support = false, entry = preview and preview.entries[unit] or nil,
                         entries = preview and preview.entries or nil,
                         order = preview and preview.order or nil }
            end
            return nil
        end
        -- A revealed enemy trap in reach -> click-to-destroy.
        local trap = revealedEnemyTrapAt(current, cx, cy)
        if trap and battle.attackReach and battle.attackReach[cx .. "," .. cy] then
            local weapon = battle.defaultWeapon
            local dmg = weapon and Combat.computeTrapDamage(current, weapon) or 0
            return { kind = "strikeTrap", item = weapon, actor = current, trap = trap,
                     support = false, trapDamage = dmg, trapLethal = dmg >= (trap.health or 0) }
        end
        -- An empty reachable tile -> move there.
        local node = battle.reachable and battle.reachable[cx .. "," .. cy]
        if node then
            return { kind = "move", actor = current, moveCost = node.cost, steps = node.steps }
        end
    end

    return nil
end

-- Confirm on the cursor cell: move there (does NOT end the turn -- the unit can still act or
-- wait), attack an enemy on it with the default weapon (moving into reach first), or use the
-- armed item on it (ends the turn).
local function confirm()
    local current = battle.current
    if battle.over or not current or current.side ~= "party" then return end
    local cx, cy = battle.map.cursor.x, battle.map.cursor.y
    if battle.mode == "move" then
        local target = Combat.unitAt(battle.combat, cx, cy)
        if target and target.side ~= current.side then
            tryDefaultAttack(current, cx, cy)
        elseif revealedEnemyTrapAt(current, cx, cy) then
            tryDamageTrap(current, cx, cy)
        elseif battle.reachable[cx .. "," .. cy] then
            if Combat.moveUnit(battle.combat, current, cx, cy) then
                -- Move spent: clear the reachable set (only one move per turn), recompute the
                -- threat band from the new tile, and stay in this turn so the player can arm an
                -- item or wait. The per-frame refreshView in battle.update picks up the state.
                battle.reachable, battle.moveCells = {}, {}
                computeThreat(current)
            end
        end
    elseif battle.mode == "armed" and battle.armedItem then
        if Combat.useItem(battle.combat, current, battle.armedItem, cx, cy) then advanceTurn() end
    end
end

-- End the current party unit's turn without acting. The default is a delay (Combat.wait), but an
-- item may swap this into Focus (restore mana) or Defend (a defensive stance) -- see
-- Combat.waitBehavior. Available whether or not the unit moved.
local function waitTurn()
    local current = battle.current
    if battle.over or not current or current.side ~= "party" then return end
    local kind = Combat.waitBehavior(current).kind
    local action = (kind == "focus" and Combat.focus)
        or (kind == "defend" and Combat.defend)
        or Combat.wait
    if action(battle.combat, current) then advanceTurn() end
end

local function executeEnemyAction()
    local current = battle.current
    if not current or current.side ~= "enemy" then return end
    local act = Combat.planEnemyAction(battle.combat, current)
    if act.move then Combat.moveUnit(battle.combat, current, act.move.x, act.move.y) end
    local acted = false
    if act.item then acted = Combat.useItem(battle.combat, current, act.item, act.tx, act.ty) end
    -- Reposition-only, nothing to do, or an item use that unexpectedly failed: pass so the
    -- turn always ends (paying the real move cost) and never soft-locks on this unit.
    if not acted then Combat.pass(battle.combat, current) end
    advanceTurn()
end

-- Compute the turn-order preview + battlefield overlays and hand them to the widgets.
local function refreshView()
    local current = battle.current
    if not current then return end
    local isParty = current.side == "party" and not battle.over

    -- Preview the projected initiative the pending action would give the actor. The actor
    -- sits at initiative 0; a move already taken this turn is folded in via the pending move
    -- cost, and a wait previews the delay slot (next unit's initiative + 1).
    local newInit
    if isParty then
        local pendingMove = (battle.combat.turn and battle.combat.turn.moveCost) or 0
        if battle.hoverWait then
            local nxt
            for _, u in ipairs(Combat.turnOrder(battle.combat)) do
                if u ~= current then nxt = u.initiative break end
            end
            newInit = nxt and math.max(pendingMove, nxt + 1) or (pendingMove + Combat.WAIT_COST)
        elseif battle.hoverItem and battle.hoverItem.activeAbility then
            newInit = pendingMove + (battle.hoverItem.activeAbility.speed or 0)
        elseif battle.mode == "armed" and battle.armedItem then
            newInit = pendingMove + (battle.armedItem.activeAbility.speed or 0)
        elseif battle.mode == "move" then
            local node = battle.reachable and battle.reachable[battle.map.cursor.x .. "," .. battle.map.cursor.y]
            if node then newInit = node.cost end
        end
    end
    -- Timeline entries for the panel: the live order, plus a ghost of the actor at its
    -- projected slot while a move/item/wait is being previewed.
    local entries
    if newInit then
        entries = Combat.previewTimeline(battle.combat, current, newInit)
    else
        entries = {}
        for _, u in ipairs(Combat.turnOrder(battle.combat)) do
            entries[#entries + 1] = { unit = u, preview = false, initiative = u.initiative }
        end
    end

    -- Board highlights: the acting unit always, plus whichever unit the timeline is hovering.
    local overlays = { move = {}, range = {} }
    local hoverAbility = battle.hoverItem and battle.hoverItem.activeAbility
    if isParty and battle.mode == "armed" then
        overlays.range = battle.rangeCells
        overlays.rangeSupport = battle.armedSupport
        -- An armed AoE ability paints its blast footprint around the aimed cell (the cursor),
        -- brighter than the range wash, so the player sees exactly which tiles the cast sweeps.
        overlays.aoe = aoeFootprint(battle.armedItem, battle.map.cursor.x, battle.map.cursor.y)
        overlays.aoeSupport = battle.armedSupport
    elseif isParty and hoverAbility then
        -- Hovering an ability slot previews that item's range on the board (without arming it),
        -- green for a friendly target, red for an offensive one -- mirroring the armed look.
        computeRange(current, battle.hoverItem)
        overlays.range = battle.rangeCells
        overlays.rangeSupport = Combat.isSupportAbility(hoverAbility)
    elseif isParty then
        overlays.move = battle.moveCells
        overlays.threat = battle.threatCells -- red default-attack reach beyond the move band
    end
    overlays.current = { x = current.x, y = current.y }
    local hover = battle.hoverUnit
    if hover and hover.alive then overlays.hover = { x = hover.x, y = hover.y } end

    -- Traps the party can currently see (its own + detected enemy traps): a per-frame lookup for
    -- click-to-damage (revealedEnemyTrapAt) and the list the renderer draws.
    battle.revealedTraps = Trap.revealedTo(battle.combat, "party")
    battle.trapCells = {}
    for _, t in ipairs(battle.revealedTraps) do battle.trapCells[t.x .. "," .. t.y] = t end
    overlays.traps = battle.revealedTraps

    -- Hazards (fire/rain/sanctuary) are always visible to both sides, so the renderer draws the whole
    -- live list -- no per-side visibility filter like traps have.
    overlays.hazards = battle.combat.hazards

    -- Preview resources lost / damage dealt on the turn-order banners: the action under the mouse
    -- (the same one the tile tooltip shows) projects its damage/heal onto every affected unit's
    -- banner and its resource cost onto the actor's banner. Computed after the range/reach overlays
    -- so actionPreviewFor sees the current valid-target sets.
    local bannerPreview
    if isParty and battle.mouseX then
        local cx, cy = battle.map:cellAt(battle.mouseX, battle.mouseY)
        local action = cx and actionPreviewFor(cx, cy)
        if action then
            bannerPreview = {}
            if action.entries then
                for tgt, e in pairs(action.entries) do
                    bannerPreview[tgt] = { damage = e.damage, heal = e.heal, lethal = e.lethal }
                end
            end
            local ab = action.item and action.item.activeAbility
            if action.actor and ab and ab.cost then
                local a = bannerPreview[action.actor] or {}
                a.cost = { stat = ab.cost.stat, amount = ab.cost.amount }
                bannerPreview[action.actor] = a
            end
        end
    end

    battle.panel:setView({
        order = entries, current = current, isPartyTurn = isParty,
        items = (current.side == "party") and current.char.inventory or {},
        itemOwner = (current.side == "party") and current.char or nil, -- for adjacency link lines
        armedItem = battle.armedItem,
        showInitiative = battle.showInitiative,
        preview = bannerPreview,
    })

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
    for _, u in ipairs(battle.arena.enemies) do
        battle.enemyUnits[#battle.enemyUnits + 1] =
            { char = Character.instantiate(u.id), x = u.x, y = u.y }
    end

    battle.combat = Combat.new(battle.arena, battle.partyUnits, battle.enemyUnits)
    battle.map = BattleMap.new(battle.arena,
        { combat = battle.combat, leftMargin = LEFT_W, rightMargin = PANEL_W,
          tileSize = BOARD_TILE, topMargin = BOARD_TOP })
    battle.panel = CombatPanel.new(battle.combat, {
        onActivateItem = function(item) armItem(item) end,
        onHoverItem = function(item) battle.hoverItem = item end,
        onHoverUnit = function(unit) battle.hoverUnit = unit end,
    })
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
    if not battle.over and battle.current and battle.current.side == "enemy" then
        battle.aiTimer = (battle.aiTimer or 0) - dt
        if battle.aiTimer <= 0 then executeEnemyAction() end
    end
    refreshView()
end

function battle.draw()
    love.graphics.setColor(0.04, 0.05, 0.07)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    battle.drawLeftColumn()
    battle.map:draw()
    battle.panel:draw()
    battle.drawHud()
    battle.log:draw()

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
    local dockTop, gap = 150, 8

    -- Terrain box at the very bottom of the column. Any hazards on the tile ride along on the same
    -- info so they read as a section directly above the terrain (and below the occupant box).
    local terrainBox = TileTooltip.draw(
        { cell = cell, bonus = Combat.fieldBonus(battle.combat, cx, cy),
          hazards = Hazard.allAt(battle.combat, cx, cy) },
        mx, my, maxRight, { dock = true, dockX = 16, dockTop = dockTop, width = W })
    local topBox = terrainBox

    -- Occupant (unit or trap) in its own box, separated from the terrain by a gap.
    local objInfo
    if unit and unit.char then objInfo = { unit = unit, preview = preview }
    elseif trap then objInfo = { trap = trap, preview = preview } end
    if objInfo then
        local objBox = TileTooltip.draw(objInfo, mx, my, maxRight,
            { dock = true, dockX = 16, dockTop = dockTop, width = W,
              dockBottom = (terrainBox and terrainBox.y or Scale.HEIGHT - 8) - gap })
        if objBox then topBox = objBox end
    end

    -- Action preview above whatever box is currently on top.
    if action and topBox then
        ActionPreview.draw(action, topBox, maxRight, { placement = "above", dockTop = dockTop, width = W })
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

    -- Wait / End Turn button, active only on a party unit's turn.
    local canWait = battle.current and battle.current.side == "party" and not battle.over
    if canWait then love.graphics.setColor(0.18, 0.22, 0.30) else love.graphics.setColor(0.14, 0.15, 0.18) end
    love.graphics.rectangle("fill", waitButton.x, waitButton.y, waitButton.w, waitButton.h, 6, 6)
    if canWait then love.graphics.setColor(0.5, 0.65, 0.85) else love.graphics.setColor(0.3, 0.32, 0.38) end
    love.graphics.rectangle("line", waitButton.x, waitButton.y, waitButton.w, waitButton.h, 6, 6)
    if canWait then love.graphics.setColor(0.9, 0.94, 1) else love.graphics.setColor(0.5, 0.52, 0.58) end
    love.graphics.setFont(hudFont)
    -- Label reflects the acting unit's wait behavior (item-swapped Focus / Defend, else Wait).
    local waitLabel = "Wait"
    if battle.current then
        local kind = Combat.waitBehavior(battle.current).kind
        waitLabel = (kind == "focus" and "Focus") or (kind == "defend" and "Defend") or "Wait"
    end
    love.graphics.printf(waitLabel, waitButton.x, waitButton.y + waitButton.h / 2 - 8, waitButton.w, "center")

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

    -- Encounter name + objective, centred over the battlefield region.
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(battle.encounter.name or "Battle", boardX, 20, boardW, "center")

    love.graphics.setFont(hudFont)
    love.graphics.setColor(0.85, 0.85, 0.9)
    love.graphics.printf(objectiveText(battle.arena.objective), boardX, 52, boardW, "center")

    -- Contextual control hint.
    local hint
    if battle.current and battle.current.side == "party" and not battle.over then
        if battle.mode == "armed" then
            local verb
            if battle.armedTile then verb = "Click a tile to place the trap"
            elseif battle.armedSupport then verb = "Click an ally to support"
            else verb = "Click a target to strike" end
            hint = verb .. "  ·  click the item / Esc to cancel"
        elseif Combat.hasMoved(battle.combat) then
            hint = "Click a foe in range to attack  ·  click an item  ·  Wait to hold this turn"
        else
            hint = "Click a blue tile to move  ·  a foe in red range to attack  ·  an item  ·  Wait to delay"
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
    if battle.over then return end
    if key == "return" or key == "kpenter" or key == "space" then
        confirm()
    elseif key == "tab" then
        waitTurn()
    elseif key == "escape" then
        if battle.mode == "armed" then cancelArm() else lose() end
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
    -- Hovering the Wait button previews the delay slot on the timeline.
    battle.hoverWait = pointIn(waitButton, x, y)
        and battle.current and battle.current.side == "party" and not battle.over or false
    if battle.panel:mousemoved(x, y) then return end
    battle.map:mousemoved(x, y)
end

function battle.wheelmoved(dx, dy)
    battle.log:wheelmoved(dx, dy)
end

function battle.mousepressed(x, y, button)
    if button == 1 and pointIn(forfeitButton, x, y) then
        lose()
        return
    end
    if button == 1 and pointIn(waitButton, x, y) then
        waitTurn()
        return
    end
    if button == 1 and pointIn(logButton, x, y) then
        battle.log:toggle()
        return
    end
    -- A click inside the open log panel is consumed by it (it must not fall through to a
    -- move/attack on the battlefield beneath).
    if battle.log:contains(x, y) then return end
    if battle.panel:mousepressed(x, y, button) then return end
    if battle.map:mousepressed(x, y, button) then confirm() end
end

return battle
