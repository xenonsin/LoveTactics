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
-- shortens reach and costs more time, then scaled by the unit's status cost multiplier
-- (Combat.moveInitiative -- Haste makes the walk cheaper in time, though not longer in reach).
-- `combat.clock` accumulates the elapsed initiative (the
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
-- Status effects (models/status.lua), traps (models/trap.lua) and traits (models/trait.lua) hook
-- into this module: statuses tick down inside rebase, gate/charge movement, and fire on turn
-- start/end; traps live in combat.traps, trigger as a unit paths over them (Combat.moveUnit), and
-- can be struck down (Combat.strikeTrap); traits are standing reactions that fire at four moments
-- below (combat start, damage survived, cast finished, death). All are required here; NONE requires
-- this module at load time (they pull combat helpers through a lazy require), so there is no cycle.

local Status = require("models.status")
local Trap = require("models.trap")
local Hazard = require("models.hazard")
local Summon = require("models.summon")
local Trait = require("models.trait")
local Wall = require("models.wall")
local Character = require("models.character")

local Combat = {}

-- Random source, indirected so the headless tests can stub it (this module is pure Lua -- see the
-- header: not even love.math -- and math.random's global state would make a spec order-dependent).
-- Called as Combat.random(n) -> 1..n. Only Combat.steal uses it today.
Combat.random = math.random

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

-- The cardinal unit step from (ax, ay) toward (bx, by) along the DOMINANT axis (an exact diagonal
-- breaks toward x). Returns 0, 0 when the two points coincide. The grid is 4-directional, so a
-- "facing" derived from a caster->target vector is too. Shared by directional AoE footprints
-- (Combat.aoeCells) and forced movement (signDominant, below, defers to it).
local function stepToward(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    if math.abs(dx) >= math.abs(dy) then
        if dx == 0 then return 0, 0 end
        return (dx > 0) and 1 or -1, 0
    end
    return 0, (dy > 0) and 1 or -1
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

-- Returns the entry it appended, so a caller can hold onto a line it may later have to correct --
-- the Decoy fakes a move here, and destroying the decoy rewrites that very entry (see killUnit).
-- An entry that has since aged out past LOG_CAP is simply an orphan table: rewriting it is a no-op.
function Combat.logEvent(combat, kind, text)
    if not text then return end
    local log = combat.log
    if not log then log = {}; combat.log = log end
    local entry = { kind = kind or "system", text = text, turn = combat.turnCount or 0 }
    log[#log + 1] = entry
    if #log > Combat.LOG_CAP then table.remove(log, 1) end
    return entry
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
        total = total + ((cell and cell.sightCost) or 0) + Wall.sightCostAt(combat, x, y)
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

-- Extra Power a strike gets when it is thrown with the wielder's bare fists: the aggregated
-- `unarmedBonus.power` from passive "fist" items carried in the grid (Iron Fist), plus
-- `unarmedBonus.drunkPower` while the unit is Drunk (Drunken Fist). 0 for any crafted weapon --
-- an identity check against the hidden unarmed instance keeps the bonus off real blades. The
-- companion range/extra-hit halves live in Combat.abilityRange and data/items/weapon/unarmed.lua.
local function unarmedPowerBonus(user, item)
    if not (user and item and item == user.char.unarmed) then return 0 end
    local ub = user.unarmedBonus
    if not ub then return 0 end
    local bonus = ub.power or 0
    if ub.drunkPower and Status.has(user, "drunk") then bonus = bonus + ub.drunkPower end
    return bonus
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
    -- A "fist" item (Shadow Fist) that lengthens the bare-handed strike: add its range only when
    -- `ab` is this unit's own hidden unarmed ability, so a crafted weapon's reach is untouched.
    if unit and unit.unarmedBonus and unit.unarmedBonus.range
        and unit.char.unarmed and ab == unit.char.unarmed.activeAbility then
        base = base + unit.unarmedBonus.range
    end
    return base + (Combat.fieldBonus(combat, x or unit.x, y or unit.y).range or 0)
end

-- Minimum range of ability `ab`: a fixed "dead zone" a target must be at least this far away to be
-- hit (a bow can't fire point-blank). Defaults to 0 (no restriction). Unlike Combat.abilityRange
-- this gets NO tile field bonus -- a vantage point extends max reach, it doesn't shrink the dead zone.
function Combat.abilityMinRange(ab)
    return (ab and ab.minRange) or 0
end

-- Cells an area-of-effect ability centred on (tx, ty) covers, clamped to the arena. An ability's
-- optional `aoe` defines the blast footprint. The centred shapes read only (tx, ty):
--   * "square" (default) -- every cell within Chebyshev distance `radius`, i.e. the (2r+1)^2 block
--                           "including the corners" (a fireball's boxy burst).
--   * "diamond"          -- every cell within Manhattan distance `radius` (a pointed burst, no corners).
-- The DIRECTIONAL shapes orient off the caster->target vector, so they need `unit` (the caster):
--   * "line"             -- `length` tiles starting at (tx, ty) and running AWAY from the caster
--                           (a bolt punching through a row -- Powershot).
--   * "front"            -- a `width`-wide arc PERPENDICULAR to the facing, centred on (tx, ty)
--                           (a 3x1 sweep in front -- Cleave).
-- With no `aoe` (or radius 0) the footprint is just the target cell, so a single-target ability
-- and an AoE one share one path; a directional shape with no `unit` (or a target on the caster)
-- likewise falls back to the aimed cell. The single source of truth for BOTH what a cast hits
-- (fx.aoeUnits) and the red/green footprint highlight the battle state previews, so the two can
-- never disagree.
function Combat.aoeCells(combat, ab, tx, ty, unit)
    local aoe = ab and ab.aoe
    local cols = (combat.arena and combat.arena.cols) or 0
    local rows = (combat.arena and combat.arena.rows) or 0
    local cells = {}
    local function add(x, y)
        if x >= 1 and x <= cols and y >= 1 and y <= rows then
            cells[#cells + 1] = { x = x, y = y }
        end
    end

    local shape = aoe and aoe.shape
    if shape == "line" or shape == "front" then
        local dx, dy = 0, 0
        if unit then dx, dy = stepToward(unit.x, unit.y, tx, ty) end
        if dx == 0 and dy == 0 then add(tx, ty) return cells end -- no facing: just the aimed cell
        if shape == "line" then
            local length = (aoe and aoe.length) or 1
            for i = 0, length - 1 do add(tx + dx * i, ty + dy * i) end
        else -- "front": a width-wide line perpendicular to the facing, centred on the aimed cell
            local width = (aoe and aoe.width) or 1
            local px, py = -dy, dx -- rotate the facing 90 degrees for the perpendicular axis
            local half = math.floor(width / 2)
            for i = -half, half do add(tx + px * i, ty + py * i) end
        end
        return cells
    end

    local r = (aoe and aoe.radius) or 0
    local diamond = shape == "diamond"
    for dx = -r, r do
        for dy = -r, r do
            if not diamond or (math.abs(dx) + math.abs(dy) <= r) then
                add(tx + dx, ty + dy)
            end
        end
    end
    return cells
end

-- Living units standing on an ability's AoE footprint centred on (tx, ty) -- everyone a cast would
-- sweep, friend or foe. Reached through `fx.aoeUnits` so a data-file effect just iterates and hits;
-- a single-target ability (no `aoe`) yields only the occupant of the target cell, if any. `unit` is
-- the caster, needed to orient a directional footprint (line/front); harmless for the others.
function Combat.aoeUnits(combat, ab, tx, ty, unit)
    local out = {}
    for _, c in ipairs(Combat.aoeCells(combat, ab, tx, ty, unit)) do
        local u = Combat.unitAt(combat, c.x, c.y)
        if u then out[#out + 1] = u end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

-- Fold one unit's passive armor in: aggregate `item.bonus` (flat stat bonuses) and `item.resist`
-- (tag -> flat damage reduction) onto the unit WITHOUT mutating the shared character instance, so
-- a member's base stats never drift battle-to-battle. Split out so a unit that joins mid-battle
-- (Combat.addUnit) gets the same treatment as one placed at setup.
local function applyUnitPassives(unit)
    unit.bonus, unit.resist = {}, {}
    -- Aggregated bare-fist buffs (Iron/Shadow/Swift/Drunken Fist) and resource-ceiling raises
    -- (Toughness/Endurance/Attunement) from the grid. `unit.unarmedBonus` is read by the unarmed
    -- damage/range/hit paths; `char.maxBonus` is folded into Combat.unreservedMax (the one cap).
    -- Both are rebuilt from scratch here every setup, so nothing compounds battle to battle and the
    -- shared character instance's base stats are never mutated.
    unit.unarmedBonus = { power = 0, range = 0, hits = 0, drunkPower = 0 }
    local maxBonus = {}
    for _, item in ipairs(Character.eachItem(unit.char)) do
        for stat, amount in pairs(item.bonus or {}) do
            unit.bonus[stat] = (unit.bonus[stat] or 0) + amount
        end
        for tag, amount in pairs(item.resist or {}) do
            unit.resist[tag] = (unit.resist[tag] or 0) + amount
        end
        for stat, amount in pairs(item.unarmedBonus or {}) do
            unit.unarmedBonus[stat] = (unit.unarmedBonus[stat] or 0) + amount
        end
        for stat, amount in pairs(item.maxBonus or {}) do
            maxBonus[stat] = (maxBonus[stat] or 0) + amount
        end
    end
    unit.char.maxBonus = maxBonus
end

function Combat.applyPassives(combat)
    for _, unit in ipairs(combat.units) do applyUnitPassives(unit) end
end

-- Who drives this unit's turn: "player" (the battle state hands it the cursor and the item grid),
-- "ai" (Combat.planEnemyAction), or "none" (it holds position -- a decoy that must LOOK like a
-- real unit in the turn order without ever acting). Set from the unit's side at setup, and
-- inherited from the summoner for a summon, so an enemy-summoned wolf is AI-run for free.
function Combat.isPlayerControlled(unit)
    return unit ~= nil and unit.control == "player"
end

-- Add a unit to a battle already in progress (a summon). It joins combat.units, so every query
-- (turnOrder, unitAt, aliveCount, the renderer, the AI) picks it up with no further wiring.
--
-- Its starting initiative is its natural one (Combat.initiative), clamped at 0: a fast creature
-- acts soon and a slow one waits, but neither can cut ahead of the field's current baseline (the
-- acting unit sits at 0). Deliberately does NOT rebase -- the actor whose ability spawned this
-- unit is mid-turn at initiative 0, and rebasing under it would corrupt the timeline.
--
-- `opts`: control ("player"|"ai"|"none"; defaults from `side`), summoner (the unit sustaining it),
-- fragile (any hit is lethal), summoned (marks it as not a "real" combatant -- see Combat.evaluate),
-- duration (ticks it may stand before it fades; nil = until something kills it -- see Summon.tick).
function Combat.addUnit(combat, char, side, x, y, opts)
    opts = opts or {}
    local unit = {
        char = char, side = side,
        x = x, y = y,
        initiative = math.max(0, Combat.initiative(char)),
        speed = Combat.speed(char),
        alive = true,
        statuses = {},
        control = opts.control or (side == "party" and "player" or "ai"),
        summoner = opts.summoner,
        fragile = opts.fragile,
        summoned = opts.summoned,
        summonRemaining = opts.duration, -- nil for an indefinite summon; ticks down in rebase
    }
    unit.index = #combat.units + 1
    combat.units[unit.index] = unit
    applyUnitPassives(unit)
    -- Traits are attached but their opener is NOT fired: a summon arriving mid-battle did not start
    -- the battle. Its reactive hooks (onDamaged / onCast / onDeath) are live from this moment.
    Trait.attach(unit)
    return unit
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
                -- Side implies control, except where the caller overrides it: an escorted
                -- ally fights on the party's side but runs itself (control = "ai"/"none").
                control = u.control or ((side == "party") and "player" or "ai"),
            }
            unit.index = #combat.units + 1
            combat.units[unit.index] = unit
            -- Between-battle policy: stamina refills to max each battle (it's the renewable
            -- resource), while mana persists on the reused party instance (spent mana stays
            -- spent). Enemies are freshly instantiated, so this is a harmless no-op for them.
            -- Reservations never outlive the battle that made them (their summons are gone), so
            -- clear them BEFORE the refill or a stale one would cap stamina below its max. A summon
            -- claim (Combat.activeSummon) is the same kind of leftover: the wolf that was still
            -- standing at the last blow is not on this field, so its horn is free to blow again.
            if side == "party" then
                unit.char.reservations = nil
                for i = 1, Character.MAX_INVENTORY do
                    local item = unit.char.inventory[i]
                    if item then item.activeSummon = nil end
                end
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

    -- Passives (above) established each unit's resource ceilings, including any Endurance/Attunement
    -- raise. Stamina refills to its full effective ceiling for the party here -- addSide topped it to
    -- the BASE max before maxBonus existed, so a fresh battle's stamina pool includes the bonus.
    -- Mana is deliberately left where it stood (it persists between battles); the extra mana ceiling
    -- is headroom to recover into, exactly like the extra health ceiling.
    for _, unit in ipairs(combat.units) do
        if unit.side == "party" then
            local st = unit.char.stats.stamina
            if type(st) == "table" then st.current = Combat.unreservedMax(unit.char, "stamina") end
        end
    end

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

    -- Walls: conjured blockers (models/wall.lua), placed in-combat via fx.placeWall. Authored via
    -- arena.walls ({ id, x, y, side }) for a map that wants standing cover.
    combat.walls = {}
    for _, w in ipairs((arena and arena.walls) or {}) do
        Wall.place(combat, w.x, w.y, w.id, { side = w.side, duration = w.duration })
    end

    -- Authored traps are placed above WITHOUT logging (they're hidden until detected); the log
    -- opens on a clean "battle begins" line so the panel isn't empty on the first frame.
    Combat.logEvent(combat, "system", "The battle begins.")

    -- Last, so an opener that reads or reshapes the field (Envy copying your strongest unit) finds
    -- every unit, passive, trap and hazard already in place. Its lines follow the "battle begins".
    Trait.setup(combat)

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
    -- count hazard durations down (and let fire spread) by it, fade any timed summon whose time is
    -- up, and regenerate stamina by the same time.
    Status.tick(combat, minInit)
    Hazard.tick(combat, minInit)
    Summon.tick(combat, minInit)
    Wall.tick(combat, minInit)
    Combat.tickCooldowns(combat, minInit)
    Combat.regenerate(combat, minInit)
end

-- ---------------------------------------------------------------------------
-- Cooldowns
--
-- A cooldown is a per-unit timer keyed by a string (usually a trait id), measured in the same
-- *ticks* every duration uses. A triggered ability (a counter) fires, sets a cooldown, and stays
-- silent until it counts back to 0 -- the recharge Combat.tickCooldowns runs from rebase, beside
-- Status.tick. Deliberately generic: any future "once every N ticks" effect hangs its key here
-- rather than inventing its own clock.
-- ---------------------------------------------------------------------------

-- Put `key` on cooldown for `ticks` on `unit` (refreshes to the longer of any existing remaining).
function Combat.setCooldown(unit, key, ticks)
    unit.cooldowns = unit.cooldowns or {}
    unit.cooldowns[key] = math.max(unit.cooldowns[key] or 0, ticks or 0)
end

-- Is `key` still recharging on `unit`? False once it has counted back to 0 (or was never set).
function Combat.onCooldown(unit, key)
    local cd = unit.cooldowns
    return cd ~= nil and (cd[key] or 0) > 0
end

-- Count every unit's cooldowns down by `elapsed` ticks, clearing any that reach 0. Called from
-- Combat.rebase with the ticks that just elapsed, the same amount fed to Status.tick.
function Combat.tickCooldowns(combat, elapsed)
    if not elapsed or elapsed <= 0 then return end
    for _, u in ipairs(combat.units) do
        local cd = u.cooldowns
        if cd then
            for key, remaining in pairs(cd) do
                local left = remaining - elapsed
                if left <= 0 then cd[key] = nil else cd[key] = left end
            end
        end
    end
end

-- Mana regenerated per tick by an Arcane Reservoir bearer -- the lone exception to "mana never
-- regenerates". Everyone else's rate is zero, so the global rule holds; the trait is what bends it.
Combat.ARCANE_REGEN = 1
-- Health an adjacent Sanctified Presence restores per tick, to each ally it wards (and to the priest).
Combat.SANCTIFY_HEAL = 1

-- Is `u` warded by a Sanctified Presence this tick? True if it bears the trait itself (the priest is
-- its own font) or stands orthogonally adjacent to a living ally that does.
local function nearSanctifier(combat, u)
    if Trait.has(u, "sanctified_presence") then return true end
    for _, o in ipairs(combat.units) do
        if o.alive and o ~= u and o.side == u.side and Trait.has(o, "sanctified_presence")
            and manhattan(o.x, o.y, u.x, u.y) == 1 then
            return true
        end
    end
    return false
end

-- Passive recovery each rebase: every living unit regains its staminaRegen rate per elapsed tick
-- (clamped to max). Mana deliberately does NOT regenerate -- except for an Arcane Reservoir bearer.
-- A unit under a Sanctified Presence also mends a little health. Called from rebase with the ticks
-- that just elapsed (the same amount fed to Status.tick), so recovery scales with time on the clock.
function Combat.regenerate(combat, elapsed)
    if not elapsed or elapsed <= 0 then return end
    for _, u in ipairs(combat.units) do
        if u.alive then
            Combat.restoreResource(u.char, "stamina", flatStat(u, "staminaRegen") * elapsed)
            -- Quiet heals (no per-tick log line, like stamina): the badge/aura is the tell, not the log.
            if Trait.has(u, "arcane_reservoir") then
                Combat.restoreResource(u.char, "mana", Combat.ARCANE_REGEN * elapsed)
            end
            if nearSanctifier(combat, u) then
                Combat.restoreResource(u.char, "health", Combat.SANCTIFY_HEAL * elapsed)
            end
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

-- The first walkable, unoccupied tile in the 8-neighbourhood of (x, y), or nil when the spot is
-- hemmed in. The same standard `useItem` enforces for a `target = "tile"` cast -- so an effect that
-- has to PUT something down beside a unit it picked by name (the Philosopher's Stone copying a foe
-- onto the ground next to its caster) can honour that standard without re-deriving it.
--
-- Orthogonals before diagonals: a body set down beside you should read as beside you.
function Combat.openTileNear(combat, x, y)
    local ring = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 }, { 1, -1 }, { 1, 1 }, { -1, 1 }, { -1, -1 } }
    for _, d in ipairs(ring) do
        local nx, ny = x + d[1], y + d[2]
        local row = combat.arena and combat.arena.tiles and combat.arena.tiles[ny]
        local cell = row and row[nx]
        if cell and cell.walkable and not Combat.unitAt(combat, nx, ny) then
            return nx, ny
        end
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
                    if cell.walkable and not Combat.unitAt(combat, nx, ny)
                        and not Wall.blocksAt(combat, nx, ny) then
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

-- Everything a unit sets off by arriving on (x, y): an opposing trap on the tile triggers, and any
-- hazard there fires its on-entry effect. Shared by a walk (Combat.moveUnit, per path tile), by
-- forced movement (knockback / pull), and by a summon appearing (models/summon.lua) -- so being
-- shoved across a spike trap, or conjured on top of one, is exactly as dangerous as walking over it.
--
-- The unit must already stand on (x, y) when this is called: a trap may kill it, and the death path
-- reads its position. Callers move it first, then announce the arrival.
function Combat.enterTile(combat, unit, x, y)
    local trap = Trap.at(combat, x, y)
    if trap then Trap.trigger(combat, trap, unit) end
    if unit.alive then
        Hazard.onEnter(combat, unit, x, y)
        Combat.updateAuras(combat, unit)
    end
end

-- Drop any "aura" status the unit is no longer standing in. An aura status carries `source` = the id
-- of the hazard that granted it (e.g. Sanctuary's Regeneration -> "hazard_heal"); it lasts only while
-- a live hazard of that id sits under the unit. Called from Combat.enterTile, the one chokepoint every
-- position change routes through (a walk step, a knockback / pull, a summon appearing), so leaving a
-- Sanctuary ends its blessing on the very beat the unit steps off -- not `regen` ticks later. A status
-- with no `source` (a spell / potion buff) is never touched.
function Combat.updateAuras(combat, unit)
    local list = unit.statuses
    if not list then return end
    for i = #list, 1, -1 do
        local s = list[i]
        if s.source and not Hazard.at(combat, unit.x, unit.y, s.source) then
            table.remove(list, i)
            if not s.def.hideLog then
                Combat.logEvent(combat, "status",
                    string.format("%s's %s fades outside the %s.",
                        unitName(unit), s.name or s.id, Hazard.defs[s.source] and Hazard.defs[s.source].name or "zone"))
            end
        end
    end
end

-- The initiative a walk of terrain-weighted `cost` actually charges `unit`: the raw path cost
-- scaled by the unit's status cost multiplier, exactly as Combat.abilityCost prices a cast (Haste
-- halves both -- a quickened unit is quicker on its feet as well as with its hands). Movement RANGE
-- is deliberately untouched: Combat.reachable still spends the raw path cost against the movement
-- budget, so a hasted unit walks exactly as far, it just comes back around the turn order sooner.
function Combat.moveInitiative(unit, cost)
    return math.floor((cost or 0) * Status.costMultiplier(unit) + 0.5)
end

-- The walk a unit would take to reach (x, y): `{ unit, path, cost }`, where `path` is the
-- ORIGIN-FIRST list of `{ x, y }` tiles it steps through and `cost` the raw terrain-weighted path
-- cost. Pure -- nothing is mutated -- so one legality gate serves both the instant Combat.moveUnit
-- and the battle state's tile-at-a-time walk. Returns nil + a reason when the move is illegal.
function Combat.planMove(combat, unit, x, y)
    if not unit.alive then return nil, "dead" end
    if not combat.turn or combat.turn.unit ~= unit then return nil, "not this unit's turn" end
    if combat.turn.moved then return nil, "already moved" end
    if Status.blocksMove(unit) then return nil, "rooted" end
    local reachable = Combat.reachable(combat, unit)
    local node = reachable[key(x, y)]
    if not node then return nil, "unreachable" end

    -- Walk the fromKey chain back from the destination -- it stops at the first step, the origin
    -- having been cleared from the reachable set -- then reverse it and put the origin back on the
    -- front, so `path` reads in the order the unit's feet take it.
    local back = {}
    local n = node
    while n do
        back[#back + 1] = n
        n = n.fromKey and reachable[n.fromKey] or nil
    end
    local path = { { x = unit.x, y = unit.y } }
    for i = #back, 1, -1 do path[#path + 1] = { x = back[i].x, y = back[i].y } end

    return { unit = unit, path = path, cost = node.cost }
end

-- Open a walk. The unit has now spent its one move for the turn and owes the move initiative at
-- end of turn, but it has NOT left the origin: Combat.stepMove carries it, one tile per call.
-- Returns the walk handle to feed back into stepMove. Moving never ends the turn -- the unit can
-- still act or wait once it arrives.
function Combat.beginMove(combat, plan)
    local unit = plan.unit
    local dest = plan.path[#plan.path]
    combat.turn.moved = true
    combat.turn.moveCost = Combat.moveInitiative(unit, plan.cost)
    Combat.logEvent(combat, "move",
        string.format("%s moves to (%d, %d).", unitName(unit), dest.x, dest.y))
    return { unit = unit, path = plan.path, index = 1 }
end

-- Carry the walk's unit onto the next tile of its path, setting off everything that tile holds:
-- an opposing trap, and the on-entry effect of any hazard standing on it. Returns true while the
-- walk has further to go, so a caller can drive it either flat-out (moveUnit) or a tile per
-- animation beat (states/battle.lua). A unit killed en route -- a spike trap, a fire it walked
-- into -- stops on the tile it fell on rather than sliding on to the destination.
function Combat.stepMove(combat, walk)
    if not walk.unit.alive or walk.index >= #walk.path then return false end
    walk.index = walk.index + 1
    local tile = walk.path[walk.index]
    walk.unit.x, walk.unit.y = tile.x, tile.y
    Combat.enterTile(combat, walk.unit, tile.x, tile.y)
    return true
end

-- Move a unit to (x, y) if reachable this turn, all in one go. The headless equivalent of the
-- battle state's watchable walk (planMove -> beginMove -> stepMove per tile): same legality gate,
-- same traps sprung, same initiative owed. Returns ok plus the move initiative it charged.
function Combat.moveUnit(combat, unit, x, y)
    local plan, reason = Combat.planMove(combat, unit, x, y)
    if not plan then return false, reason end
    local walk = Combat.beginMove(combat, plan)
    while Combat.stepMove(combat, walk) do end
    return true, combat.turn.moveCost
end

-- ---------------------------------------------------------------------------
-- Forced movement (knockback / pull)
--
-- A unit shoved across the board isn't walking: it pays no move cost, doesn't spend its turn, and
-- ignores its movement stat -- but it still sets off whatever it is dragged over (enterTile). A
-- push stops dead against the first thing it can't pass through; a pull stops once it is adjacent.
-- ---------------------------------------------------------------------------

-- Flat damage everything involved in a collision takes when a shove is stopped short. The mace /
-- Push ability override it with their Power (opts.power).
Combat.COLLISION_DAMAGE = 4

-- The cardinal step matching a delta, along the DOMINANT axis (a diagonal shove resolves to the
-- axis it leans on; an exact diagonal breaks toward x). The grid is 4-directional, so forced
-- movement is too.
local function signDominant(dx, dy)
    return stepToward(0, 0, dx, dy)
end

-- Can `unit` be shoved onto (x, y)? Returns ok, blocker -- where a nil blocker on a failed step
-- means the way is barred by the map itself (an edge, or impassable terrain).
local function canShoveInto(combat, x, y)
    local row = combat.arena and combat.arena.tiles and combat.arena.tiles[y]
    local cell = row and row[x]
    if not (cell and cell.walkable) then return false, nil end
    if Wall.blocksAt(combat, x, y) then return false, nil end -- a conjured wall bars the shove
    local blocker = Combat.unitAt(combat, x, y)
    if blocker then return false, blocker end
    return true, nil
end

-- Slide `unit` one tile by (dx, dy), triggering whatever it lands on. Returns false on a blocked
-- tile without moving it.
local function shoveStep(combat, unit, dx, dy)
    local nx, ny = unit.x + dx, unit.y + dy
    if not canShoveInto(combat, nx, ny) then return false end
    unit.x, unit.y = nx, ny
    Combat.enterTile(combat, unit, nx, ny)
    return true
end

-- Knock `target` up to `distance` tiles directly away from `source`. The direction is fixed at the
-- start (a straight line, however far it travels). A shove barred by the map edge, impassable
-- terrain, or another unit stops there and hurts EVERYONE involved -- the target and, if there was
-- one, whatever it slammed into. Returns (tilesMoved, collided).
function Combat.knockback(combat, source, target, distance, opts)
    opts = opts or {}
    if not (target and target.alive) then return 0, false end
    local power = opts.power or Combat.COLLISION_DAMAGE
    local dx, dy = signDominant(target.x - source.x, target.y - source.y)
    if dx == 0 and dy == 0 then return 0, false end

    local moved = 0
    for _ = 1, (distance or 1) do
        local ok, blocker = canShoveInto(combat, target.x + dx, target.y + dy)
        if not ok then
            Combat.logEvent(combat, "damage",
                string.format("%s slams into %s.", unitName(target),
                    blocker and unitName(blocker) or "an obstacle"))
            Combat.dealFlatDamage(combat, target, power, { "physical", "impact" }, "the impact")
            if blocker and blocker.alive then
                Combat.dealFlatDamage(combat, blocker, power, { "physical", "impact" }, "the impact")
            end
            return moved, true
        end
        shoveStep(combat, target, dx, dy)
        moved = moved + 1
        Combat.logEvent(combat, "move",
            string.format("%s is knocked back to (%d, %d).", unitName(target), target.x, target.y))
        -- A trap or hazard on the tile it was driven onto may have finished it; stop the slide.
        if not target.alive then return moved, false end
    end
    return moved, false
end

-- Drag `target` toward `source` until it stands adjacent. Needs a clear line of sight (you can't
-- hook what you can't see). The direction is re-aimed EVERY step -- a fixed one would march a
-- diagonal target straight past the source along a single axis. Stops early on a blocked tile.
-- Returns (true, tilesMoved) or (false, reason).
function Combat.pull(combat, source, target)
    if not (target and target.alive) then return false, "dead" end
    if not Combat.hasLineOfSight(combat, source.x, source.y, target.x, target.y) then
        return false, "no line of sight"
    end
    local moved = 0
    while manhattan(source.x, source.y, target.x, target.y) > 1 do
        local dx, dy = signDominant(source.x - target.x, source.y - target.y)
        if not shoveStep(combat, target, dx, dy) then break end
        moved = moved + 1
        Combat.logEvent(combat, "move",
            string.format("%s is pulled to (%d, %d).", unitName(target), target.x, target.y))
        if not target.alive then break end
    end
    return true, moved
end

-- Set `unit` down on (x, y) in a blink, setting off whatever the tile holds (a trap, a hazard) --
-- the self-relocation a Leaping Crash makes before it bursts. No move cost and no line check: a
-- teleport, not a walk. Returns true once placed (false for a dead/nil unit).
function Combat.teleportUnit(combat, unit, x, y)
    if not (unit and unit.alive) then return false end
    unit.x, unit.y = x, y
    Combat.logEvent(combat, "move",
        string.format("%s leaps to (%d, %d).", unitName(unit), x, y))
    Combat.enterTile(combat, unit, x, y)
    return true
end

-- A Charge: `user` pins the foe directly in front and drives it `distance` tiles straight ahead,
-- moving in lockstep behind it (the target leads, the charger follows into the tile it vacates). The
-- direction is fixed at the outset. The run stops the moment the lane ahead is barred by impassable
-- terrain, a wall, or the board edge. Any OTHER unit caught in the lane is shoved one tile to the
-- side and takes minor impact damage; if it cannot be cleared, the charge grinds to a halt against
-- it. `target` must start orthogonally adjacent (the "pin"). Returns the number of tiles advanced.
function Combat.charge(combat, user, target, distance)
    if not (user and user.alive and target and target.alive) then return 0 end
    if manhattan(user.x, user.y, target.x, target.y) ~= 1 then return 0 end -- must be pinned in front
    local dx, dy = signDominant(target.x - user.x, target.y - user.y)
    if dx == 0 and dy == 0 then return 0 end

    local moved = 0
    for _ = 1, (distance or 1) do
        if not (user.alive and target.alive) then break end
        local fx_, fy_ = target.x + dx, target.y + dy
        local ok, blocker = canShoveInto(combat, fx_, fy_)
        if not ok then
            if not blocker then break end -- impassable terrain / wall / edge halts the charge
            -- A bystander in the lane: shove it aside (either perpendicular) and bloody it.
            local px, py = -dy, dx
            local pushed = shoveStep(combat, blocker, px, py) or shoveStep(combat, blocker, -px, -py)
            Combat.logEvent(combat, "damage",
                string.format("%s is trampled by the charge.", unitName(blocker)))
            Combat.dealFlatDamage(combat, blocker, Combat.COLLISION_DAMAGE, { "physical", "impact" }, "the charge")
            ok = canShoveInto(combat, fx_, fy_) -- the lane may now be clear (pushed aside, or slain)
            if not ok then break end
        end
        local oldTx, oldTy = target.x, target.y
        target.x, target.y = fx_, fy_
        Combat.enterTile(combat, target, fx_, fy_)
        if user.alive then
            user.x, user.y = oldTx, oldTy
            Combat.enterTile(combat, user, oldTx, oldTy)
        end
        moved = moved + 1
        Combat.logEvent(combat, "move",
            string.format("%s charges, driving %s to (%d, %d).", unitName(user), unitName(target), fx_, fy_))
        if not target.alive then break end
    end
    return moved
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
-- fold into the attack, the statuses to inflict on a damaged target, and the numeric modifiers a
-- neighboring charm grants the cast. Returns (tags, statuses, mods) where mods is
-- { power, range, preserve }: `power`/`range` add to the ability's Power and reach (an Alchemic
-- Mastery / Long-Fuse Reagent charm buffing an adjacent bomb), and `preserve` spares a consumable's
-- stack when it is used (an Everflask). All three are additive across every applicable neighbor.
local function adjacencyAura(char, item)
    local tags, statuses = {}, {}
    local mods = { power = 0, range = 0, preserve = false, lifesteal = 0 }
    local idx = char and Character.slotIndex(char, item)
    if idx then
        for _, nb in ipairs(Character.adjacentItems(char, idx)) do
            if nb.aura and Combat.auraApplies(nb.aura, item) then
                for _, t in ipairs(nb.aura.grantTags or {}) do tags[#tags + 1] = t end
                if nb.aura.status then statuses[#statuses + 1] = nb.aura.status end
                mods.power = mods.power + (nb.aura.powerBonus or 0)
                mods.range = mods.range + (nb.aura.rangeBonus or 0)
                mods.lifesteal = mods.lifesteal + (nb.aura.lifesteal or 0) -- Vampiric Strike: heal a share of damage
                if nb.aura.preserve then mods.preserve = true end
            end
        end
    end
    return tags, statuses, mods
end

-- The range a neighboring charm's aura adds to a cast of `item` from `char`'s grid (a Long-Fuse
-- Reagent lengthening an adjacent bomb's throw), or 0. Public so the range gate, the targeting
-- highlight, the target scan, and the AI all extend reach by the same amount the cast will get --
-- a highlight that outran the gate (or fell short of it) would read as a bug.
function Combat.adjacencyRangeBonus(char, item)
    if not (char and item) then return 0 end
    local _, _, mods = adjacencyAura(char, item)
    return mods.range
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

-- An adjacency predicate as the player reads it: "adjacent bow", "adjacent weapon". Public so the
-- slot badge and the tooltip name a requirement the same way.
function Combat.adjacencyLabel(pred)
    return "adjacent " .. ((pred and (pred.tag or pred.type)) or "item")
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
function Combat.mitigatedDamage(target, base, tags, opts)
    tags = tags or {}
    local magical = hasTag(tags, "magical")
    -- A barrier of the incoming school swallows the hit whole: report 0 so the damage preview reads
    -- the negation. Combat.dealFlatDamage makes the same check and is the one that CONSUMES the
    -- barrier -- this read never mutates, so a hovered target never spends someone's ward.
    if Status.barrierAgainst(target, magical) then return 0 end
    -- Raw (armor-piercing) damage skips defense and tag resists entirely -- a Penetrating Strike
    -- that lands its full Power on the flesh. Barriers and vulnerabilities still apply (a ward is
    -- not armor). Floors at 1 like any hit.
    if opts and opts.raw then
        local vuln = Status.vulnerability(target, tags)
        return math.max(1, math.floor(base + vuln + 0.5))
    end
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

-- A decoy that is gone stops being a lie. Its deployment wrote a fake "moves to (x, y)" line into
-- the log (data/items/utility/decoy.lua) and kept a handle on it; rewrite that entry IN PLACE, so
-- re-reading the log tells the truth about what really happened on that turn. A no-op for a decoy
-- whose line has already aged out of the log, and for any unit that isn't a decoy.
local function correctDecoyRecord(decoy)
    local faked = decoy.decoyLogEntry
    if not faked then return end
    faked.kind = "status"
    faked.text = string.format("%s never moved to (%d, %d) -- that was the decoy.",
        unitName(decoy.decoyOf), decoy.x, decoy.y)
    decoy.decoyLogEntry = nil
end

-- A decoy struck down: correct the record, and drag the caster it was hiding back into view. The
-- concealment may have already lapsed on its own (Invisible ends at the caster's next turn), in
-- which case there is nobody left to reveal.
local function unmaskDecoy(combat, decoy)
    local caster = decoy.decoyOf
    Combat.logEvent(combat, "death", string.format("%s's decoy is destroyed.", unitName(caster)))
    correctDecoyRecord(decoy)
    if caster.alive and Status.has(caster, "invisible") then
        Status.remove(caster, "invisible")
        Combat.logEvent(combat, "status", string.format("%s is revealed!", unitName(caster)))
    end
end

-- Take a summon off the field without killing it: its summoner fell, or the binding that held it
-- ran out (Summon.tick). Not a death -- nothing struck it -- so it is logged as vanishing rather
-- than as a defeat, and `text` lets the caller say why. Everything its presence held up is unwound:
-- whatever IT was sustaining is dismissed in turn (the chain always terminates -- a summoner exists
-- before its summon, so the bond can't loop), and its reservations are released.
--
-- The one place a summon leaves the field short of dying, so the `activeSummon` claim and the
-- reservation are freed together, from here, however it went.
function Combat.dismiss(combat, unit, text)
    if not unit or not unit.alive then return end
    unit.alive = false
    Combat.logEvent(combat, "death", text or string.format("%s vanishes.", unitName(unit)))
    -- A decoy dismissed alongside the caster it was covering for: nobody is left to reveal, but the
    -- fake move it wrote is still sitting in the log. Set it straight.
    correctDecoyRecord(unit)
    for _, u in ipairs(combat.units) do
        if u.alive and u.summoner == unit then Combat.dismiss(combat, u) end
    end
    Combat.releaseHeldBy(combat, unit)
end

-- Everything that follows from a unit dropping: mark it dead, log the kill, and unwind whatever
-- its existence was holding up. Called from the one place a unit can die (Combat.dealFlatDamage).
--   * A destroyed decoy unmasks itself, and the caster it was hiding (see above).
--   * A dead unit's summons vanish with it -- which is what keeps the objectives honest: kill the
--     enemy summoner and its wolf goes too, so `killAll` can still resolve.
--   * Reservations sustained by the dead unit are released, on whichever character holds them
--     (a summon's death frees its summoner's mana); a dead caster drops its own.
local function killUnit(combat, target)
    target.alive = false

    -- A "real" fallen combatant leaves a body behind: mark it a corpse so it can be reanimated
    -- (Revive puts the same character back on its feet) or raised (Raise Dead turns it into a zombie).
    -- A summoned creature and a decoy leave nothing -- they were never truly there -- so they are
    -- skipped, which also keeps a raised zombie or a dismissed wolf from itself becoming a corpse.
    if not target.summoned and not target.decoyOf then
        target.corpse = true
    end

    -- A decoy wears its caster's name, so "Archer is defeated!" would read as the real thing dying.
    if target.decoyOf then
        unmaskDecoy(combat, target)
    else
        Combat.logEvent(combat, "death", string.format("%s is defeated!", unitName(target)))
    end

    -- Before the unwinding below, so a dying trait still has its summons and reservations to spend.
    Trait.onDeath(combat, target, {})

    for _, u in ipairs(combat.units) do
        if u.alive and u.summoner == target then Combat.dismiss(combat, u) end
    end

    Combat.releaseHeldBy(combat, target)
    target.char.reservations = nil
end

-- An adjacent ally may throw itself in front of a blow aimed at `target`, taking it instead. Returns
-- the guardian to strike (and spends its intercept) or nil for no redirect. Two guard kinds, both set
-- by an onCombatStart trait onto `unit.guard`:
--   * "oathward"  -- soaks the FIRST hit on an adjacent ally each turn (a cooldown gates the rest)
--   * "martyr"    -- takes a would-be-LETHAL blow for an adjacent ally, once per battle
-- The intercept's own damage runs through dealFlatDamage again (so the guardian's armor and barriers
-- apply); each redirect spends a charge, so a ring of guardians can't bounce a hit forever.
function Combat.tryRedirect(combat, target, base, tags)
    for _, g in ipairs(combat.units) do
        if g.alive and g.guard and g ~= target and g.side == target.side
            and manhattan(g.x, g.y, target.x, target.y) == 1 then
            local kind = g.guard.kind
            if kind == "oathward" and not Combat.onCooldown(g, "oathward") then
                Combat.setCooldown(g, "oathward", g.guard.cooldown or 6)
                Combat.logEvent(combat, "action",
                    string.format("%s takes the blow for %s!", unitName(g), unitName(target)))
                return g
            elseif kind == "martyr" and not g.guard.used then
                if Combat.mitigatedDamage(target, base, tags) >= (target.char.stats.health.current or 0) then
                    g.guard.used = true
                    Combat.logEvent(combat, "action",
                        string.format("%s throws itself in front of %s!", unitName(g), unitName(target)))
                    return g
                end
            end
        end
    end
    return nil
end

function Combat.dealFlatDamage(combat, target, base, tags, source, attacker, opts)
    -- An adjacent guardian (Oathward, Martyr's Vow) may take the blow in the target's place. The
    -- redirected hit re-enters here on the guardian, so its own armor, barrier and traits all apply.
    local guardian = Combat.tryRedirect(combat, target, base, tags)
    if guardian then
        return Combat.dealFlatDamage(combat, guardian, base, tags, source, attacker, opts)
    end
    -- A barrier of the incoming school (physical/magical, the same switch mitigation reads) negates
    -- the blow outright: consume that one ward, deal nothing, and return BEFORE the trait dispatch --
    -- an absorbed hit is not a "wound survived", so it grants no rage and advances no threshold phase.
    local barrier = Status.barrierAgainst(target, hasTag(tags or {}, "magical"))
    if barrier then
        Status.remove(target, barrier.id)
        Combat.logEvent(combat, "status",
            string.format("%s's %s absorbs the blow.", unitName(target), barrier.name or barrier.id))
        return 0
    end
    -- A standing Dodge reflex (a trait on cooldown, not a consumed status) voids a physical blow
    -- outright. Like the barrier above it returns BEFORE the trait damage dispatch -- an evaded hit is
    -- not a wound survived, so it grants no rage, advances no threshold phase, and provokes no counter.
    if Trait.tryEvade(combat, target, tags) then
        return 0
    end
    local dmg = Combat.mitigatedDamage(target, base, tags, opts)
    local hp = target.char.stats.health
    hp.current = hp.current - dmg
    if source then
        Combat.logEvent(combat, "damage",
            string.format("%s takes %d damage from %s.", unitName(target), dmg, source))
    else
        Combat.logEvent(combat, "damage", string.format("%s takes %d damage.", unitName(target), dmg))
    end
    -- A berserk window (Fury's `preventsDeath` status) holds the bearer up at 1 HP through a blow
    -- that would fell it -- but never a `fragile` shape (a decoy/doppelganger is unmade by any hit).
    if hp.current <= 0 and not target.fragile and Status.preventsDeath(target) then
        hp.current = 1
        Combat.logEvent(combat, "action",
            string.format("%s refuses to fall!", unitName(target)))
        Trait.onDamaged(combat, target, { amount = dmg, tags = tags, source = source, attacker = attacker })
        return dmg
    end
    -- A `fragile` unit (a doppelganger, a decoy) dies to ANY hit, however light. Damage floors at 1
    -- in mitigatedDamage, so reaching here at all is fatal for one.
    if hp.current <= 0 or target.fragile then
        -- A once-per-battle Second Wind trait may catch a would-be-lethal blow and stand the bearer
        -- back up at half health, exactly like a barrier voids a hit -- but only a "real" unit
        -- (never a fragile shape, which the check above already excluded from the death path).
        if not target.fragile and Trait.trySurvive(combat, target) then
            Trait.onDamaged(combat, target, { amount = dmg, tags = tags, source = source, attacker = attacker })
            return dmg
        end
        hp.current = 0
        killUnit(combat, target)
    else
        -- Reaction traits fire here and nowhere else: AFTER mitigation, so a hook reads the damage
        -- that actually landed, and only on a SURVIVOR, so the blow that kills you grants no rage and
        -- a boss's health-threshold phase can never trigger on a corpse. Nothing in the damage
        -- PREVIEW reaches this function (previewAbility routes through Combat.computeDamage), so a
        -- hovered target never quietly advances a trait.
        Trait.onDamaged(combat, target, { amount = dmg, tags = tags, source = source, attacker = attacker })
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
    local base = power + flatStat(user, atkStat) + unarmedPowerBonus(user, item)
    -- `user` rides along as the attacker so a reaction trait (a counter) knows who struck, and how
    -- far away they stood. A flat source (a trap, a burn) passes no attacker and provokes no counter.
    local dealt = Combat.dealFlatDamage(combat, target, base, tags, nil, user, opts)
    -- Let the attacker's statuses record what they just did (Fury banks damage dealt to heal from
    -- later). Fired here, where the attacker is known, only for a survived-or-not real hit.
    Status.onDealDamage(combat, user, dealt)
    return dealt
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
    local base = power + flatStat(user, atkStat) + unarmedPowerBonus(user, item)
    return Combat.mitigatedDamage(target, base, tags, opts)
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

-- Restore health to `target`, capped at its ceiling (its max less any reserved health -- reserved
-- life can't be healed back into). Returns the amount actually healed. Reached through `fx.heal`
-- inside an ability effect.
function Combat.applyHeal(combat, target, amount)
    local hp = target.char.stats.health
    local before = hp.current
    hp.current = math.min(Combat.unreservedMax(target.char, "health"), hp.current + (amount or 0))
    local healed = math.max(0, hp.current - before)
    if healed > 0 then
        Combat.logEvent(combat, "heal", string.format("%s is healed for %d.", unitName(target), healed))
    end
    return healed
end

-- Strip every debuff from `unit` and log it (Cure). Delegates the removal to Status.cleanse -- the
-- single rule for what counts as a debuff -- and adds the log line the spell wants. Returns the count.
function Combat.cleanse(combat, unit)
    local n = Status.cleanse(unit)
    if n > 0 then
        Combat.logEvent(combat, "status",
            string.format("%s is cleansed of %d debuff%s.", unitName(unit), n, n == 1 and "" or "s"))
    end
    return n
end

-- ---------------------------------------------------------------------------
-- Corpses (reanimation / raising)
--
-- A "real" unit that dies stays in combat.units flagged `corpse` (killUnit), lying on its last tile.
-- It is not alive -- unitAt / turnOrder / aliveCount all ignore it, so a living unit may walk over it
-- and the objectives resolve as normal -- but it is still THERE to be brought back:
--   * Combat.reanimate -- Revive: the same character stands up again at a fraction of its health.
--   * Combat.raiseZombie -- Raise Dead: the body is consumed and a fresh zombie takes its place.
-- Either path clears `corpse`, so a body can only be used once.
-- ---------------------------------------------------------------------------

-- The corpse on (x, y), or nil. A tile with a LIVING unit on it has no reachable corpse (you can't
-- work on a body someone is standing on) -- Revive's "as long as no one is on top of the tile".
function Combat.corpseAt(combat, x, y)
    if Combat.unitAt(combat, x, y) then return nil end
    for _, u in ipairs(combat.units) do
        if u.corpse and not u.alive and u.x == x and u.y == y then return u end
    end
    return nil
end

-- Every reachable corpse standing on the given cells (a list of { x, y }) -- what Raise Dead sweeps
-- across its footprint. Skips a tile a living unit occupies (Combat.corpseAt's rule).
function Combat.corpsesIn(combat, cells)
    local out = {}
    for _, c in ipairs(cells or {}) do
        local corpse = Combat.corpseAt(combat, c.x, c.y)
        if corpse then out[#out + 1] = corpse end
    end
    return out
end

-- Reanimate a corpse: the same character rises again on its own side at `fraction` (default 0.5) of
-- its health ceiling, its debuffs and wounds wiped, slotted back into the turn order at a natural
-- initiative. Refuses a tile a living unit now stands on. Returns true on success. The heart of
-- Revive (and the revive scroll). The unit keeps its identity -- its id, its kit, its traits -- so an
-- escorted ally brought back still counts for a protect objective.
function Combat.reanimate(combat, corpse, fraction)
    if not corpse or corpse.alive or not corpse.corpse then return false end
    if Combat.unitAt(combat, corpse.x, corpse.y) then return false end
    fraction = fraction or 0.5
    corpse.alive = true
    corpse.corpse = false
    corpse.statuses = {}
    local hp = corpse.char.stats.health
    hp.current = math.max(1, math.floor(Combat.unreservedMax(corpse.char, "health") * fraction + 0.5))
    -- A body raised mid-battle rejoins like a fresh summon: its natural initiative, clamped so it can't
    -- cut ahead of the acting unit (which sits at 0). No rebase -- the caster is mid-turn.
    corpse.initiative = math.max(0, Combat.initiative(corpse.char))
    Combat.logEvent(combat, "heal", string.format("%s rises again!", unitName(corpse)))
    return true
end

-- Raise a corpse as a zombie: consume the body (it can't be revived or raised again) and put a fresh
-- `charId` creature on `caster`'s side where it lay, AI-run (yours in allegiance but not in command)
-- and sustained by the caster. Returns the new unit (which may already be dead if its tile is deadly).
function Combat.raiseZombie(combat, caster, corpse, charId, opts)
    if not corpse or corpse.alive or not corpse.corpse then return nil end
    opts = opts or {}
    local x, y = corpse.x, corpse.y
    corpse.corpse = false -- the body is spent, whatever becomes of the zombie
    return Summon.spawn(combat, caster, charId, x, y, {
        control = "ai",              -- allied but not directly controllable
        side = caster.side,
        duration = opts.duration,    -- zombies rot away on a timer if the caller sets one
        power = opts.power,
        scaling = opts.scaling,
    })
end

-- A throwaway unit handed back by a dry run's `summon`/`copy` so an effect that keeps using the
-- creature it just called (buffing it, moving it) works on something rather than nil. Nothing
-- reads it back out -- it exists only to keep the replayed effect from faulting.
local function previewStandIn()
    return {
        char = { name = "Summon", stats = { health = { max = 1, current = 1 } }, inventory = {} },
        x = 0, y = 0, alive = true, side = "party", initiative = 0, statuses = {},
    }
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
    local auraTags, auraStatuses, auraMods = adjacencyAura(unit.char, item)
    -- Fold in a neighboring Alchemic Mastery charm's Power bonus exactly as Combat.useItem does, so
    -- the previewed number matches the hit the player is about to land.
    local effectivePower = ab.power and (ab.power + auraMods.power) or ab.power
    local fx = {
        user = unit, target = target, item = item, combat = combat, tx = tx, ty = ty,
        power = effectivePower, -- the ability's balance scalar; effects derive heal/status magnitude from it
        unitAt = function(x, y) return Combat.unitAt(combat, x, y) end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
        -- A free tile beside (x, y) to set something down on, or nil when the spot is hemmed in.
        -- Read-only, so the dry run may answer it truthfully.
        openTileNear = function(x, y) return Combat.openTileNear(combat, x, y) end,
        aoeUnits = function() return Combat.aoeUnits(combat, ab, tx, ty, unit) end,
        aoeCells = function() return Combat.aoeCells(combat, ab, tx, ty, unit) end,
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
            opts = opts or {}
            if opts.power == nil then opts.power = effectivePower end
            local d = Combat.computeDamage(combat, unit, tgt, item, withAuraTags(opts, auraTags))
            local e = entryFor(tgt)
            e.damage = e.damage + d
            if d > 0 then
                for _, st in ipairs(auraStatuses) do
                    e.statuses[#e.statuses + 1] = { id = st.id, def = Status.defs[st.id], opts = st.opts }
                end
                -- A neighboring Vampiric Strike charm heals the caster for a share of the hit -- show
                -- it on the caster's own bar so the previewed heal matches the live cast.
                if auraMods.lifesteal > 0 then
                    entryFor(unit).heal = entryFor(unit).heal + math.floor(d * auraMods.lifesteal)
                end
            end
            return d
        end,
        heal = function(tgt, amount)
            if not tgt then return 0 end
            local hp = tgt.char.stats.health
            -- Clamp at the same ceiling Combat.applyHeal uses (max less any reserved health), so a
            -- previewed heal on a summoner never promises life the reservation has locked away.
            local ceiling = Combat.unreservedMax(tgt.char, "health")
            local healed = math.max(0, math.min(ceiling, hp.current + (amount or 0)) - hp.current)
            entryFor(tgt).heal = entryFor(tgt).heal + healed
            return healed
        end,
        applyStatus = function(tgt, id, opts)
            if not tgt then return nil end
            local e = entryFor(tgt)
            e.statuses[#e.statuses + 1] = { id = id, def = Status.defs[id], opts = opts }
            return nil
        end,
        -- A dry run must not mutate resources; report the clamped gain without applying it, against
        -- the same ceiling Combat.restoreResource honours.
        restore = function(tgt, stat, amount)
            if not tgt or not amount or amount <= 0 then return 0 end
            local res = tgt.char.stats[stat]
            if type(res) == "table" then
                local ceiling = Combat.unreservedMax(tgt.char, stat)
                return math.max(0, math.min(ceiling, res.current + amount) - res.current)
            end
            return amount
        end,
        -- Anything that mutates the battlefield -- placing a trap or hazard, summoning a unit,
        -- shoving one, stealing an item, cutting an initiative -- is inert in a dry run. `summon`
        -- and `copy` hand back a throwaway stand-in so an effect that goes on to use the returned
        -- unit doesn't fault out of the pcall and blank the tooltip.
        placeTrap = function() return nil end,
        placeHazard = function() return nil end,
        placeWall = function() return nil end,
        dispel = function() return { revealed = 0, wallsDestroyed = 0 } end,
        summon = function() return previewStandIn() end,
        copy = function() return previewStandIn() end,
        copyOf = function() return previewStandIn() end,
        knockback = function() return 0, false end,
        pull = function() return false end,
        teleportUser = function() return false end,
        charge = function() return 0 end,
        steal = function() return nil end,
        hasten = function() return 0 end,
        -- Board-mutating helpers are inert in a dry run; the read-only ones may answer truthfully.
        random = function() return 1 end,
        cleanse = function() return 0 end,
        corpseAt = function(x, y) return Combat.corpseAt(combat, x, y) end,
        corpsesIn = function(cells)
            return Combat.corpsesIn(combat, cells or Combat.aoeCells(combat, ab, tx, ty, unit))
        end,
        reanimate = function() return false end,
        raise = function() return previewStandIn() end,
        log = function() end,
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
-- inventory-hover tooltip and the shop detail pane. Replays the real effect against a zero-defense
-- stand-in (so `damage` is the pre-armor Power + attack stat) and captures the `fx.power`-derived
-- heal and status too, so it stays correct for AoE / multi-hit / heal / buff abilities alike.
-- `unit` may be nil (a shop with no unit selected, an Armory hover with no acting member): it falls
-- back to a zero-stat stand-in caster, so `out.damage` is exactly the item's raw Power -- which is
-- what the "Power" row quotes regardless. Returns { damage, heal, statuses = { { id, def, opts } },
-- multi } (multi flags an AoE ability, whose number is per target) or nil for an item with no
-- active-ability effect. The effect is pcall-guarded so a data-file quirk can never crash the caller.
function Combat.abilityOutput(unit, item)
    local ab = item and item.activeAbility
    if not ab or not ab.effect then return nil end
    unit = unit or previewStandIn()
    local dummy = dummyTarget()
    local out = { damage = 0, heal = 0, statuses = {}, multi = ab.aoe ~= nil }
    local fx = {
        user = unit, target = dummy, item = item, combat = nil, tx = 0, ty = 0,
        power = ab.power,
        unitAt = function() return nil end,
        unitsNear = function() return { dummy } end,
        -- There is no board here, so hand back the cell itself: an effect that goes on to place
        -- something there must not bail before it has told us what it would have placed.
        openTileNear = function(x, y) return x, y end,
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
        adjacentItems = function() return {} end,
        adjacentMatching = function() return 0 end,
        placeTrap = function() return nil end,
        placeHazard = function() return nil end,
        placeWall = function() return nil end,
        dispel = function() return { revealed = 0, wallsDestroyed = 0 } end,
        -- Record WHAT the ability summons -- and for how long -- so the inventory tooltip can name it
        -- and quote its duration, without building anything; the stand-in keeps a chained effect from
        -- faulting out of the pcall.
        summon = function(charId, _, _, opts)
            out.summon = charId
            out.summonDuration = opts and opts.duration
            return previewStandIn()
        end,
        copy = function(_, _, opts)
            out.summon = "copy"
            out.summonDuration = opts and opts.duration
            return previewStandIn()
        end,
        -- The tooltip has no board and therefore no target to name, so it says what the ability does
        -- rather than whose shape it would take.
        copyOf = function(_, _, _, opts)
            out.summon = "copy of the target"
            out.summonDuration = opts and opts.duration
            return previewStandIn()
        end,
        knockback = function(_, distance) out.knockback = distance or 1; return 0, false end,
        pull = function() out.pull = true; return false end,
        teleportUser = function() return false end,
        charge = function(_, distance) out.charge = distance or 1; return 0 end,
        steal = function() out.steal = true; return nil end,
        hasten = function() return 0 end,
        -- No board here, so the corpse/reanimation helpers report nothing; `raise` records what it
        -- would call so the inventory tooltip can name it, like `summon` does.
        random = function() return 1 end,
        cleanse = function() return 0 end,
        corpseAt = function() return nil end,
        corpsesIn = function() return {} end,
        reanimate = function() return false end,
        raise = function(_, charId, opts)
            out.summon = charId
            out.summonDuration = opts and opts.duration
            return previewStandIn()
        end,
        log = function() end,
    }
    pcall(ab.effect, fx)
    return out
end

-- Living units a unit may target with `item`'s ability, by range + target kind.
function Combat.abilityTargets(combat, unit, item)
    local ab = item.activeAbility
    if not ab then return {} end
    local out = {}
    local range = Combat.abilityRange(combat, unit, ab) + Combat.adjacencyRangeBonus(unit.char, item)
    local minRange = Combat.abilityMinRange(ab)
    for _, other in ipairs(combat.units) do
        local d = manhattan(unit.x, unit.y, other.x, other.y)
        if other.alive and d <= range and d >= minRange then
            local valid = false
            -- An untargetable foe (Invisible) can't be picked; a friendly cast ignores the status,
            -- so an ally can still heal or buff someone the enemy has lost sight of.
            if ab.target == "enemy" then valid = other.side ~= unit.side and not Status.untargetable(other)
            elseif ab.target == "ally" then valid = other.side == unit.side -- includes self
            elseif ab.target == "self" then valid = other == unit
            -- An occupiable AoE (e.g. Rain of Arrows) aims at a cell, so it can be centred right on
            -- a foe -- surface those foes as targets so the enemy AI plans the volley like a strike.
            -- A point placement (a trap: tile-target but no aoe/allowOccupied) stays unplannable here.
            elseif ab.target == "tile" and ab.aoe and ab.allowOccupied then
                valid = other.side ~= unit.side and not Status.untargetable(other) end
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

-- Overchannel: a mage that casts through its own life when the mana runs dry (the trait of the same
-- name). A capability read, not a dispatched hook -- there is no "onSpend" trait event, so the cost
-- path consults this directly (documented as the one trait that works this way).
function Combat.canOverchannel(unit)
    return Trait.has(unit, "overchannel")
end

-- Pay an ability's `cost` for `unit`. Normally a plain spend; but an Overchannel unit short on mana
-- drains what mana it has and pays the shortfall out of health (1 HP per missing point). The single
-- spend path useItem / strikeTrap / strikeWall all route through, so casting-in-blood is uniform.
function Combat.spendCost(combat, unit, cost)
    if not cost then return end
    local char = unit.char
    if cost.stat == "mana" and Combat.canOverchannel(unit) then
        local have = resourceValue(char, "mana")
        if have < cost.amount then
            local shortfall = cost.amount - have
            spendResource(char, "mana", have) -- drain the pool to 0
            spendResource(char, "health", shortfall) -- pay the rest in blood
            Combat.logEvent(combat, "status",
                string.format("%s overchannels, burning %d health.", unitName(unit), shortfall))
            return
        end
    end
    spendResource(char, cost.stat, cost.amount)
end

-- ---------------------------------------------------------------------------
-- Blink (teleport movement)
--
-- A `moveBehavior` item (ability_blink) doesn't cast: it toggles the unit's `blinkArmed` flag, and
-- while that is set AND the unit can pay one jump, the unit MOVES by teleport this turn instead of
-- walking. A blink ignores terrain cost and intervening obstacles, reaches its own (wider) range,
-- costs a resource per jump rather than move initiative, and -- like a walk -- spends the turn's one
-- move without ending the turn. A blink it can't afford falls back to an ordinary walk.
-- ---------------------------------------------------------------------------

-- The unit's teleport item (a `moveBehavior` of mode "teleport") in its grid, or nil.
function Combat.blinkItem(char)
    for _, item in ipairs(Character.eachItem(char)) do
        local mb = item.moveBehavior
        if mb and mb.mode == "teleport" then return item end
    end
    return nil
end

-- The active blink for `unit` this turn -- its moveBehavior and the item -- or nil for a normal walk.
-- Present only when the unit has toggled blink on AND can pay one jump's cost. The single gate the
-- move overlay, the click handler, and Combat.blink all read, so teleport is offered exactly when it
-- can be taken (and a blink you can't afford silently becomes a walk).
function Combat.blinkReady(unit)
    if not unit.blinkArmed then return nil end
    local item = Combat.blinkItem(unit.char)
    if not item then return nil end
    local mb = item.moveBehavior
    if mb.cost and resourceValue(unit.char, mb.cost.stat) < mb.cost.amount then return nil end
    return mb, item
end

-- Tiles a unit may blink to this turn: every walkable, unoccupied, wall-free tile within the blink's
-- `movement` (Manhattan), ignoring terrain move cost and intervening obstacles -- a teleport does not
-- walk, so nothing bars the line, only the destination itself. Returns reachable's shape
-- ({ [key] = { x, y, cost, steps } }) so the battle overlay and click handling treat it identically;
-- cost is 0 (a blink charges no move initiative) and steps a nominal 1.
function Combat.teleportCells(combat, unit, range)
    range = range or 0
    local out = {}
    local cols = (combat.arena and combat.arena.cols) or 0
    local rows = (combat.arena and combat.arena.rows) or 0
    for dx = -range, range do
        for dy = -range, range do
            if not (dx == 0 and dy == 0) and (math.abs(dx) + math.abs(dy)) <= range then
                local x, y = unit.x + dx, unit.y + dy
                if x >= 1 and x <= cols and y >= 1 and y <= rows then
                    local cell = combat.arena.tiles[y][x]
                    if cell.walkable and not Combat.unitAt(combat, x, y)
                        and not Wall.blocksAt(combat, x, y) then
                        out[key(x, y)] = { x = x, y = y, cost = 0, steps = 1 }
                    end
                end
            end
        end
    end
    return out
end

-- Teleport `unit` to (x, y): spend the blink cost, jump straight there (no path, no move cost), and
-- trigger the destination tile (a trap or hazard on it still bites a unit that blinks onto it). Marks
-- the turn's one move as spent WITHOUT ending the turn -- the unit may still act or wait. Charges no
-- move initiative; the resource cost is the whole price. Returns true, or false + a reason.
function Combat.blink(combat, unit, x, y)
    if not unit.alive then return false, "dead" end
    if not combat.turn or combat.turn.unit ~= unit then return false, "not this unit's turn" end
    if combat.turn.moved then return false, "already moved" end
    local mb = Combat.blinkReady(unit)
    if not mb then return false, "cannot blink" end
    local row = combat.arena and combat.arena.tiles and combat.arena.tiles[y]
    local cell = row and row[x]
    if not (cell and cell.walkable) then return false, "blocked tile" end
    if Combat.unitAt(combat, x, y) or Wall.blocksAt(combat, x, y) then return false, "occupied tile" end
    if manhattan(unit.x, unit.y, x, y) > (mb.movement or 0) then return false, "out of range" end

    if mb.cost then spendResource(unit.char, mb.cost.stat, mb.cost.amount) end
    combat.turn.moved = true
    combat.turn.moveCost = 0 -- a blink owes no move initiative; its resource cost is the price
    unit.x, unit.y = x, y
    Combat.logEvent(combat, "move", string.format("%s blinks to (%d, %d).", unitName(unit), x, y))
    Combat.enterTile(combat, unit, x, y)
    return true
end

-- ---------------------------------------------------------------------------
-- Resource reservation
--
-- An ability may RESERVE part of a resource for as long as it stays active (a summon lives).
-- A reservation is BOTH a price and a lock: the amount is spent out of `current` on the spot (so
-- the caster must actually hold it to cast), and the resource's CEILING drops by the same amount,
-- so what was spent cannot be regenerated back until the reservation is released.
--
-- The ceiling is `max` less everything reserved; `max` itself is never touched, so
-- percentage-of-maximum modifiers (a future "regenerate 1% of maximum life") are unaffected.
-- Reserved health is therefore not a buffer: it is simply life you no longer have.
--
-- Reservations live on the CHARACTER (`char.reservations`), beside the {max,current} pools they
-- constrain, so the char-based resource helpers below need no unit. Each entry is
-- { stat, amount, holder } where `holder` is the unit whose existence sustains it (the summon);
-- when that unit dies the reservation is released (Combat.releaseHeldBy, called from the death
-- path). Party characters persist between battles, so Combat.new clears them at setup.
-- ---------------------------------------------------------------------------

-- Total currently reserved from `stat` on `char`.
function Combat.reservedAmount(char, stat)
    local total = 0
    for _, r in ipairs(char.reservations or {}) do
        if r.stat == stat then total = total + r.amount end
    end
    return total
end

-- The ceiling `stat`'s `current` may reach: its max less everything reserved from it. `max`
-- itself is never modified. A plain-number (non-pool) stat has no ceiling, so it reads as its
-- own value. The single source of truth for "how full can this pool get" -- restoreResource and
-- applyHeal both clamp here rather than at `res.max`.
function Combat.unreservedMax(char, stat)
    local res = char.stats[stat]
    local max = (type(res) == "table") and res.max or (res or 0)
    -- A carried resource-passive (Toughness/Endurance/Attunement) raises the ceiling without touching
    -- the base `max`. `char.maxBonus` is rebuilt from the grid every setup (applyUnitPassives), so it
    -- never compounds; it is nil outside a battle, where these items have no effect anyway.
    max = max + ((char.maxBonus and char.maxBonus[stat]) or 0)
    return math.max(0, max - Combat.reservedAmount(char, stat))
end

-- Can `amount` of `stat` be set aside out of a pool currently holding `current`? The reservation is
-- spent on the spot, so you must actually hold the resource to commit it (no summoning on an empty
-- pool), and reserving health can never be lethal. Takes the amount rather than the character so
-- costBlock can ask about the pool as it will stand *after* the ability's cost is paid.
local function canReserveFrom(current, stat, amount)
    if stat == "health" then return current > amount end
    return current >= amount
end

-- Can `char` set `amount` of `stat` aside right now?
function Combat.canReserve(char, stat, amount)
    return canReserveFrom(resourceValue(char, stat), stat, amount)
end

-- Reserve `amount` of `stat` on `char` for as long as `holder` (a unit) lives. Spends the amount out
-- of `current` and drops the pool's ceiling by it, so the resource is gone and stays gone until the
-- holder falls. Returns the reservation entry.
function Combat.reserve(char, stat, amount, holder)
    char.reservations = char.reservations or {}
    local entry = { stat = stat, amount = amount, holder = holder }
    char.reservations[#char.reservations + 1] = entry
    spendResource(char, stat, amount)
    local res = char.stats[stat]
    if type(res) == "table" then
        res.current = math.max(0, math.min(res.current, Combat.unreservedMax(char, stat)))
    end
    return entry
end

-- Release every reservation sustained by `holder`, across every character on the field. Called
-- from the death path when a summon (or the caster that spawned it) falls. The freed ceiling
-- does NOT refund `current` -- the resource was spent to commit, and comes back the usual way.
function Combat.releaseHeldBy(combat, holder)
    for _, u in ipairs(combat.units) do
        local list = u.char.reservations
        if list then
            for i = #list, 1, -1 do
                if list[i].holder == holder then table.remove(list, i) end
            end
        end
    end
end

-- The reservation an ability would take: `ab.reserve = { stat, percent }` commits a share of the
-- pool's MAXIMUM (not its current), so the commitment is the same whether the caster is full or
-- nearly spent. Returns nil for an ability that reserves nothing.
function Combat.abilityReserve(unit, ab)
    local r = ab and ab.reserve
    if not r then return nil end
    local res = unit.char.stats[r.stat]
    local max = (type(res) == "table") and res.max or (res or 0)
    return { stat = r.stat, amount = math.floor(max * (r.percent or 0)) }
end

-- Current value of a resource stat on `char` (a {max,current} table reads `current`; a plain
-- number reads itself; missing reads 0). Public so the UI can show "have N" without duplicating
-- the {max,current}-vs-number handling.
function Combat.resource(char, stat)
    return resourceValue(char, stat)
end

-- Restore a resource stat toward its ceiling -- the inverse of spendResource. A {max,current}
-- table clamps at Combat.unreservedMax (its max less anything reserved from it, so a reservation
-- caps recovery too); a plain-number stat just adds. Returns the amount actually restored (0 if it
-- was already full or `amount` is non-positive). Shared by stamina regen, Focus, and on-hit mana gain.
function Combat.restoreResource(char, stat, amount)
    if not amount or amount <= 0 then return 0 end
    local res = char.stats[stat]
    if type(res) == "table" then
        local before = res.current
        res.current = math.min(Combat.unreservedMax(char, stat), res.current + amount)
        return math.max(0, res.current - before)
    end
    char.stats[stat] = (res or 0) + amount
    return amount
end

-- What ability `ab` actually costs `unit` right now: its declared cost scaled by the unit's status
-- cost multiplier (Haste halves it). Returns nil for a free ability. The single source of truth --
-- useItem, strikeTrap, the AI, the affordability gray-out and the tooltip all price a cast here, so
-- a cost-modifying status can never be visible in one place and missing in another. A RESERVATION
-- (ab.reserve) is not a cost and is deliberately not scaled: see Combat.abilityReserve.
function Combat.abilityCost(unit, ab)
    if not ab or not ab.cost then return nil end
    local mult = Status.costMultiplier(unit)
    return { stat = ab.cost.stat, amount = math.floor(ab.cost.amount * mult + 0.5) }
end

-- Everything a cast takes out of `unit`'s own pools, in the order Combat.useItem takes it: the
-- ability's resource cost (Haste-scaled) and then the reservation it locks away for as long as its
-- summon lives. Both come out of `current` on the spot, so summing them per stat gives the pool
-- change a hovered cast would make. Empty for an ability that takes nothing.
--   { { kind = "cost"|"reserve", stat = "mana", amount = 12 }, ... }
-- The single source of truth for the spend the board hover previews: the action-preview panel's
-- rows and the actor's turn-strip bars both read this, so a reservation can't be priced in one
-- place and missing from the other.
function Combat.abilitySpend(unit, ab)
    local out = {}
    local cost = Combat.abilityCost(unit, ab)
    if cost then out[#out + 1] = { kind = "cost", stat = cost.stat, amount = cost.amount } end
    local reserve = Combat.abilityReserve(unit, ab)
    if reserve then out[#out + 1] = { kind = "reserve", stat = reserve.stat, amount = reserve.amount } end
    return out
end

-- The reason `unit` can't pay for `ab` -- a cost it can't spend or a reservation it can't commit --
-- as an itemBlockReason entry, or nil when it can. Shared by Combat.canAfford (which only wants the
-- yes/no) and Combat.itemBlockReason (which wants to say which pool fell short, and by how much).
local function costBlock(unit, ab)
    local cost = Combat.abilityCost(unit, ab)
    if cost and resourceValue(unit.char, cost.stat) < cost.amount then
        -- An Overchannel mage isn't blocked for low mana: it pays the shortfall in health, so long as
        -- it has the blood to spare (never a lethal self-cost). Only then does the low pool gate it.
        local paidInBlood = false
        if cost.stat == "mana" and Combat.canOverchannel(unit) then
            local shortfall = cost.amount - resourceValue(unit.char, "mana")
            if resourceValue(unit.char, "health") > shortfall then paidInBlood = true end
        end
        if not paidInBlood then
            return { kind = "cost", stat = cost.stat, reason = "insufficient " .. cost.stat,
                text = string.format("Not enough %s (have %d)", cost.stat,
                    math.floor(resourceValue(unit.char, cost.stat))) }
        end
    end
    -- A reservation is spent like a cost and then locked away, so the caster must hold it now (and
    -- reserving health can never be lethal). Combat.useItem pays the cost before the effect takes
    -- the reservation, so when both draw the same pool the reservation only gets what the cost left.
    local res = Combat.abilityReserve(unit, ab)
    if res then
        local available = resourceValue(unit.char, res.stat)
        if cost and cost.stat == res.stat then available = available - cost.amount end
        if not canReserveFrom(available, res.stat, res.amount) then
            return { kind = "reserve", stat = res.stat, reason = "insufficient " .. res.stat,
                text = string.format("Not enough %s to reserve %d (have %d)", res.stat, res.amount,
                    math.floor(available)) }
        end
    end
    return nil
end

-- Can `unit` currently pay ability `ab`'s resource cost (and set aside its reservation)? True when
-- the ability demands neither. Prefer Combat.itemBlockReason for a whole item: affordability is
-- only one of the conditions that gate a cast.
function Combat.canAfford(unit, ab)
    return costBlock(unit, ab) == nil
end

-- Is this a consuming item whose stack is spent (quantity 0)? A depleted consumable KEEPS its
-- inventory slot but can't be activated until it's restocked (Character.addItem merges a new
-- stack back into the empty slot). The shared gate for the grayed-out "out of stock" slot,
-- mirrored inside Combat.useItem so a keyboard/gamepad use can't fire on an empty stack either.
function Combat.isDepleted(item)
    local ab = item and item.activeAbility
    return ab ~= nil and ab.consumesItem and (item.quantity or 1) <= 0
end

-- The creature this item summoned and is still sustaining, or nil once it falls. An item holds ONE
-- summon at a time: `fx.summon` / `fx.copy` stamp what they spawned onto the item (below), and the
-- unit's own `alive` flag retires the claim -- a summon that dies, and a summon dismissed with its
-- summoner, both clear it without anyone having to remember to. That makes a summon ability
-- self-limiting: it cannot be recast while what it called still stands (Combat.itemBlockReason).
--
-- Party items outlive their battle, so a summon still standing at the final blow would keep its
-- claim forever; Combat.new wipes the field's claims at setup, beside the reservations.
function Combat.activeSummon(item)
    local held = item and item.activeSummon
    if held and held.alive then return held end
    return nil
end

-- Why can't `unit` activate `item` right now? Covers every condition known BEFORE a target is
-- picked: a spent stack, a summon of this item's still on the field, a cost or reservation it can't
-- pay, an unmet grid adjacency (Rain of Arrows without its bow). Returns nil when the item is
-- activatable -- and for a passive item, which is inert rather than blocked. A nil `unit` checks
-- only the item-intrinsic conditions, so a tooltip with no actor still reports an empty stack.
--
-- The single source of truth for the grayed-out slot, the refused arm (mouse / key / gamepad), the
-- tooltip's red note and the AI's item filter -- so a condition can never gate the cast in
-- Combat.useItem while the UI still advertises the item as ready. Returns:
--   { kind   = "depleted" | "active" | "cost" | "reserve" | "adjacency",
--     stat   = the resource at fault (cost / reserve only),
--     summon = the creature still standing (active only),
--     reason = terse, what useItem reports to its caller,
--     text   = a sentence for the player }
function Combat.itemBlockReason(unit, item)
    local ab = item and item.activeAbility
    if not ab then return nil end
    if Combat.isDepleted(item) then
        return { kind = "depleted", reason = "out of stock", text = "Out of stock -- restock to use" }
    end
    -- One summon per summoner: while the wolf lives, the horn that called it stays silent. Checked
    -- before affordability so a caster whose mana is locked away by the very reservation sustaining
    -- its wolf is told about the wolf, not about the mana. A timed summon says how long the wait is.
    local held = Combat.activeSummon(item)
    if held then
        local text = (held.char.name or "Its summon") .. " is still on the field"
        if held.summonRemaining then
            text = text .. string.format(" (%d left)", math.max(0, math.ceil(held.summonRemaining)))
        end
        return { kind = "active", summon = held, reason = "summon still active", text = text }
    end
    if not unit then return nil end

    -- Silenced: a mana cost can't be paid, so a mana ability is refused (one drawing on stamina or
    -- health still fires). Checked before affordability so the note reads "silenced", not "no mana".
    if ab.cost and ab.cost.stat == "mana" and Status.silenced(unit) then
        return { kind = "silenced", reason = "silenced", text = "Silenced -- cannot cast mana abilities" }
    end

    -- Disarmed: crafted weapons are struck from the hand. A weapon -- the basic attack included, since
    -- it routes through here as the default weapon's ability -- is refused while this lasts; the bare
    -- `unarmed` fallback is exempt (a disarmed unit can still throw a punch), as are abilities and
    -- potions. Disarm takes the blade, not the satchel, and never the fists -- so it can't become a
    -- strictly-better Stun. Mirrors the silenced gate above.
    if item.type == "weapon" and not hasTag(item.tags, "unarmed") and Status.disarmed(unit) then
        return { kind = "disarmed", reason = "disarmed", text = "Disarmed -- cannot use weapons" }
    end

    local cost = costBlock(unit, ab)
    if cost then return cost end
    if not Combat.adjacencyMet(unit.char, item) then
        local label = Combat.adjacencyLabel(ab.requiresAdjacent)
        return { kind = "adjacency", reason = "requires " .. label,
            text = "Requires an " .. label .. " in the item grid" }
    end
    return nil
end

-- Lift one item from `victim`'s grid into `thief`'s. Items the blueprint marks `noSteal` (a
-- beast's fangs) can't be taken. Among the rest, the highest `stealPriority` wins -- that's how a
-- Decoy makes itself the obvious thing to grab -- and ties are broken at random.
--
-- The item goes into the thief's own grid; if that grid is full, a party thief pockets it into the
-- player's stash (combat.stash, wired to player.stash by the battle state -- unbounded), while an
-- enemy thief with nowhere to put it simply destroys it. Returns the stolen item, or nil if the
-- victim carried nothing worth taking.
function Combat.steal(combat, thief, victim)
    local best, pool = nil, {}
    for i = 1, Character.MAX_INVENTORY do
        local item = victim.char.inventory[i]
        if item and not item.noSteal then
            local priority = item.stealPriority or 0
            if not best or priority > best then best, pool = priority, { item }
            elseif priority == best then pool[#pool + 1] = item end
        end
    end
    if #pool == 0 then
        Combat.logEvent(combat, "action",
            string.format("%s finds nothing to steal from %s.", unitName(thief), unitName(victim)))
        return nil
    end

    local item = pool[Combat.random(#pool)]
    Character.removeItem(victim.char, item)
    Combat.logEvent(combat, "action", string.format("%s steals %s from %s.",
        unitName(thief), item.name or "an item", unitName(victim)))

    if not Character.addItem(thief.char, item) then
        if thief.side == "party" and combat.stash then
            combat.stash[#combat.stash + 1] = item
            Combat.logEvent(combat, "system",
                string.format("%s goes to the stash.", item.name or "The item"))
        else
            Combat.logEvent(combat, "system",
                string.format("%s is lost.", item.name or "The item"))
        end
    end
    return item
end

-- Perform an item action: validate range + target kind + resource cost, spend the cost,
-- run the ability's effect(fx), push the actor back by the ability speed, and consume the
-- item if it's a consumable. Returns (true, result) or (false, reason). `result` is
-- { damageDealt, healed } aggregated across the effect's helper calls.
function Combat.useItem(combat, unit, item, tx, ty)
    if not unit.alive then return false, "dead" end
    local ab = item.activeAbility
    if not ab then return false, "no ability" end
    -- Everything that gates the cast regardless of where it's aimed (spent stack, cost/reservation,
    -- grid adjacency) -- the same check the grayed-out slot and the refused arm run.
    local blocked = Combat.itemBlockReason(unit, item)
    if blocked then return false, blocked.reason end

    local dist = manhattan(unit.x, unit.y, tx, ty)
    if dist > Combat.abilityRange(combat, unit, ab) + Combat.adjacencyRangeBonus(unit.char, item) then
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

    -- Affordability was settled by itemBlockReason above (nothing has been spent since), so the
    -- cast is committed from here: pay the cost. The reservation isn't taken until the effect
    -- produces the summon that holds it (below).
    local cost = Combat.abilityCost(unit, ab)
    if cost then Combat.spendCost(combat, unit, cost) end
    local reserve = Combat.abilityReserve(unit, ab)

    -- Effect context: bound helpers let a data-file effect compose damage/heal/AoE
    -- without touching this module. Results are accumulated for the caller/UI.
    -- Adjacency auras from neighboring items (e.g. a Fire Stone next to this weapon) fold extra
    -- tags into every hit and inflict their status on any target this cast damages.
    local auraTags, auraStatuses, auraMods = adjacencyAura(unit.char, item)
    -- The cast's effective Power: the ability's own, raised by a neighboring Alchemic Mastery charm
    -- (auraMods.power, 0 without one). A Power-less effect (a pure summon or cleanse) stays nil, so
    -- the bonus never conjures damage out of nothing. Threaded into fx.power (for effects that read it
    -- directly, e.g. a heal) AND into fx.damage's default opts.power below -- Combat.dealDamage bases
    -- its hit on opts.power/ab.power, not on fx.power, so a damage bomb needs it fed in there too.
    local effectivePower = ab.power and (ab.power + auraMods.power) or ab.power
    local result = { damageDealt = 0, healed = 0 }
    local fx = {
        user = unit, target = target, item = item, combat = combat,
        tx = tx, ty = ty, -- the targeted cell, for tile-targeted abilities (e.g. placing a trap)
        power = effectivePower, -- effects derive heal/status/restore magnitude from it
        unitAt = function(x, y) return Combat.unitAt(combat, x, y) end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
        -- A free tile beside (x, y) to set something down on, or nil when the spot is hemmed in.
        -- Read-only, so the dry run may answer it truthfully.
        openTileNear = function(x, y) return Combat.openTileNear(combat, x, y) end,
        aoeUnits = function() return Combat.aoeUnits(combat, ab, tx, ty, unit) end,
        -- The cells this ability's AoE footprint covers (reads `ab.aoe`); an effect iterates them to
        -- paint the ground -- e.g. Fireball dropping a fire hazard on every blasted tile.
        aoeCells = function() return Combat.aoeCells(combat, ab, tx, ty, unit) end,
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
            -- Default the hit's Power to the cast's effective Power (which folds in the Alchemic
            -- Mastery bonus); an effect that passes its own `opts.power` still overrides. Normally
            -- effectivePower == ab.power, so this is a no-op for every cast with no charm beside it.
            opts = opts or {}
            if opts.power == nil then opts.power = effectivePower end
            local d = Combat.dealDamage(combat, unit, tgt, item, withAuraTags(opts, auraTags))
            result.damageDealt = result.damageDealt + d
            if d > 0 then
                for _, st in ipairs(auraStatuses) do
                    Status.apply(combat, tgt, st.id, st.opts)
                end
                -- A neighboring Vampiric Strike charm makes this weapon drink: the caster heals a
                -- share of the damage it just dealt.
                if auraMods.lifesteal > 0 then
                    result.healed = result.healed + Combat.applyHeal(combat, unit, math.floor(d * auraMods.lifesteal))
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
        -- Raise a wall segment on a tile, owned by the caster's side (models/wall.lua). Summon Wall
        -- calls this once per tile of its 3x1 line; a tile that can't hold a wall (a unit on it,
        -- solid terrain, another wall) is silently skipped by Wall.place returning nil.
        placeWall = function(px, py, id, opts)
            opts = opts or {}
            opts.side = opts.side or unit.side
            return Wall.place(combat, px, py, id, opts)
        end,
        -- Reveal invisible units and tear down `illusion` walls across a set of cells (Dispel
        -- Illusions). Defaults to the ability's own AoE footprint around the aimed tile.
        dispel = function(cells)
            return Combat.dispel(combat, cells or Combat.aoeCells(combat, ab, tx, ty, unit))
        end,
        -- Summon a character onto the field, sustained by the caster (models/summon.lua). Whatever
        -- comes back holds two things for as long as it lives: the ability's reservation (ab.reserve),
        -- so the committed resource is freed the moment the creature falls, and the item's own
        -- `activeSummon` claim, which keeps the ability from being cast again while it stands. An
        -- effect that summons twice leaves the last one holding the claim.
        --
        -- A creature can die on the tile it is called to -- a trap under it, a fire on it -- and then
        -- there is nothing to sustain and nothing to hold: binding a reservation to a corpse would
        -- lock the caster's mana away for good, since the death that would release it has already
        -- passed. It arrives dead, the cast is spent, and the caster keeps its ceiling.
        summon = function(charId, px, py, opts)
            local summoned = Summon.spawn(combat, unit, charId, px, py, opts)
            if summoned and summoned.alive then
                item.activeSummon = summoned
                if reserve then Combat.reserve(unit.char, reserve.stat, reserve.amount, summoned) end
            end
            return summoned
        end,
        -- Summon a duplicate of the caster (doppelganger / decoy). Held the same way: one double at
        -- a time, and no second decoy while the first still stands -- and the same, too, for a double
        -- that does not survive the tile it is planted on.
        copy = function(px, py, opts)
            local copied = Summon.copy(combat, unit, px, py, opts)
            if copied and copied.alive then
                item.activeSummon = copied
                if reserve then Combat.reserve(unit.char, reserve.stat, reserve.amount, copied) end
            end
            return copied
        end,
        -- Summon a duplicate of SOMEONE ELSE, on the caster's side (the Philosopher's Stone). Held
        -- exactly like the other two: one shape at a time per item, and a shape that dies on the tile
        -- it was called to holds nothing.
        copyOf = function(tgt, px, py, opts)
            if not tgt then return nil end
            local copied = Summon.copyOf(combat, unit, tgt, px, py, opts)
            if copied and copied.alive then
                item.activeSummon = copied
                if reserve then Combat.reserve(unit.char, reserve.stat, reserve.amount, copied) end
            end
            return copied
        end,
        -- Shove a unit `distance` tiles straight away from the caster; a collision hurts everyone.
        knockback = function(tgt, distance, opts)
            if not tgt then return 0 end
            return Combat.knockback(combat, unit, tgt, distance, opts)
        end,
        -- Drag a unit to a tile adjacent to the caster (needs line of sight).
        pull = function(tgt)
            if not tgt then return false end
            return Combat.pull(combat, unit, tgt)
        end,
        -- Teleport the CASTER onto a tile, springing whatever it lands on (Leaping Crash's jump).
        teleportUser = function(x, y) return Combat.teleportUnit(combat, unit, x, y) end,
        -- Pin the target in front and drive it (and the caster behind it) `distance` tiles ahead,
        -- trampling anyone in the lane (Charge).
        charge = function(tgt, distance)
            if not tgt then return 0 end
            return Combat.charge(combat, unit, tgt, distance)
        end,
        -- Lift a random item off a unit (Combat.steal picks it; a Decoy volunteers itself).
        steal = function(tgt)
            if not tgt then return nil end
            return Combat.steal(combat, unit, tgt)
        end,
        -- Rush a unit forward in the initiative order by cutting its current initiative. Mutating
        -- initiative straight from an effect mirrors what Stun does from a status hook.
        hasten = function(tgt, fraction)
            if not tgt then return 0 end
            tgt.initiative = tgt.initiative * (1 - (fraction or 0.5))
            return tgt.initiative
        end,
        -- A random integer in 1..n, drawn from the model's indirected source (so a spec can stub it).
        -- What a scattershot ability rolls to pick its tiles (Meteor Storm), and any future dice.
        random = function(n) return Combat.random(n or 1) end,
        -- Strip every debuff from a unit (Cure). Returns the number removed.
        cleanse = function(tgt)
            if not tgt then return 0 end
            return Combat.cleanse(combat, tgt)
        end,
        -- The reachable corpse on a tile, or nil (Revive picks the body it stands over).
        corpseAt = function(x, y) return Combat.corpseAt(combat, x, y) end,
        -- Every corpse under a set of cells, defaulting to this ability's own AoE footprint (Raise Dead
        -- sweeping its blast for bodies).
        corpsesIn = function(cells)
            return Combat.corpsesIn(combat, cells or Combat.aoeCells(combat, ab, tx, ty, unit))
        end,
        -- Reanimate a corpse in place at `fraction` health (Revive). Returns true on success.
        reanimate = function(corpse, fraction) return Combat.reanimate(combat, corpse, fraction) end,
        -- Consume a corpse and raise a `charId` zombie on the caster's side where it lay (Raise Dead).
        raise = function(corpse, charId, opts) return Combat.raiseZombie(combat, unit, corpse, charId, opts) end,
        -- Write a line straight into the combat log, for an ability whose entry must not read as
        -- what it actually is (a Decoy reports a move, not a cast -- see `ab.silent`). Hands back
        -- the entry, so an effect can keep a handle on a line it may later have to correct.
        log = function(kind, text) return Combat.logEvent(combat, kind, text) end,
    }

    -- Log the action itself before its effect runs, so the cast heads the sub-events it spawns
    -- (damage / heal / status / trap lines). Offensive casts read "attacks with", the rest "uses".
    -- A `silent` ability skips this and narrates itself through fx.log, so the log can lie about
    -- what just happened (the Decoy reports a move).
    if not ab.silent then
        local verb = (ab.target == "enemy") and "attacks with" or "uses"
        Combat.logEvent(combat, "action",
            string.format("%s %s %s.", unitName(unit), verb, item.name or "an item"))
    end

    if ab.effect then ab.effect(fx) end

    -- Water quenches fire: a cast carrying the "water" tag douses any dousable hazard across its
    -- footprint (the AoE cells, or just the aimed cell). Runs after the effect so a water AoE that
    -- also lays down rain clears the fire it fell on. Uses the full cast tag set (item + ability).
    local castTags = collectTags(item, nil)
    if hasTag(castTags, "water") then
        local cells = ab.aoe and Combat.aoeCells(combat, ab, tx, ty, unit) or { { x = tx, y = ty } }
        Hazard.douse(combat, cells, castTags)
    end

    -- The cast has fully resolved (effect, then the water/fire interaction). A reaction trait sees a
    -- finished action, never a half-applied one -- and fires before the turn is charged, so a
    -- counter-cast is not billed to the initiative of the unit that provoked it.
    Trait.onCast(combat, unit, { item = item, ability = ab, tx = tx, ty = ty })

    -- Tally a class-tagged action toward the actor's growth (models/growth.lua). A weapon strike, a
    -- spell, or a thrown consumable all land here with the item's `class`. Only a real player roster
    -- member counts: `control == "player"` excludes AI escortees, and `not summoned` excludes summons
    -- (both use transient char instances that would never persist the tally anyway).
    if item.class and Combat.isPlayerControlled(unit) and not unit.summoned then
        Character.recordUse(unit.char, item.class)
    end

    -- Using an item ends the turn: advance by (this turn's move cost) + the ability speed.
    endTurn(combat, unit, ab.speed or Combat.DEFAULT_SPEED)

    -- Consume one use: decrement the stack (a bundle of consumables), floored at 0. The spent
    -- slot STAYS in the inventory as an empty stack -- Combat.isDepleted then blocks activation
    -- until it's restocked (Character.addItem merges a fresh stack back in). Non-stacked items
    -- carry quantity 1, so this leaves an empty, greyed-out slot after their single use.
    if ab.consumesItem and not auraMods.preserve then
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
    local blocked = Combat.itemBlockReason(unit, weapon)
    if blocked then return false, blocked.reason end
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
    local cost = Combat.abilityCost(unit, ab)
    if cost then Combat.spendCost(combat, unit, cost) end

    -- Damage the trap by the weapon's attack stat (magical weapons use magicDamage). Traps have
    -- no defense, so this is the raw stat, floored.
    Combat.logEvent(combat, "trap", string.format("%s strikes %s.", unitName(unit), trap.name or "a trap"))
    Trap.damage(combat, trap, Combat.computeTrapDamage(unit, weapon))

    endTurn(combat, unit, ab.speed or Combat.DEFAULT_SPEED)
    return true, { trap = trap }
end

-- Strike a wall at (x, y) with `weapon`: the wall analogue of Combat.strikeTrap, so a unit can tear
-- down a conjured barrier the hard way (Dispel clears it for free, but a party without one still has
-- an answer). Validates range + affordability, spends the cost, damages the wall by the weapon's
-- attack stat, and ends the turn. Walls are always visible, so there is no visibility gate. Returns
-- (true, { wall }) or (false, reason).
function Combat.strikeWall(combat, unit, weapon, x, y)
    if not unit.alive then return false, "dead" end
    local wall = Wall.at(combat, x, y)
    if not wall then return false, "no wall" end
    local ab = weapon and weapon.activeAbility
    if not ab then return false, "no ability" end
    local blocked = Combat.itemBlockReason(unit, weapon)
    if blocked then return false, blocked.reason end
    local dist = manhattan(unit.x, unit.y, x, y)
    if dist > Combat.abilityRange(combat, unit, ab) then return false, "out of range" end
    if dist < Combat.abilityMinRange(ab) then return false, "too close" end
    if ab.requiresSight and not Combat.hasLineOfSight(combat, unit.x, unit.y, x, y) then
        return false, "no line of sight"
    end
    local cost = Combat.abilityCost(unit, ab)
    if cost then Combat.spendCost(combat, unit, cost) end

    Combat.logEvent(combat, "trap", string.format("%s strikes %s.", unitName(unit), wall.name or "a wall"))
    Wall.damage(combat, wall, Combat.computeTrapDamage(unit, weapon))

    endTurn(combat, unit, ab.speed or Combat.DEFAULT_SPEED)
    return true, { wall = wall }
end

-- Dispel: reveal every invisible unit standing on `cells` (stripping the Invisible that hides a
-- decoy's caster) and tear down every `illusion`-tagged wall there. The heart of Dispel Illusions;
-- reached through fx.dispel. Returns { revealed, wallsDestroyed } counts.
function Combat.dispel(combat, cells)
    local revealed = 0
    for _, c in ipairs(cells or {}) do
        local u = Combat.unitAt(combat, c.x, c.y)
        if u and Status.has(u, "invisible") then
            Status.remove(u, "invisible")
            Combat.logEvent(combat, "status", string.format("%s is revealed!", unitName(u)))
            revealed = revealed + 1
        end
    end
    local wallsDestroyed = Wall.dispelIn(combat, cells)
    return { revealed = revealed, wallsDestroyed = wallsDestroyed }
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
    -- Can this unit see `other` as a foe at all? An Invisible unit is off the AI's board entirely:
    -- it isn't chased, attacked, or approached. (A decoy, however, is a perfectly ordinary foe.)
    local function isFoe(other)
        return other.alive and other.side ~= unit.side and not Status.untargetable(other)
    end

    -- Taunt overrides everything: a taunted unit must go for the taunter with its default weapon and
    -- nothing else. Strike it if it is already in reach; otherwise close to a tile that can hit it and
    -- swing; otherwise shamble toward it. The taunter is a foe (opposite side) by construction.
    local taunt = Status.get(unit, "taunt")
    if taunt and taunt.taunter and taunt.taunter.alive and taunt.taunter.side ~= unit.side then
        local tt = taunt.taunter
        local weapon = Combat.defaultWeapon(unit.char)
        if weapon then
            local ab = weapon.activeAbility
            for _, t in ipairs(Combat.abilityTargets(combat, unit, weapon)) do
                if t.x == tt.x and t.y == tt.y then
                    return { item = weapon, tx = tt.x, ty = tt.y }
                end
            end
            local minRange = Combat.abilityMinRange(ab)
            local best
            for _, node in pairs(Combat.reachable(combat, unit)) do
                local range = Combat.abilityRange(combat, unit, ab, node.x, node.y)
                    + Combat.adjacencyRangeBonus(unit.char, weapon)
                local d = manhattan(node.x, node.y, tt.x, tt.y)
                if d <= range and d >= minRange
                    and (not (ab and ab.requiresSight) or Combat.hasLineOfSight(combat, node.x, node.y, tt.x, tt.y))
                    and (not best or node.steps < best.steps) then
                    best = { x = node.x, y = node.y, steps = node.steps }
                end
            end
            if best then return { move = { x = best.x, y = best.y }, item = weapon, tx = tt.x, ty = tt.y } end
        end
        -- Out of reach even after moving: step as close to the taunter as the turn allows.
        local dest
        for _, node in pairs(Combat.reachable(combat, unit)) do
            local d = manhattan(node.x, node.y, tt.x, tt.y)
            if not dest or d < dest.dist or (d == dest.dist and node.steps < dest.steps) then
                dest = { x = node.x, y = node.y, dist = d, steps = node.steps }
            end
        end
        if dest and dest.dist < manhattan(unit.x, unit.y, tt.x, tt.y) then
            return { move = { x = dest.x, y = dest.y } }
        end
        return { wait = true }
    end

    -- Nearest living party unit (the foe we path toward / attack).
    local target, bestDist
    for _, u in ipairs(combat.units) do
        if isFoe(u) then
            local d = manhattan(unit.x, unit.y, u.x, u.y)
            if not bestDist or d < bestDist then target, bestDist = u, d end
        end
    end
    if not target then return { wait = true } end

    -- Only consider abilities the unit can actually activate right now -- affordable, in stock, and
    -- with any adjacency requirement met (else the plan would waste the turn on an item useItem
    -- rejects).
    local items = {}
    for _, item in ipairs(Combat.abilityItems(unit.char)) do
        if not Combat.itemBlockReason(unit, item) then
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
    -- hazard-free tile, so this reduces to the old steps/dist ordering when nothing is burning; it is
    -- scored from `unit.side` so a sanctuary the party consecrated holds no draw for the enemy.
    local reachable = Combat.reachable(combat, unit)
    local best
    for _, node in pairs(reachable) do
        local nodeBias = Hazard.tileBias(combat, node.x, node.y, unit.side)
        for _, item in ipairs(items) do
            local ab = item.activeAbility
            local range = Combat.abilityRange(combat, unit, ab, node.x, node.y)
                + Combat.adjacencyRangeBonus(unit.char, item)
            local minRange = Combat.abilityMinRange(ab)
            for _, p in ipairs(combat.units) do
                if isFoe(p)
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
    -- the friendlier hazard footing -- so a wounded unit steps onto its own sanctuary and away from
    -- fire -- then fewer steps. Only move if it strictly closes the gap, to avoid pacing in place.
    local dest
    for _, node in pairs(reachable) do
        local d = manhattan(node.x, node.y, target.x, target.y)
        local nodeBias = Hazard.tileBias(combat, node.x, node.y, unit.side)
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

-- Is the character a `protect` objective names still standing on the party's side? A
-- summoned duplicate shares its origin's `char.id`, so it would otherwise stand in for the
-- charge it is impersonating -- only the real one keeps the escort alive (the same rule
-- Combat.evaluate's assassinate branch applies to its mark).
function Combat.isProtectedAlive(combat, charId)
    for _, u in ipairs(combat.units) do
        if u.alive and u.side == "party" and u.char.id == charId and not u.summoned then
            return true
        end
    end
    return false
end

-- Resolve the arena objective to "win" / "loss" / nil. A total party wipe is always a
-- loss. Called after each action so the battle state can fire onWin/onLoss.
--
-- `obj.protect` is a *composable* loss condition, not a win type: it names a party-side
-- character (usually an escorted ally, see Arena.build's `spec.allies`) whose death fails
-- the battle whatever the win type is. That is what expresses an escort -- "survive 8
-- turns, and the caravan must live" -- without exit tiles or pathing.
function Combat.evaluate(combat)
    if Combat.aliveCount(combat, "party") == 0 then return "loss" end

    local obj = combat.objective or { type = "killAll" }

    if obj.protect and not Combat.isProtectedAlive(combat, obj.protect) then
        return "loss"
    end

    if obj.type == "assassinate" then
        for _, u in ipairs(combat.units) do
            -- A summoned duplicate shares its origin's `char.id`, so it would otherwise read as the
            -- mark still standing. Only the real thing counts.
            if u.alive and u.side == "enemy" and u.char.id == obj.target and not u.summoned then
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
