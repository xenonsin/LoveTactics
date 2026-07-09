-- Turn-based combat logic. Pure model (no love.graphics; not even love.math), so it
-- loads under the headless tests, mirroring models/arena.lua and models/overworld.lua.
-- The battle state (states/battle.lua) and its renderer drive this module; all rules
-- live here.
--
-- Combat runs on an *initiative countdown*. Each unit has an `initiative` >= 0; the living
-- unit with the LOWEST initiative acts next, and the unit whose turn it is always sits at 0.
-- A unit's starting initiative is the average `speed` of its ability items (items with an
-- activeAbility) MINUS its `speed` stat, so faster kit and a higher speed stat both act
-- sooner; the whole field is then rebased so the fastest unit is at 0. Ties (equal
-- initiative) are broken by `speed` (higher acts first).
--
-- A *turn* spans an optional move (once) plus one terminating action. `Combat.startTurn`
-- opens the current unit's turn; `Combat.moveUnit` repositions it WITHOUT ending the turn
-- (it just records the terrain-weighted move cost); then either `Combat.useItem` or
-- `Combat.wait` ends the turn. Ending a turn sets the actor's initiative to its cost and then
-- REBASES: subtract the new minimum initiative from every unit, so the next unit drops to 0.
--   * item action -> initiative = moveCost + ability.speed
--   * wait (delay) -> initiative = max(moveCost, nextUnit.initiative + 1): land one tick after
--     the next unit in line, but never before the move you took is paid for.
-- `moveCost` is the Dijkstra path cost (rough terrain costs more), so difficult ground both
-- shortens reach and costs more time. `combat.clock` accumulates the elapsed initiative (the
-- amount subtracted each rebase) so the `survive N turns` objective still works.
--
--   local combat = Combat.new(arena, partyUnits, enemyUnits)  -- units: { { char, x, y }, ... }
--   local unit = Combat.startTurn(combat)                     -- open the current unit's turn
--   Combat.moveUnit(combat, unit, x, y)                       -- optional; doesn't end the turn
--   Combat.useItem(combat, unit, item, targetX, targetY)      -- or Combat.wait(combat, unit)
--   local result = Combat.evaluate(combat)                    -- "win" | "loss" | nil
--
-- Item abilities carry an `effect(fx)` FUNCTION (see data/items/*.lua). useItem builds an
-- `fx` context with bound helpers (fx.damage / fx.heal / fx.unitsNear) so a data file
-- composes effects without requiring this module. All the damage/heal math lives in the
-- helpers (Combat.dealDamage / Combat.applyHeal).
--
-- Status effects (models/status.lua) and traps (models/trap.lua) hook into this module: statuses
-- tick down inside rebase, gate/charge movement, and fire on turn start/end; traps live in
-- combat.traps, trigger as a unit paths over them (Combat.moveUnit), and can be struck down
-- (Combat.strikeTrap). Both are required here; NEITHER requires this module at load time (they
-- pull combat helpers through a lazy require), so there is no require cycle.

local Status = require("models.status")
local Trap = require("models.trap")
local Hazard = require("models.hazard")
local Character = require("models.character")

local Combat = {}

-- Ability-speed fallback for a unit that carries no ability item at all.
Combat.DEFAULT_SPEED = 5

-- Initiative cost of the Focus / Defend wait-behaviors (see Combat.focus / Combat.defend) when
-- the granting item doesn't specify its own. Deliberately larger than a plain wait's near-zero
-- delay -- these actions trade a big chunk of the timeline for mana / a defense buff. Focus costs
-- the most: recovering mana for free should give up a real turn's worth of tempo.
Combat.FOCUS_SPEED = 10
Combat.DEFEND_SPEED = 5

-- Line-of-sight block threshold: a line is obstructed once the summed `sightCost` of the tiles
-- it crosses (endpoints excluded) REACHES this. Soft cover (forest, sightCost 1) only lowers a
-- line, so two stacked tiles block; mountain (2) / obstacle (huge) block on their own. See
-- Arena.TILE_PROPS and Combat.hasLineOfSight.
Combat.SIGHT_BLOCK = 2

-- Fallback wait cost when there is no other living unit to delay past (the battle is
-- effectively already decided, but this keeps the clock advancing).
Combat.WAIT_COST = Combat.DEFAULT_SPEED

-- Deterministic tie-break when two units share an initiative AND a speed: party before
-- enemy, then spawn order. (Speed is the primary tie-break; see orderBy.)
local SIDE_RANK = { party = 0, enemy = 1 }

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

local function key(x, y) return x .. "," .. y end

local function manhattan(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do
        if t == want then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Combat log
-- ---------------------------------------------------------------------------

-- Newest-last rolling log of battlefield events, shown by the toggleable combat-log panel
-- (ui/combat_log.lua). Pure data (a { kind, text, turn } list on combat.log), so it stays
-- headless-safe: the model records events here and the UI colours them by `kind`. Status and
-- trap modules reach this through their lazy require of this module, so trap triggers and
-- status ticks land in the same stream in the order they happen.
Combat.LOG_CAP = 300 -- keep the tail; drop the oldest beyond this so it can't grow unbounded

function Combat.logEvent(combat, kind, text)
    if not text then return end
    local log = combat.log
    if not log then log = {}; combat.log = log end
    log[#log + 1] = { kind = kind or "system", text = text, turn = combat.turnCount or 0 }
    if #log > Combat.LOG_CAP then table.remove(log, 1) end
end

-- The display name of a unit for log lines (falls back to a generic label).
local function unitName(unit)
    return (unit and unit.char and unit.char.name) or "Unit"
end

-- Walk the tiles a straight line crosses from (x0,y0) to (x1,y1) inclusive (Bresenham),
-- calling visit(x, y) for each. A diagonal step threads the corner -- it jumps straight to the
-- next diagonal cell without visiting either side tile -- so a lone blocker at a corner never
-- seals a line. Used only by hasLineOfSight.
local function traceLine(x0, y0, x1, y1, visit)
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx - dy
    local x, y = x0, y0
    while true do
        visit(x, y)
        if x == x1 and y == y1 then break end
        local e2 = 2 * err
        if e2 > -dy then err = err - dy; x = x + sx end
        if e2 < dx then err = err + dx; y = y + sy end
    end
end

-- Is there a clear line of sight between (x0,y0) and (x1,y1)? True when the summed `sightCost`
-- of the tiles the line crosses -- EXCLUDING the two endpoints, so a unit always sees its own
-- tile and its target's even on cover -- stays below Combat.SIGHT_BLOCK. Off-map cells count as
-- transparent (they can't sit between two in-bounds tiles anyway). Endpoints are canonicalised
-- so A->B and B->A always agree. Ability targeting (Combat.useItem / abilityTargets), the
-- threat-reach highlight, and the enemy AI all gate ranged (`ab.requiresSight`) actions on this.
function Combat.hasLineOfSight(combat, x0, y0, x1, y1)
    if x0 == x1 and y0 == y1 then return true end
    -- Canonical endpoint order (smaller x, then smaller y first) so the trace is symmetric.
    if x1 < x0 or (x1 == x0 and y1 < y0) then
        x0, y0, x1, y1 = x1, y1, x0, y0
    end
    local tiles = combat.arena and combat.arena.tiles
    if not tiles then return true end
    local total = 0
    traceLine(x0, y0, x1, y1, function(x, y)
        if (x == x0 and y == y0) or (x == x1 and y == y1) then return end
        local row = tiles[y]
        local cell = row and row[x]
        total = total + ((cell and cell.sightCost) or 0)
    end)
    return total < Combat.SIGHT_BLOCK
end

-- Items in a character's inventory that define an active ability (the ones that feed
-- initiative and can be used as an action).
function Combat.abilityItems(char)
    local list = {}
    for _, item in ipairs(Character.eachItem(char)) do
        if item.activeAbility then list[#list + 1] = item end
    end
    return list
end

-- The unit's "default attack" weapon: the first inventory item of `type == "weapon"` that
-- carries an ability, in inventory (row-major grid) order -- so a lower slot wins. Falls back
-- to the character's hidden unarmed weapon (models/character.lua attaches `char.unarmed`) when
-- it carries no weapon. Drives the default-attack (threat) range highlight and the click-to-
-- attack basic strike. May be nil only for a hand-built char with neither.
function Combat.defaultWeapon(char)
    for _, item in ipairs(Character.eachItem(char)) do
        if item.type == "weapon" and item.activeAbility then return item end
    end
    return char.unarmed
end

-- The character's `speed` stat (0 if unset), used as the primary tie-break and folded into
-- the starting initiative.
function Combat.speed(char)
    return (char.stats and char.stats.speed) or 0
end

-- Starting initiative = the average speed of the character's ability items (DEFAULT_SPEED if
-- it has none) MINUS its `speed` stat, so a higher speed stat acts sooner. Lower acts sooner;
-- Combat.new rebases the field (which may go negative here) so the fastest unit begins at 0.
function Combat.initiative(char)
    local items = Combat.abilityItems(char)
    local avg
    if #items == 0 then
        -- No ability items: fall back to the hidden unarmed weapon's speed (which is itself
        -- DEFAULT_SPEED), so a bare unit's timing matches its always-available basic attack.
        avg = (char.unarmed and char.unarmed.activeAbility.speed) or Combat.DEFAULT_SPEED
    else
        local sum = 0
        for _, item in ipairs(items) do
            sum = sum + (item.activeAbility.speed or Combat.DEFAULT_SPEED)
        end
        avg = sum / #items
    end
    return avg - Combat.speed(char)
end

-- Effective flat stat for a unit: the character's base plus aggregated item bonuses
-- (armor) plus any active status modifier (e.g. Defending's temporary +defense). Resource
-- stats ({max,current}) are never read through here.
local function flatStat(unit, name)
    local base = unit.char.stats[name] or 0
    return base + ((unit.bonus and unit.bonus[name]) or 0) + Status.statBonus(unit, name)
end

-- The unit's effective movement budget (base + item bonus). Public so status hooks (root's
-- "pay as if you moved max spaces") can read it without duplicating the passive folding.
function Combat.moveBudget(unit)
    return flatStat(unit, "movement")
end

-- Positional ("field") bonuses a unit gains from WHERE it stands, as an aggregated bag of flat
-- modifiers, e.g. { range = 1 }. Sources: the terrain tile it occupies (Arena tile `bonus`,
-- carried onto the runtime cell) and any placed field objects on that tile (combat.fieldObjects,
-- each { x, y, bonus = {...} } -- e.g. a future vantage totem). Unlike item bonuses (unit.bonus,
-- fixed for the battle) these move with the unit, so they're computed on demand. Deliberately
-- generic: a new buff source only has to contribute here.
function Combat.fieldBonus(combat, x, y)
    local out = {}
    local function add(mods)
        for k, v in pairs(mods or {}) do out[k] = (out[k] or 0) + v end
    end
    local tiles = combat.arena and combat.arena.tiles
    local cell = tiles and tiles[y] and tiles[y][x]
    if cell then add(cell.bonus) end
    for _, obj in ipairs(combat.fieldObjects or {}) do
        if obj.alive ~= false and obj.x == x and obj.y == y then add(obj.bonus) end
    end
    return out
end

-- Effective range of ability `ab` for `unit` acting from tile (x, y) -- the ability's base range
-- plus any `range` field bonus that tile grants (high ground, a vantage object). Defaults to the
-- unit's current tile. The single source of truth for reach, so a positional buff extends
-- targeting, the threat/range highlights, and the enemy AI's planning alike.
function Combat.abilityRange(combat, unit, ab, x, y)
    local base = (ab and ab.range) or 1
    return base + (Combat.fieldBonus(combat, x or unit.x, y or unit.y).range or 0)
end

-- Minimum range of ability `ab`: a fixed "dead zone" a target must be at least this far away to be
-- hit (a bow can't fire point-blank). Defaults to 0 (no restriction). Unlike Combat.abilityRange
-- this gets NO tile field bonus -- a vantage point extends max reach, it doesn't shrink the dead zone.
function Combat.abilityMinRange(ab)
    return (ab and ab.minRange) or 0
end

-- Cells an area-of-effect ability centred on (tx, ty) covers, clamped to the arena. An ability's
-- optional `aoe = { radius = r, shape = "square"|"diamond" }` defines the blast footprint:
--   * "square" (default) -- every cell within Chebyshev distance r, i.e. the (2r+1)^2 block
--                           "including the corners" (a fireball's boxy burst).
--   * "diamond"          -- every cell within Manhattan distance r (a pointed burst, no corners).
-- With no `aoe` (or radius 0) the footprint is just the target cell, so a single-target ability
-- and an AoE one share one path. The single source of truth for BOTH what a cast hits (fx.aoeUnits)
-- and the red/green footprint highlight the battle state previews, so the two can never disagree.
function Combat.aoeCells(combat, ab, tx, ty)
    local aoe = ab and ab.aoe
    local r = (aoe and aoe.radius) or 0
    local diamond = aoe and aoe.shape == "diamond"
    local cols = (combat.arena and combat.arena.cols) or 0
    local rows = (combat.arena and combat.arena.rows) or 0
    local cells = {}
    for dx = -r, r do
        for dy = -r, r do
            if not diamond or (math.abs(dx) + math.abs(dy) <= r) then
                local x, y = tx + dx, ty + dy
                if x >= 1 and x <= cols and y >= 1 and y <= rows then
                    cells[#cells + 1] = { x = x, y = y }
                end
            end
        end
    end
    return cells
end

-- Living units standing on an ability's AoE footprint centred on (tx, ty) -- everyone a cast would
-- sweep, friend or foe. Reached through `fx.aoeUnits` so a data-file effect just iterates and hits;
-- a single-target ability (no `aoe`) yields only the occupant of the target cell, if any.
function Combat.aoeUnits(combat, ab, tx, ty)
    local out = {}
    for _, c in ipairs(Combat.aoeCells(combat, ab, tx, ty)) do
        local u = Combat.unitAt(combat, c.x, c.y)
        if u then out[#out + 1] = u end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

-- Fold passive armor into each unit: aggregate `item.bonus` (flat stat bonuses) and
-- `item.resist` (tag -> flat damage reduction) onto the unit WITHOUT mutating the shared
-- character instance, so a member's base stats never drift battle-to-battle.
function Combat.applyPassives(combat)
    for _, unit in ipairs(combat.units) do
        unit.bonus, unit.resist = {}, {}
        for _, item in ipairs(Character.eachItem(unit.char)) do
            for stat, amount in pairs(item.bonus or {}) do
                unit.bonus[stat] = (unit.bonus[stat] or 0) + amount
            end
            for tag, amount in pairs(item.resist or {}) do
                unit.resist[tag] = (unit.resist[tag] or 0) + amount
            end
        end
    end
end

-- Build combat state. partyUnits/enemyUnits are lists of { char = <instance>, x, y }
-- (exactly what states/battle.lua keeps as partyUnits/enemyUnits).
function Combat.new(arena, partyUnits, enemyUnits)
    local combat = {
        arena = arena,
        objective = (arena and arena.objective) or { type = "killAll" },
        units = {},
        clock = 0,      -- accumulated elapsed initiative (drives `survive`)
        turnCount = 0,  -- number of actions taken
        turn = nil,     -- the in-progress turn: { unit, moved, moveCost } (see startTurn)
        log = {},       -- rolling event log for the combat-log panel (Combat.logEvent)
    }

    local function addSide(list, side)
        for _, u in ipairs(list or {}) do
            local unit = {
                char = u.char, side = side,
                x = u.x, y = u.y,
                initiative = Combat.initiative(u.char),
                speed = Combat.speed(u.char), -- primary tie-break
                alive = true,
            }
            unit.index = #combat.units + 1
            combat.units[unit.index] = unit
            -- Between-battle policy: stamina refills to max each battle (it's the renewable
            -- resource), while mana persists on the reused party instance (spent mana stays
            -- spent). Enemies are freshly instantiated, so this is a harmless no-op for them.
            if side == "party" then
                local st = unit.char.stats.stamina
                if type(st) == "table" then st.current = st.max end
            end
        end
    end
    addSide(partyUnits, "party")
    addSide(enemyUnits, "enemy")

    -- Rebase so the fastest unit starts at initiative 0 (the current-actor convention). The
    -- initial offset isn't elapsed battle time, so reset the clock to 0 afterwards.
    Combat.rebase(combat)
    combat.clock = 0
    Combat.applyPassives(combat)

    -- Authored traps: arena.traps is a list of { id, x, y, side } (side defaults to "enemy",
    -- i.e. hidden from the player until detected). In-combat placement adds more via fx.placeTrap.
    combat.traps = {}
    for _, t in ipairs((arena and arena.traps) or {}) do
        Trap.place(combat, t.x, t.y, t.id, t.side or "enemy")
    end

    -- Hazards: persistent area effects (fire/rain/sanctuary). Authored via arena.hazards
    -- ({ id, x, y }); in-combat placement adds more via fx.placeHazard. Always visible, per-cell.
    combat.hazards = {}
    for _, h in ipairs((arena and arena.hazards) or {}) do
        Hazard.place(combat, h.x, h.y, h.id, { side = h.side, duration = h.duration })
    end

    -- Authored traps are placed above WITHOUT logging (they're hidden until detected); the log
    -- opens on a clean "battle begins" line so the panel isn't empty on the first frame.
    Combat.logEvent(combat, "system", "The battle begins.")

    return combat
end

-- Subtract the lowest living initiative from every living unit so the next actor sits at 0,
-- and add that amount to the elapsed clock. Called at construction and after each turn ends.
function Combat.rebase(combat)
    local minInit
    for _, u in ipairs(combat.units) do
        if u.alive and (not minInit or u.initiative < minInit) then minInit = u.initiative end
    end
    if not minInit then return end
    for _, u in ipairs(combat.units) do
        if u.alive then u.initiative = u.initiative - minInit end
    end
    combat.clock = combat.clock + minInit
    -- The subtracted amount IS the ticks that just elapsed: count status durations down by it,
    -- count hazard durations down (and let fire spread) by it, and regenerate stamina by the same time.
    Status.tick(combat, minInit)
    Hazard.tick(combat, minInit)
    Combat.regenerate(combat, minInit)
end

-- Passive stamina recovery: each living unit regains its staminaRegen rate per elapsed tick,
-- clamped to max. Mana deliberately does NOT regenerate. Called from rebase with the ticks that
-- just elapsed (the same amount fed to Status.tick), so recovery scales with time on the clock.
function Combat.regenerate(combat, elapsed)
    if not elapsed or elapsed <= 0 then return end
    for _, u in ipairs(combat.units) do
        if u.alive then
            Combat.restoreResource(u.char, "stamina", flatStat(u, "staminaRegen") * elapsed)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

function Combat.unitAt(combat, x, y)
    for _, u in ipairs(combat.units) do
        if u.alive and u.x == x and u.y == y then return u end
    end
    return nil
end

function Combat.unitsNear(combat, x, y, radius)
    radius = radius or 0
    local out = {}
    for _, u in ipairs(combat.units) do
        if u.alive and manhattan(x, y, u.x, u.y) <= radius then out[#out + 1] = u end
    end
    return out
end

function Combat.aliveCount(combat, side)
    local n = 0
    for _, u in ipairs(combat.units) do
        if u.alive and (not side or u.side == side) then n = n + 1 end
    end
    return n
end

-- Order living units by turn using `initOf(unit)` for each unit's initiative: lowest first,
-- then higher `speed` (the faster unit wins a tie), then the deterministic tie-break (party
-- before enemy, then index). `initOf` lets previewOrder substitute a hypothetical initiative
-- for one unit without mutating.
local function orderBy(combat, initOf)
    local order = {}
    for _, u in ipairs(combat.units) do
        if u.alive then order[#order + 1] = u end
    end
    table.sort(order, function(a, b)
        local ia, ib = initOf(a), initOf(b)
        if ia ~= ib then return ia < ib end
        if a.speed ~= b.speed then return a.speed > b.speed end
        if a.side ~= b.side then return SIDE_RANK[a.side] < SIDE_RANK[b.side] end
        return a.index < b.index
    end)
    return order
end

-- Living units ordered by turn: lowest initiative first, then the deterministic tie-break.
function Combat.turnOrder(combat)
    return orderBy(combat, function(u) return u.initiative end)
end

-- Turn order computed as if `unit.initiative == newInit`, without mutating any unit. Drives
-- the UI's hover preview: newInit is `moveCost` for a move or `moveCost + speed` for an item.
function Combat.previewOrder(combat, unit, newInit)
    return orderBy(combat, function(u)
        if u == unit then return newInit end
        return u.initiative
    end)
end

-- Like the live turn order, but with an extra GHOST copy of `unit` inserted where it would
-- land if it acted (newTime). The actor keeps its real slot AND gains a preview slot, so the
-- UI can show "you are here now / you would move to here". Returns a list of
-- { unit, preview } entries in turn order (soonest first); the real entry sorts before the
-- ghost on a tie so the live one stays lower in a bottom-anchored strip.
function Combat.previewTimeline(combat, unit, newInit)
    local entries = {}
    for _, u in ipairs(combat.units) do
        if u.alive then entries[#entries + 1] = { unit = u, preview = false, initiative = u.initiative } end
    end
    entries[#entries + 1] = { unit = unit, preview = true, initiative = newInit }
    -- Order by initiative, matching Combat.turnOrder's tie-breaks so the strip agrees with the
    -- board's turn numbers; a preview ghost sorts AFTER real entries at an exact tie. Every
    -- branch is guarded so comparing an entry with itself returns false (a valid weak order --
    -- an unguarded `return not a.preview` here would assert x < x and corrupt table.sort).
    table.sort(entries, function(a, b)
        if a.initiative ~= b.initiative then return a.initiative < b.initiative end
        if a.preview ~= b.preview then return b.preview end -- real before ghost at a tie
        if a.unit.speed ~= b.unit.speed then return a.unit.speed > b.unit.speed end
        if a.unit.side ~= b.unit.side then return SIDE_RANK[a.unit.side] < SIDE_RANK[b.unit.side] end
        return a.unit.index < b.unit.index
    end)
    return entries
end

function Combat.currentUnit(combat)
    return Combat.turnOrder(combat)[1]
end

-- Open the current unit's turn: a fresh { unit, moved, moveCost } record the move/action
-- calls read and end. Returns the unit whose turn it is (nil if none are left alive).
function Combat.startTurn(combat)
    local unit = Combat.currentUnit(combat)
    combat.turn = unit and { unit = unit, moved = false, moveCost = 0 } or nil
    if unit then Status.onTurnStart(combat, unit) end
    return unit
end

-- Has the active unit already spent its (once-per-turn) move?
function Combat.hasMoved(combat)
    return combat.turn ~= nil and combat.turn.moved
end

-- The next living unit to act (the one a wait would delay past), or nil if `unit` is the last
-- one standing. `unit` sits at initiative 0 during its turn, so this is the second in order.
local function nextUnit(combat, unit)
    for _, u in ipairs(Combat.turnOrder(combat)) do
        if u ~= unit then return u end
    end
    return nil
end

-- End the active unit's turn: set its initiative to (moveCost spent this turn) + the action
-- cost, then rebase so the next unit drops to 0. Shared by useItem and passing.
local function endTurn(combat, unit, actionCost)
    local moveCost = (combat.turn and combat.turn.unit == unit and combat.turn.moveCost) or 0
    -- A status may charge a move cost even if the unit stayed put (root: as if it moved max).
    moveCost = math.max(moveCost, Status.forcedMoveCost(combat, unit))
    Status.onTurnEnd(combat, unit)
    unit.initiative = unit.initiative + moveCost + actionCost
    combat.turnCount = combat.turnCount + 1
    combat.turn = nil
    Combat.rebase(combat)
end

-- Wait (delay): the acting unit sits at initiative 0, so end the turn by setting its
-- initiative to (next unit's initiative + 1) -- act one tick after them -- but never below the
-- move cost it spent this turn, so a move is still paid. Rebasing then drops the next unit to
-- 0 and the waiter lands just behind it. Falls back to moveCost + WAIT_COST when no other unit
-- is alive. The player's deliberate "delay my turn" action.
function Combat.wait(combat, unit)
    if not unit.alive then return false, "dead" end
    local moveCost = (combat.turn and combat.turn.unit == unit and combat.turn.moveCost) or 0
    moveCost = math.max(moveCost, Status.forcedMoveCost(combat, unit))
    Status.onTurnEnd(combat, unit)
    local nxt = nextUnit(combat, unit)
    unit.initiative = nxt and math.max(moveCost, nxt.initiative + 1) or (moveCost + Combat.WAIT_COST)
    combat.turnCount = combat.turnCount + 1
    combat.turn = nil
    Combat.logEvent(combat, "wait", string.format("%s waits.", unitName(unit)))
    Combat.rebase(combat)
    return true
end

-- How this unit's "Wait" behaves, resolved from the first inventory item that declares a
-- `waitBehavior` table { kind = "focus"|"defend", ... }. Defaults to a plain delay. A unit is
-- expected to carry at most one such item; if it somehow carries several, first-in-inventory
-- wins. Drives both the battle UI's action-button label and which of wait/focus/defend runs.
function Combat.waitBehavior(unit)
    for _, item in ipairs(Character.eachItem(unit.char)) do
        if item.waitBehavior then return item.waitBehavior end
    end
    return { kind = "delay" }
end

-- Focus: end the turn without attacking, restoring mana instead. Costs more of the timeline than
-- a plain wait (behavior.speed, or Combat.FOCUS_SPEED). The mana-recovery half of the wait swap
-- granted by a focus item (data/items/utility/focus_stone.lua).
function Combat.focus(combat, unit)
    if not unit.alive then return false, "dead" end
    local behavior = Combat.waitBehavior(unit)
    local restored = Combat.restoreResource(unit.char, "mana", behavior.mana or 0)
    Combat.logEvent(combat, "focus",
        string.format("%s focuses (+%d mana).", unitName(unit), restored))
    endTurn(combat, unit, behavior.speed or Combat.FOCUS_SPEED)
    return true
end

-- Defend: end the turn without attacking, gaining the Defending status (a temporary +defense that
-- lasts until this unit's next turn). Costs behavior.speed of the timeline (or Combat.DEFEND_SPEED).
-- The wait swap granted by a shield item (data/items/armor/buckler.lua).
function Combat.defend(combat, unit)
    if not unit.alive then return false, "dead" end
    local behavior = Combat.waitBehavior(unit)
    Status.apply(combat, unit, "defending")
    Combat.logEvent(combat, "defend", string.format("%s takes a defensive stance.", unitName(unit)))
    endTurn(combat, unit, behavior.speed or Combat.DEFEND_SPEED)
    return true
end

-- Pass: end the turn without acting, paying the normal timeline cost (this turn's move cost,
-- or WAIT_COST if the unit also stayed put so it can never stall). Unlike wait it does NOT
-- delay past the next unit -- used by enemy AI and the auto-pass so terrain still slows them.
function Combat.pass(combat, unit)
    if not unit.alive then return false, "dead" end
    local moved = combat.turn ~= nil and combat.turn.unit == unit and combat.turn.moved
    -- A move-only reposition already logged the move; only log the idle case so a unit with
    -- nothing to do still leaves a trace (and the enemy AI's "no useful action" reads on the log).
    if not moved then
        Combat.logEvent(combat, "wait", string.format("%s holds position.", unitName(unit)))
    end
    endTurn(combat, unit, moved and 0 or Combat.WAIT_COST)
    return true
end

-- ---------------------------------------------------------------------------
-- Movement
-- ---------------------------------------------------------------------------

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- Tiles a unit can reach this turn: a Dijkstra over the arena weighted by tile
-- `moveCost`, budget = the unit's `movement`, blocked by non-walkable tiles and cells
-- occupied by other units. Returns `{ [key]= { x, y, cost, steps } }`, keyed by "x,y".
-- `cost` is the terrain-weighted path cost: it spends the movement budget AND is the
-- initiative the move costs at end-of-turn (so rough terrain is slower to cross in both
-- reach and time). `steps` is the raw tile count, used only by the enemy AI's pathing.
function Combat.reachable(combat, unit)
    local arena = combat.arena
    local budget = flatStat(unit, "movement")

    local best = {}
    local origin = { x = unit.x, y = unit.y, cost = 0, steps = 0 }
    best[key(unit.x, unit.y)] = origin
    local frontier = { origin }

    while #frontier > 0 do
        -- Pop the lowest-cost frontier node.
        local bi = 1
        for i = 2, #frontier do
            if frontier[i].cost < frontier[bi].cost then bi = i end
        end
        local cur = table.remove(frontier, bi)

        -- Skip stale entries (a cheaper path to this cell was found later).
        if best[key(cur.x, cur.y)] == cur then
            for _, d in ipairs(DIRS) do
                local nx, ny = cur.x + d[1], cur.y + d[2]
                if nx >= 1 and nx <= arena.cols and ny >= 1 and ny <= arena.rows then
                    local cell = arena.tiles[ny][nx]
                    if cell.walkable and not Combat.unitAt(combat, nx, ny) then
                        local ncost = cur.cost + cell.moveCost
                        if ncost <= budget then
                            local nk = key(nx, ny)
                            local existing = best[nk]
                            if not existing or ncost < existing.cost then
                                local node = { x = nx, y = ny, cost = ncost, steps = cur.steps + 1,
                                               fromKey = key(cur.x, cur.y) }
                                best[nk] = node
                                frontier[#frontier + 1] = node
                            end
                        end
                    end
                end
            end
        end
    end

    best[key(unit.x, unit.y)] = nil -- the origin isn't a "move" target
    return best
end

-- Every cell a unit could strike THIS turn with a `range`-reach weapon: for the origin tile
-- and each tile it can move to, the Manhattan diamond of radius `range`, clamped to the arena.
-- Returns `{ [key] = { x, y, fromX, fromY, moveCost } }`, where from/moveCost is the CHEAPEST
-- move tile to stand on to hit that cell (the origin, at moveCost 0, when already in reach).
-- One structure serves both the red default-attack (threat) highlight -- its keys, minus the
-- move set, are the "beyond movement" band -- and click-to-attack (move to `from`, then strike).
-- `range` is the weapon's BASE range; each stand tile's `range` field bonus (high ground, a
-- vantage object) extends the reach from that tile, matching what Combat.useItem allows once the
-- unit stands there. `reachable` defaults to Combat.reachable(combat, unit); the battle state
-- passes its live set so a unit that has already moved only threatens from where it now stands.
-- `requiresSight` (the default weapon's `ab.requiresSight`) drops any target cell a stand tile has
-- no clear line to, so a bow's red reach stops at terrain cover.
function Combat.attackReach(combat, unit, range, reachable, requiresSight, minRange)
    range = range or 1
    minRange = minRange or 0
    reachable = reachable or Combat.reachable(combat, unit)

    -- Stand tiles: the origin (cost 0) plus every reachable move tile.
    local stands = { { x = unit.x, y = unit.y, cost = 0 } }
    for _, node in pairs(reachable) do
        stands[#stands + 1] = { x = node.x, y = node.y, cost = node.cost }
    end

    local out = {}
    for _, s in ipairs(stands) do
        local r = range + (Combat.fieldBonus(combat, s.x, s.y).range or 0)
        for dx = -r, r do
            for dy = -r, r do
                local d = math.abs(dx) + math.abs(dy)
                if d <= r and d >= minRange then
                    local x, y = s.x + dx, s.y + dy
                    -- Impassable tiles (solid obstacles, which also fully block sight) can never
                    -- hold a target, so they're never part of the reach -- no red highlight, and
                    -- click-to-attack can't fire into a wall.
                    if x >= 1 and x <= combat.arena.cols and y >= 1 and y <= combat.arena.rows
                        and combat.arena.tiles[y][x].walkable
                        and (not requiresSight or Combat.hasLineOfSight(combat, s.x, s.y, x, y)) then
                        local k = key(x, y)
                        local e = out[k]
                        if not e or s.cost < e.moveCost then
                            out[k] = { x = x, y = y, fromX = s.x, fromY = s.y, moveCost = s.cost }
                        end
                    end
                end
            end
        end
    end
    return out
end

-- Move a unit to (x, y) if reachable this turn. A unit may move once per turn and moving
-- does NOT end the turn: it just repositions and records the terrain-weighted path cost
-- (node.cost), which endTurn later folds into the timeline (move cost + action cost).
function Combat.moveUnit(combat, unit, x, y)
    if not unit.alive then return false, "dead" end
    if not combat.turn or combat.turn.unit ~= unit then return false, "not this unit's turn" end
    if combat.turn.moved then return false, "already moved" end
    if Status.blocksMove(unit) then return false, "rooted" end
    local reachable = Combat.reachable(combat, unit)
    local node = reachable[key(x, y)]
    if not node then return false, "unreachable" end

    -- Reconstruct the path (destination back to the first step; origin was cleared from the
    -- reachable set) so a trap on ANY tile entered triggers -- not just the landing tile.
    local path = {}
    local n = node
    while n do
        path[#path + 1] = n
        n = n.fromKey and reachable[n.fromKey] or nil
    end

    unit.x, unit.y = x, y
    combat.turn.moved = true
    combat.turn.moveCost = node.cost
    Combat.logEvent(combat, "move", string.format("%s moves to (%d, %d).", unitName(unit), x, y))

    -- Walk the path origin-first, triggering each opposing trap in traversal order. A trap that
    -- kills (or roots-then-kills via a later trap) the mover stops further triggers. Any hazard on a
    -- NEWLY entered tile (path[i] with i < #path -- the origin is #path, which the unit is leaving,
    -- not entering) fires its on-entry effect too; a hazard affects either side.
    for i = #path, 1, -1 do
        if not unit.alive then break end
        local trap = Trap.at(combat, path[i].x, path[i].y)
        if trap then Trap.trigger(combat, trap, unit) end
        if unit.alive and i < #path then Hazard.onEnter(combat, unit, path[i].x, path[i].y) end
    end

    return true, node.cost
end

-- ---------------------------------------------------------------------------
-- Item actions + damage/heal helpers
-- ---------------------------------------------------------------------------

-- Every tag that applies to an attack from `item`: the item's own tags, any ability-level
-- tags, and per-cast tags passed by the effect (opts.tags).
local function collectTags(item, opts)
    local tags = {}
    for _, t in ipairs(item.tags or {}) do tags[#tags + 1] = t end
    local ab = item.activeAbility
    if ab and ab.tags then
        for _, t in ipairs(ab.tags) do tags[#tags + 1] = t end
    end
    if opts and opts.tags then
        for _, t in ipairs(opts.tags) do tags[#tags + 1] = t end
    end
    return tags
end

-- ---------------------------------------------------------------------------
-- Inventory adjacency (3x3 grid). Items can grant to (aura), require, or scale off the items
-- sitting adjacent to them in the grid -- diagonals included. The grid math lives in
-- models/character.lua; these read the current arrangement of a character's inventory.
-- ---------------------------------------------------------------------------

-- Does `item` match an adjacency predicate `{ type=?, tag=? }`? Each field is optional (an absent
-- field is a wildcard); a predicate with neither field matches any item.
function Combat.matchesAdjacency(item, pred)
    if not (item and pred) then return false end
    if pred.type and item.type ~= pred.type then return false end
    if pred.tag and not hasTag(item.tags, pred.tag) then return false end
    return true
end

-- Does an aura block `a` (declared on a neighbor item) apply to the cast `item`? The item's type
-- must be listed in `a.appliesTo`, and it must carry none of `a.exceptTags`.
function Combat.auraApplies(a, item)
    if not (a and item) then return false end
    local ok = false
    for _, t in ipairs(a.appliesTo or {}) do
        if t == item.type then ok = true break end
    end
    if not ok then return false end
    for _, t in ipairs(a.exceptTags or {}) do
        if hasTag(item.tags, t) then return false end
    end
    return true
end

-- Aggregate the adjacency auras affecting a cast of `item` from `char`'s grid: the extra tags to
-- fold into the attack, and the statuses to inflict on a damaged target. Returns (tags, statuses).
local function adjacencyAura(char, item)
    local tags, statuses = {}, {}
    local idx = char and Character.slotIndex(char, item)
    if idx then
        for _, nb in ipairs(Character.adjacentItems(char, idx)) do
            if nb.aura and Combat.auraApplies(nb.aura, item) then
                for _, t in ipairs(nb.aura.grantTags or {}) do tags[#tags + 1] = t end
                if nb.aura.status then statuses[#statuses + 1] = nb.aura.status end
            end
        end
    end
    return tags, statuses
end

-- Return `opts` with `auraTags` appended to its tag list, without mutating the caller's table
-- (a fresh copy only when there is something to add). Used to fold aura-granted tags into every
-- damage call an aura-augmented cast makes.
local function withAuraTags(opts, auraTags)
    if not auraTags or #auraTags == 0 then return opts end
    local merged = {}
    if opts then for k, v in pairs(opts) do merged[k] = v end end
    local tags = {}
    for _, t in ipairs(merged.tags or {}) do tags[#tags + 1] = t end
    for _, t in ipairs(auraTags) do tags[#tags + 1] = t end
    merged.tags = tags
    return merged
end

-- Is `item`'s adjacency requirement satisfied in `char`'s grid? True when the ability declares no
-- `requiresAdjacent`, or when at least one adjacent item matches it.
function Combat.adjacencyMet(char, item)
    local ab = item and item.activeAbility
    local req = ab and ab.requiresAdjacent
    if not req then return true end
    local idx = char and Character.slotIndex(char, item)
    if not idx then return false end
    for _, nb in ipairs(Character.adjacentItems(char, idx)) do
        if Combat.matchesAdjacency(nb, req) then return true end
    end
    return false
end

-- The active adjacency relationships in `char`'s grid, for UI connector lines. Returns a list of
-- { from, to, kind } where from/to are 1-based cell indices and `kind` is one of:
--   "aura"        -- the item at `from` has an aura that applies to the item at `to`,
--   "boost"       -- the ability at `from` scales off the matching item at `to`,
--   "requirement" -- the ability at `from`'s requiresAdjacent is met by the item at `to`.
function Combat.adjacencyLinks(char)
    local links = {}
    for i = 1, Character.MAX_INVENTORY do
        local item = char.inventory[i]
        if item then
            local ab = item.activeAbility
            for _, j in ipairs(Character.adjacentIndices(i)) do
                local nb = char.inventory[j]
                if nb then
                    if item.aura and Combat.auraApplies(item.aura, nb) then
                        links[#links + 1] = { from = i, to = j, kind = "aura" }
                    end
                    if ab and ab.adjacencyScaling and Combat.matchesAdjacency(nb, ab.adjacencyScaling) then
                        links[#links + 1] = { from = i, to = j, kind = "boost" }
                    end
                    if ab and ab.requiresAdjacent and Combat.matchesAdjacency(nb, ab.requiresAdjacent) then
                        links[#links + 1] = { from = i, to = j, kind = "requirement" }
                    end
                end
            end
        end
    end
    return links
end

-- Apply tag-driven damage from `user` to `target`. The `magical` tag routes scaling to
-- magicDamage/magicDefense (else damage/defense); armor `resist` for each matching tag is
-- subtracted. Damage floors at 1. Drops the target to `alive = false` at 0 HP. Returns
-- the amount dealt. Reached through `fx.damage` inside an ability effect.
-- Apply `base` pre-mitigation damage to `target`: subtract the matching defense stat (magical
-- tags route to magicDefense) and any tag `resist`, floor at 1, and drop the target to dead at
-- 0 HP. Returns the amount dealt. The shared core for stat-scaled item damage
-- (Combat.dealDamage) AND flat sources with no attacker (traps, status effects).
-- `source` is an optional display label for the log (e.g. a trap or status name); when nil the
-- damage line stands alone (an item attack, where the preceding "attacks with" line already
-- names the attacker). A lethal hit appends a "defeated" line so the log reads the kill.
-- Pure post-mitigation damage that `base` pre-mitigation damage would deal to `target`: subtract
-- the matching defense stat (magical tags route to magicDefense) and any tag `resist`, floored at
-- 1. No mutation or logging -- shared by Combat.dealFlatDamage (which then applies it) and the
-- damage-preview tooltip (Combat.computeDamage / Combat.previewAbility).
function Combat.mitigatedDamage(target, base, tags)
    tags = tags or {}
    local magical = hasTag(tags, "magical")
    local defStat = magical and "magicDefense" or "defense"
    local defense = flatStat(target, defStat)
    local resist = 0
    for _, t in ipairs(tags) do
        resist = resist + ((target.resist and target.resist[t]) or 0)
    end
    -- Status-driven vulnerabilities ADD damage for matching tags (e.g. Wet -> +lightning). Folded in
    -- here, the shared damage core, so both real hits and the damage preview see the amplification.
    local vuln = Status.vulnerability(target, tags)
    return math.max(1, math.floor(base - defense - resist + vuln + 0.5))
end

function Combat.dealFlatDamage(combat, target, base, tags, source)
    local dmg = Combat.mitigatedDamage(target, base, tags)
    local hp = target.char.stats.health
    hp.current = hp.current - dmg
    if source then
        Combat.logEvent(combat, "damage",
            string.format("%s takes %d damage from %s.", unitName(target), dmg, source))
    else
        Combat.logEvent(combat, "damage", string.format("%s takes %d damage.", unitName(target), dmg))
    end
    if hp.current <= 0 then
        hp.current = 0
        target.alive = false
        Combat.logEvent(combat, "death", string.format("%s is defeated!", unitName(target)))
    end
    return dmg
end

function Combat.dealDamage(combat, user, target, item, opts)
    opts = opts or {}
    local tags = collectTags(item, opts)
    local magical = hasTag(tags, "magical")
    local atkStat = magical and "magicDamage" or "damage"
    local ab = item and item.activeAbility
    -- Additive: the ability's Power plus the attacker's attack stat (opts.power overrides the
    -- declared Power for a one-off hit). Mitigation then subtracts the target's defense + resists.
    local power = opts.power or (ab and ab.power) or 0
    local base = power + flatStat(user, atkStat)
    return Combat.dealFlatDamage(combat, target, base, tags)
end

-- Pure: the post-mitigation damage `user` striking `target` with `item` (and `opts`, e.g.
-- { power = 0.5 }) WOULD deal, computed exactly like Combat.dealDamage but without touching HP or
-- the log. Drives the target-hover damage preview so its number always matches the real hit.
function Combat.computeDamage(combat, user, target, item, opts)
    opts = opts or {}
    local tags = collectTags(item, opts)
    local magical = hasTag(tags, "magical")
    local atkStat = magical and "magicDamage" or "damage"
    local ab = item and item.activeAbility
    local power = opts.power or (ab and ab.power) or 0
    local base = power + flatStat(user, atkStat)
    return Combat.mitigatedDamage(target, base, tags)
end

-- Pure: the damage `unit` striking a trap with `weapon` would deal -- the weapon's attack stat
-- (magical weapons route through magicDamage), floored at 1. Traps carry no defense, so this is
-- the raw stat. Mirrors the math inside Combat.strikeTrap so the strike-trap hover preview matches.
function Combat.computeTrapDamage(unit, weapon)
    local tags = collectTags(weapon, {})
    local atkStat = hasTag(tags, "magical") and "magicDamage" or "damage"
    local ab = weapon and weapon.activeAbility
    local power = (ab and ab.power) or 0
    return math.max(1, math.floor(power + flatStat(unit, atkStat) + 0.5))
end

-- Restore health to `target`, capped at its max. Returns the amount actually healed.
-- Reached through `fx.heal` inside an ability effect.
function Combat.applyHeal(combat, target, amount)
    local hp = target.char.stats.health
    local before = hp.current
    hp.current = math.min(hp.max, hp.current + (amount or 0))
    local healed = hp.current - before
    if healed > 0 then
        Combat.logEvent(combat, "heal", string.format("%s is healed for %d.", unitName(target), healed))
    end
    return healed
end

-- Dry-run `item`'s ability aimed at cell (tx, ty) WITHOUT mutating combat: replay the very same
-- effect(fx) a real cast would run, but with helpers that only COMPUTE their outcome -- damage
-- after mitigation, the clamped heal, the status a hit would apply -- and record it per affected
-- unit. Because it replays the real effect it handles AoE / multi-hit / self-effects correctly.
-- Returns { entries = { [unit] = { unit, damage, heal, lethal, statuses = { { id, def, opts } } } },
-- order = {entries...} } (order is affected-unit order), or nil for an ability with no effect.
-- The effect is pcall-guarded so a data-file quirk in a dry run can never crash the tooltip.
function Combat.previewAbility(combat, unit, item, tx, ty)
    local ab = item and item.activeAbility
    if not ab then return nil end
    local target = Combat.unitAt(combat, tx, ty)
    local entries, order = {}, {}
    local function entryFor(tgt)
        local e = entries[tgt]
        if not e then
            e = { unit = tgt, damage = 0, heal = 0, statuses = {} }
            entries[tgt] = e
            order[#order + 1] = e
        end
        return e
    end
    local auraTags, auraStatuses = adjacencyAura(unit.char, item)
    local fx = {
        user = unit, target = target, item = item, combat = combat, tx = tx, ty = ty,
        power = ab.power, -- the ability's balance scalar; effects derive heal/status magnitude from it
        unitAt = function(x, y) return Combat.unitAt(combat, x, y) end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
        aoeUnits = function() return Combat.aoeUnits(combat, ab, tx, ty) end,
        aoeCells = function() return Combat.aoeCells(combat, ab, tx, ty) end,
        adjacentItems = function()
            local idx = Character.slotIndex(unit.char, item)
            return idx and Character.adjacentItems(unit.char, idx) or {}
        end,
        adjacentMatching = function(pred)
            local idx = Character.slotIndex(unit.char, item)
            local n = 0
            if idx then
                for _, it in ipairs(Character.adjacentItems(unit.char, idx)) do
                    if Combat.matchesAdjacency(it, pred) then n = n + 1 end
                end
            end
            return n
        end,
        damage = function(tgt, opts)
            if not tgt then return 0 end
            local d = Combat.computeDamage(combat, unit, tgt, item, withAuraTags(opts, auraTags))
            local e = entryFor(tgt)
            e.damage = e.damage + d
            if d > 0 then
                for _, st in ipairs(auraStatuses) do
                    e.statuses[#e.statuses + 1] = { id = st.id, def = Status.defs[st.id], opts = st.opts }
                end
            end
            return d
        end,
        heal = function(tgt, amount)
            if not tgt then return 0 end
            local hp = tgt.char.stats.health
            local healed = math.min(hp.max, hp.current + (amount or 0)) - hp.current
            entryFor(tgt).heal = entryFor(tgt).heal + healed
            return healed
        end,
        applyStatus = function(tgt, id, opts)
            if not tgt then return nil end
            local e = entryFor(tgt)
            e.statuses[#e.statuses + 1] = { id = id, def = Status.defs[id], opts = opts }
            return nil
        end,
        -- A dry run must not mutate resources; report the clamped gain without applying it.
        restore = function(tgt, stat, amount)
            if not tgt or not amount or amount <= 0 then return 0 end
            local res = tgt.char.stats[stat]
            if type(res) == "table" then return math.min(res.max, res.current + amount) - res.current end
            return amount
        end,
        -- Placing a trap/hazard mutates combat, so a dry run must not; report nothing.
        placeTrap = function() return nil end,
        placeHazard = function() return nil end,
    }
    if ab.effect then pcall(ab.effect, fx) end
    -- A damage total >= the target's current HP would drop it: flag the lethal blow.
    for _, e in ipairs(order) do
        local hp = e.unit.char and e.unit.char.stats and e.unit.char.stats.health
        e.lethal = e.damage > 0 and hp ~= nil and e.damage >= (hp.current or 0)
    end
    return { entries = entries, order = order }
end

-- A zero-defense, full-HP stand-in target. Feeding it to the effect's damage/heal helpers yields
-- the RAW (pre-armor) output an ability deals -- no real target needed -- and its huge health means
-- a dry-run heal reports the full amount and nothing reads as lethal. Used by Combat.abilityOutput.
local function dummyTarget()
    return {
        char = { name = "target", stats = {
            health = { max = 1e9, current = 1e9 },
            defense = 0, magicDefense = 0,
        } },
        bonus = {}, resist = {}, alive = true, side = "enemy",
    }
end

-- Pure: the raw output `unit` would get from `item`'s ability, with NO board target -- for the
-- inventory-hover tooltip, which has an actor but nothing aimed. Replays the real effect against a
-- zero-defense stand-in (so `damage` is the pre-armor Power + attack stat) and captures the
-- `fx.power`-derived heal and status too, so it stays correct for AoE / multi-hit / heal / buff
-- abilities alike. Returns { damage, heal, statuses = { { id, def, opts } }, multi } (multi flags an
-- AoE ability, whose number is per target) or nil for an item with no active-ability effect. The
-- effect is pcall-guarded so a data-file quirk can never crash the tooltip.
function Combat.abilityOutput(unit, item)
    local ab = item and item.activeAbility
    if not ab or not ab.effect then return nil end
    local dummy = dummyTarget()
    local out = { damage = 0, heal = 0, statuses = {}, multi = ab.aoe ~= nil }
    local fx = {
        user = unit, target = dummy, item = item, combat = nil, tx = 0, ty = 0,
        power = ab.power,
        unitAt = function() return nil end,
        unitsNear = function() return { dummy } end,
        aoeUnits = function() return { dummy } end,
        aoeCells = function() return {} end,
        damage = function(tgt, opts)
            local d = Combat.computeDamage(nil, unit, tgt or dummy, item, opts)
            out.damage = out.damage + d
            return d
        end,
        heal = function(_, amount)
            out.heal = out.heal + (amount or 0)
            return amount or 0
        end,
        applyStatus = function(_, id, opts)
            out.statuses[#out.statuses + 1] = { id = id, def = Status.defs[id], opts = opts }
            return nil
        end,
        restore = function(_, _, amount) return amount or 0 end,
        placeTrap = function() return nil end,
        placeHazard = function() return nil end,
    }
    pcall(ab.effect, fx)
    return out
end

-- Living units a unit may target with `item`'s ability, by range + target kind.
function Combat.abilityTargets(combat, unit, item)
    local ab = item.activeAbility
    if not ab then return {} end
    local out = {}
    local range = Combat.abilityRange(combat, unit, ab)
    local minRange = Combat.abilityMinRange(ab)
    for _, other in ipairs(combat.units) do
        local d = manhattan(unit.x, unit.y, other.x, other.y)
        if other.alive and d <= range and d >= minRange then
            local valid = false
            if ab.target == "enemy" then valid = other.side ~= unit.side
            elseif ab.target == "ally" then valid = other.side == unit.side -- includes self
            elseif ab.target == "self" then valid = other == unit end
            -- A sight-gated ability can't reach a target it has no clear line to (terrain cover).
            if valid and ab.requiresSight
                and not Combat.hasLineOfSight(combat, unit.x, unit.y, other.x, other.y) then
                valid = false
            end
            if valid then out[#out + 1] = other end
        end
    end
    return out
end

-- Does this ability read as friendly (green preview) rather than hostile (red)? Ally/self targets
-- are supportive; enemy strikes and tile-targeted trap placements are hostile. A tile/area cast that
-- lays down a friendly effect (a Sanctuary hazard) opts in explicitly with `support = true`.
function Combat.isSupportAbility(ab)
    return ab ~= nil and (ab.target == "ally" or ab.target == "self" or ab.support == true)
end

local function resourceValue(char, stat)
    local res = char.stats[stat]
    if type(res) == "table" then return res.current end
    return res or 0
end

local function spendResource(char, stat, amount)
    local res = char.stats[stat]
    if type(res) == "table" then res.current = res.current - amount
    else char.stats[stat] = (res or 0) - amount end
end

-- Current value of a resource stat on `char` (a {max,current} table reads `current`; a plain
-- number reads itself; missing reads 0). Public so the UI can show "have N" without duplicating
-- the {max,current}-vs-number handling.
function Combat.resource(char, stat)
    return resourceValue(char, stat)
end

-- Restore a resource stat toward its max -- the inverse of spendResource. A {max,current} table
-- clamps at max; a plain-number stat just adds. Returns the amount actually restored (0 if it was
-- already full or `amount` is non-positive). Shared by stamina regen, Focus, and on-hit mana gain.
function Combat.restoreResource(char, stat, amount)
    if not amount or amount <= 0 then return 0 end
    local res = char.stats[stat]
    if type(res) == "table" then
        local before = res.current
        res.current = math.min(res.max, res.current + amount)
        return res.current - before
    end
    char.stats[stat] = (res or 0) + amount
    return amount
end

-- Can `char` currently pay ability `ab`'s resource cost? True when the ability has no cost. The
-- affordability gate the UI grays a slot on, mirroring the check inside Combat.useItem.
function Combat.canAfford(char, ab)
    if not ab or not ab.cost then return true end
    return resourceValue(char, ab.cost.stat) >= ab.cost.amount
end

-- Is this a consuming item whose stack is spent (quantity 0)? A depleted consumable KEEPS its
-- inventory slot but can't be activated until it's restocked (Character.addItem merges a new
-- stack back into the empty slot). The shared gate for the grayed-out "out of stock" slot,
-- mirrored inside Combat.useItem so a keyboard/gamepad use can't fire on an empty stack either.
function Combat.isDepleted(item)
    local ab = item and item.activeAbility
    return ab ~= nil and ab.consumesItem and (item.quantity or 1) <= 0
end

-- Perform an item action: validate range + target kind + resource cost, spend the cost,
-- run the ability's effect(fx), push the actor back by the ability speed, and consume the
-- item if it's a consumable. Returns (true, result) or (false, reason). `result` is
-- { damageDealt, healed } aggregated across the effect's helper calls.
function Combat.useItem(combat, unit, item, tx, ty)
    if not unit.alive then return false, "dead" end
    local ab = item.activeAbility
    if not ab then return false, "no ability" end
    if Combat.isDepleted(item) then return false, "out of stock" end
    if not Combat.adjacencyMet(unit.char, item) then
        local req = ab.requiresAdjacent
        return false, "requires adjacent " .. (req.tag or req.type or "item")
    end

    local dist = manhattan(unit.x, unit.y, tx, ty)
    if dist > Combat.abilityRange(combat, unit, ab) then
        return false, "out of range"
    end
    if dist < Combat.abilityMinRange(ab) then
        return false, "too close"
    end
    if ab.requiresSight and not Combat.hasLineOfSight(combat, unit.x, unit.y, tx, ty) then
        return false, "no line of sight"
    end
    -- Tile-target casts (e.g. summoning a trap) land ON the chosen cell, so it must be an empty,
    -- occupiable tile -- never a solid obstacle, never a tile a unit already stands on. Reject
    -- before any cost is spent.
    if ab.target == "tile" then
        local row = combat.arena and combat.arena.tiles and combat.arena.tiles[ty]
        local cell = row and row[tx]
        if not (cell and cell.walkable) then return false, "blocked tile" end
        -- An area cast (e.g. summoning a hazard you may stand in) can target an occupied tile; a
        -- point placement (a trap) still refuses a tile a unit stands on.
        if not ab.allowOccupied and Combat.unitAt(combat, tx, ty) then return false, "occupied tile" end
    end

    local target = Combat.unitAt(combat, tx, ty)
    if target then
        if ab.target == "enemy" and target.side == unit.side then return false, "invalid target" end
        if ab.target == "ally" and target.side ~= unit.side then return false, "invalid target" end
        if ab.target == "self" and target ~= unit then return false, "invalid target" end
    end

    if ab.cost and resourceValue(unit.char, ab.cost.stat) < ab.cost.amount then
        return false, "insufficient " .. ab.cost.stat
    end
    if ab.cost then spendResource(unit.char, ab.cost.stat, ab.cost.amount) end

    -- Effect context: bound helpers let a data-file effect compose damage/heal/AoE
    -- without touching this module. Results are accumulated for the caller/UI.
    -- Adjacency auras from neighboring items (e.g. a Fire Stone next to this weapon) fold extra
    -- tags into every hit and inflict their status on any target this cast damages.
    local auraTags, auraStatuses = adjacencyAura(unit.char, item)
    local result = { damageDealt = 0, healed = 0 }
    local fx = {
        user = unit, target = target, item = item, combat = combat,
        tx = tx, ty = ty, -- the targeted cell, for tile-targeted abilities (e.g. placing a trap)
        power = ab.power, -- the ability's balance scalar; effects derive heal/status magnitude from it
        unitAt = function(x, y) return Combat.unitAt(combat, x, y) end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
        aoeUnits = function() return Combat.aoeUnits(combat, ab, tx, ty) end,
        -- The cells this ability's AoE footprint covers (reads `ab.aoe`); an effect iterates them to
        -- paint the ground -- e.g. Fireball dropping a fire hazard on every blasted tile.
        aoeCells = function() return Combat.aoeCells(combat, ab, tx, ty) end,
        -- Items adjacent to this one in the caster's 3x3 grid (diagonals included).
        adjacentItems = function()
            local idx = Character.slotIndex(unit.char, item)
            return idx and Character.adjacentItems(unit.char, idx) or {}
        end,
        -- Count of adjacent items matching a `{ type=?, tag=? }` predicate (e.g. Omnislash scaling
        -- off adjacent weapons).
        adjacentMatching = function(pred)
            local idx = Character.slotIndex(unit.char, item)
            local n = 0
            if idx then
                for _, it in ipairs(Character.adjacentItems(unit.char, idx)) do
                    if Combat.matchesAdjacency(it, pred) then n = n + 1 end
                end
            end
            return n
        end,
        damage = function(tgt, opts)
            if not tgt then return 0 end
            local d = Combat.dealDamage(combat, unit, tgt, item, withAuraTags(opts, auraTags))
            result.damageDealt = result.damageDealt + d
            if d > 0 then
                for _, st in ipairs(auraStatuses) do
                    Status.apply(combat, tgt, st.id, st.opts)
                end
            end
            return d
        end,
        heal = function(tgt, amount)
            if not tgt then return 0 end
            local h = Combat.applyHeal(combat, tgt, amount)
            result.healed = result.healed + h
            return h
        end,
        -- Restore a resource (e.g. the parasitic staff refunding mana to fx.user on hit).
        restore = function(tgt, stat, amount)
            if not tgt then return 0 end
            return Combat.restoreResource(tgt.char, stat, amount)
        end,
        -- Apply a status effect (models/status.lua) to a unit.
        applyStatus = function(tgt, id, opts)
            if not tgt then return nil end
            return Status.apply(combat, tgt, id, opts)
        end,
        -- Summon a trap on a tile, owned by the acting unit's side (fx.item's placer). Only a
        -- party placement is logged with its location -- an enemy trap stays hidden until it is
        -- detected or triggers, so surfacing its tile here would leak the detect-traps mechanic.
        placeTrap = function(px, py, id, opts)
            local trap = Trap.place(combat, px, py, id, unit.side, opts)
            if trap and unit.side == "party" then
                Combat.logEvent(combat, "trap",
                    string.format("%s places %s at (%d, %d).", unitName(unit), trap.name or "a trap", px, py))
            end
            return trap
        end,
        -- Summon a hazard (fire/rain/sanctuary) on a tile, tagged with the caster's side (for the
        -- renderer's tint). Always visible; placeable on occupied ground; refreshes rather than
        -- stacks an identical hazard already there.
        placeHazard = function(px, py, id, opts)
            opts = opts or {}
            opts.side = opts.side or unit.side
            return Hazard.place(combat, px, py, id, opts)
        end,
    }

    -- Log the action itself before its effect runs, so the cast heads the sub-events it spawns
    -- (damage / heal / status / trap lines). Offensive casts read "attacks with", the rest "uses".
    local verb = (ab.target == "enemy") and "attacks with" or "uses"
    Combat.logEvent(combat, "action",
        string.format("%s %s %s.", unitName(unit), verb, item.name or "an item"))

    if ab.effect then ab.effect(fx) end

    -- Water quenches fire: a cast carrying the "water" tag douses any dousable hazard across its
    -- footprint (the AoE cells, or just the aimed cell). Runs after the effect so a water AoE that
    -- also lays down rain clears the fire it fell on. Uses the full cast tag set (item + ability).
    local castTags = collectTags(item, nil)
    if hasTag(castTags, "water") then
        local cells = ab.aoe and Combat.aoeCells(combat, ab, tx, ty) or { { x = tx, y = ty } }
        Hazard.douse(combat, cells, castTags)
    end

    -- Using an item ends the turn: advance by (this turn's move cost) + the ability speed.
    endTurn(combat, unit, ab.speed or Combat.DEFAULT_SPEED)

    -- Consume one use: decrement the stack (a bundle of consumables), floored at 0. The spent
    -- slot STAYS in the inventory as an empty stack -- Combat.isDepleted then blocks activation
    -- until it's restocked (Character.addItem merges a fresh stack back in). Non-stacked items
    -- carry quantity 1, so this leaves an empty, greyed-out slot after their single use.
    if ab.consumesItem then
        item.quantity = math.max(0, (item.quantity or 1) - 1)
    end

    return true, result
end

-- Strike a REVEALED trap at (x, y) with `weapon`: the trap analogue of attacking a unit, so a
-- unit that can see an enemy trap can destroy it. Validates range + that the trap is visible to
-- the actor's side + affordability, spends the weapon's cost, damages the trap by the weapon's
-- attack stat, and ends the turn. Returns (true, { trap }) or (false, reason).
function Combat.strikeTrap(combat, unit, weapon, x, y)
    if not unit.alive then return false, "dead" end
    local trap = Trap.at(combat, x, y)
    if not trap then return false, "no trap" end
    if not Trap.visibleTo(combat, trap, unit.side) then return false, "hidden" end
    local ab = weapon and weapon.activeAbility
    if not ab then return false, "no ability" end
    local dist = manhattan(unit.x, unit.y, x, y)
    if dist > Combat.abilityRange(combat, unit, ab) then
        return false, "out of range"
    end
    if dist < Combat.abilityMinRange(ab) then
        return false, "too close"
    end
    if ab.requiresSight and not Combat.hasLineOfSight(combat, unit.x, unit.y, x, y) then
        return false, "no line of sight"
    end
    if ab.cost and resourceValue(unit.char, ab.cost.stat) < ab.cost.amount then
        return false, "insufficient " .. ab.cost.stat
    end
    if ab.cost then spendResource(unit.char, ab.cost.stat, ab.cost.amount) end

    -- Damage the trap by the weapon's attack stat (magical weapons use magicDamage). Traps have
    -- no defense, so this is the raw stat, floored.
    Combat.logEvent(combat, "trap", string.format("%s strikes %s.", unitName(unit), trap.name or "a trap"))
    Trap.damage(combat, trap, Combat.computeTrapDamage(unit, weapon))

    endTurn(combat, unit, ab.speed or Combat.DEFAULT_SPEED)
    return true, { trap = trap }
end

-- ---------------------------------------------------------------------------
-- Enemy AI
-- ---------------------------------------------------------------------------

-- Enemy plan for a whole turn (move once, then act). Returns a descriptor the battle state
-- executes as an optional move followed by an item use or a wait:
--   { move = { x, y } | nil, item = <item>, tx, ty }   -- attack (optionally after moving)
--   { move = { x, y } }                                -- reposition only
--   { wait = true }                                    -- nothing useful to do
-- Priority: attack from the current tile > move to a tile that lets an ability hit a party
-- unit > step toward the nearest foe > wait. Pure (no love, no mutation) so it stays testable.
function Combat.planEnemyAction(combat, unit)
    -- Nearest living party unit (the foe we path toward / attack).
    local target, bestDist
    for _, u in ipairs(combat.units) do
        if u.alive and u.side ~= unit.side then
            local d = manhattan(unit.x, unit.y, u.x, u.y)
            if not bestDist or d < bestDist then target, bestDist = u, d end
        end
    end
    if not target then return { wait = true } end

    -- Only consider abilities the unit can currently pay for (else the plan would waste the
    -- turn on an item useItem rejects).
    local items = {}
    for _, item in ipairs(Combat.abilityItems(unit.char)) do
        local ab = item.activeAbility
        if (not ab.cost or resourceValue(unit.char, ab.cost.stat) >= ab.cost.amount)
            and not Combat.isDepleted(item) then
            items[#items + 1] = item
        end
    end
    -- Always-available basic attack: append the hidden unarmed weapon last (it is free, so it
    -- can't be filtered out above). A unit with an affordable weapon still prefers it -- the
    -- weapon sorts first here -- but one that can't pay for any ability can still punch.
    if unit.char.unarmed then items[#items + 1] = unit.char.unarmed end

    -- 1. Attack from where we stand, if any ability already reaches a foe (nearest target).
    for _, item in ipairs(items) do
        local hit, hitDist
        for _, t in ipairs(Combat.abilityTargets(combat, unit, item)) do
            if t.side ~= unit.side then
                local d = manhattan(unit.x, unit.y, t.x, t.y)
                if not hitDist or d < hitDist then hit, hitDist = t, d end
            end
        end
        if hit then return { item = item, tx = hit.x, ty = hit.y } end
    end

    -- 2. Move to a reachable tile from which an ability can hit a foe. Prefer the fewest steps, then
    -- (tie) the tile with the friendlier hazard footing -- so the AI won't end its turn in fire when
    -- an equally-quick safe tile hits the same foe -- then the nearest foe. Hazard.tileBias is 0 on a
    -- hazard-free tile, so this reduces to the old steps/dist ordering when nothing is burning.
    local reachable = Combat.reachable(combat, unit)
    local best
    for _, node in pairs(reachable) do
        local nodeBias = Hazard.tileBias(combat, node.x, node.y)
        for _, item in ipairs(items) do
            local ab = item.activeAbility
            local range = Combat.abilityRange(combat, unit, ab, node.x, node.y)
            local minRange = Combat.abilityMinRange(ab)
            for _, p in ipairs(combat.units) do
                if p.alive and p.side ~= unit.side
                    and manhattan(node.x, node.y, p.x, p.y) <= range
                    and manhattan(node.x, node.y, p.x, p.y) >= minRange
                    and (not (ab and ab.requiresSight)
                         or Combat.hasLineOfSight(combat, node.x, node.y, p.x, p.y)) then
                    local d = manhattan(node.x, node.y, p.x, p.y)
                    if not best or node.steps < best.steps
                        or (node.steps == best.steps and nodeBias > best.bias)
                        or (node.steps == best.steps and nodeBias == best.bias and d < best.dist) then
                        best = { x = node.x, y = node.y, item = item, tx = p.x, ty = p.y,
                                 steps = node.steps, dist = d, bias = nodeBias }
                    end
                end
            end
        end
    end
    if best then
        return { move = { x = best.x, y = best.y }, item = best.item, tx = best.tx, ty = best.ty }
    end

    -- 3. No attack possible: step to the reachable tile closest to the target, preferring (on a tie)
    -- the friendlier hazard footing -- so a wounded unit steps onto a sanctuary and away from fire --
    -- then fewer steps. Only move if it strictly closes the gap, to avoid pacing in place.
    local dest
    for _, node in pairs(reachable) do
        local d = manhattan(node.x, node.y, target.x, target.y)
        local nodeBias = Hazard.tileBias(combat, node.x, node.y)
        if not dest or d < dest.dist
            or (d == dest.dist and nodeBias > dest.bias)
            or (d == dest.dist and nodeBias == dest.bias and node.steps < dest.steps) then
            dest = { x = node.x, y = node.y, dist = d, steps = node.steps, bias = nodeBias }
        end
    end
    if dest and dest.dist < bestDist then
        return { move = { x = dest.x, y = dest.y } }
    end
    return { wait = true }
end

-- ---------------------------------------------------------------------------
-- Objective evaluation
-- ---------------------------------------------------------------------------

-- Resolve the arena objective to "win" / "loss" / nil. A total party wipe is always a
-- loss. Called after each action so the battle state can fire onWin/onLoss.
function Combat.evaluate(combat)
    if Combat.aliveCount(combat, "party") == 0 then return "loss" end

    local obj = combat.objective or { type = "killAll" }
    if obj.type == "assassinate" then
        for _, u in ipairs(combat.units) do
            if u.alive and u.side == "enemy" and u.char.id == obj.target then
                return nil -- target still standing
            end
        end
        return "win"
    elseif obj.type == "survive" then
        if combat.clock >= (obj.turns or math.huge) then return "win" end
        return nil
    else -- killAll (default)
        if Combat.aliveCount(combat, "enemy") == 0 then return "win" end
        return nil
    end
end

return Combat
