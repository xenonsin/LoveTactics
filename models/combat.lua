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
local Transform = require("models.transform")
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

-- Structured animation-cue feed, distinct from the text log above. Where logEvent produces a line
-- of prose for the combat-log panel, this records a small plain-data event (unit references +
-- numbers) that the view layer turns into a damage floater, an HP-bar drain, a shake/flash, or a
-- death fade. Kept headless-safe (no love.graphics, no requires): the model appends here and the
-- battle state drains it after each action; a headless test never drains, so the tail just sits
-- unused. Preview/compute paths (Combat.computeDamage) never reach the mutation sites that push
-- here, so a hovered-action preview raises no cues.
function Combat.pushFx(combat, event)
    if not combat then return end
    local fx = combat.fx
    if not fx then fx = {}; combat.fx = fx end
    -- Which beat of the exchange raised this cue (see Combat.beginBeat): 0 for the action itself,
    -- 1 for what answered it, 2 for the answer to that. The view plays each beat in turn rather than
    -- all at once, so a counter reads as a reply and not as part of the blow that provoked it.
    event.beat = combat._fxBeat or 0
    fx[#fx + 1] = event
    -- A headless run (a test, an AI rollout) never drains, so bound the tail like the log does.
    if #fx > Combat.LOG_CAP then table.remove(fx, 1) end
    return event
end

-- Open a reaction beat: every cue raised until the matching endBeat is stamped one step later than
-- the blow that provoked it (see pushFx). The model still resolves the whole exchange in one
-- uninterrupted pass -- this only tells the view what answered what, so it can play a counter after
-- the attack rather than over it. Nested, because a counter can itself be countered.
function Combat.beginBeat(combat)
    if combat then combat._fxBeat = (combat._fxBeat or 0) + 1 end
end

function Combat.endBeat(combat)
    if combat then combat._fxBeat = math.max(0, (combat._fxBeat or 1) - 1) end
end

-- Hand the accumulated fx events to the caller and clear the feed. Returns nil when nothing has
-- happened since the last drain, so the battle state can cheaply tell an eventful action from a
-- move-only/wait turn (which then needs no reaction pause).
function Combat.drainFx(combat)
    local fx = combat.fx
    if not fx or #fx == 0 then return nil end
    combat.fx = {}
    return fx
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

-- Summed `sightCost` of the tiles one traced line crosses, EXCLUDING the two endpoints -- so a
-- unit always sees its own tile and its target's even on cover. Off-map cells count as
-- transparent (they can't sit between two in-bounds tiles anyway).
local function sightCostAlong(combat, tiles, x0, y0, x1, y1)
    local total = 0
    traceLine(x0, y0, x1, y1, function(x, y)
        if (x == x0 and y == y0) or (x == x1 and y == y1) then return end
        local row = tiles[y]
        local cell = row and row[x]
        total = total + ((cell and cell.sightCost) or 0) + Wall.sightCostAt(combat, x, y)
    end)
    return total
end

-- Is there a clear line of sight between (x0,y0) and (x1,y1)? True when either endpoint can trace
-- a line to the other whose summed sightCost stays below Combat.SIGHT_BLOCK.
--
-- BOTH directions are traced because one is not a mirror of the other. Bresenham breaks its
-- half-step tie (e2 == -dy) toward stepping y first, so a line hugs its STARTING column for that
-- first step -- and a trace begun at the other endpoint can therefore cross a different set of
-- tiles. Taking the cheaper of the two makes sight depend only on the pair of cells, which buys
-- two properties the callers rely on: A->B and B->A always agree (the threat highlight and
-- overwatch need that reciprocity), and two stand tiles mirrored about a blocker agree too --
-- a lone mountain no longer shadows one diagonal while leaving its mirror open.
--
-- The permissive choice (cheaper line, not stricter) matches traceLine's corner-threading: a
-- single 1-tile blocker never seals a line. Ability targeting (Combat.useItem / abilityTargets),
-- the threat-reach highlight, and the enemy AI all gate ranged (`ab.requiresSight`) actions here.
function Combat.hasLineOfSight(combat, x0, y0, x1, y1)
    if x0 == x1 and y0 == y1 then return true end
    local tiles = combat.arena and combat.arena.tiles
    if not tiles then return true end
    if sightCostAlong(combat, tiles, x0, y0, x1, y1) < Combat.SIGHT_BLOCK then return true end
    return sightCostAlong(combat, tiles, x1, y1, x0, y0) < Combat.SIGHT_BLOCK
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

-- The unit's OFFENSIVE default weapon: the first inventory item of `type == "weapon"` that
-- carries an ability, in inventory (row-major grid) order -- so a lower slot wins. Falls back
-- to the character's hidden unarmed weapon (models/character.lua attaches `char.unarmed`) when
-- it carries no weapon. This is the "what do you threaten" attack an enemy's danger zone,
-- overwatch, and counters read -- always a strike, never a heal, and never the player's pinned
-- default action (see Combat.defaultAction). May be nil only for a hand-built char with neither.
function Combat.defaultWeapon(char)
    for _, item in ipairs(Character.eachItem(char)) do
        if item.type == "weapon" and item.activeAbility then return item end
    end
    return char.unarmed
end

-- The character's player-chosen DEFAULT ACTION: the ability used by the click-to-use basic action
-- and the effective-range band shown on its turn. Unlike defaultWeapon this can be ANY ability item
-- (a spell, a heal, a consumable), pinned in the Loadout screen via `char.defaultActionSlot`.
-- Selection: the pinned slot (only while it still holds an ability item -- a stale pin silently
-- falls back), else the first inventory weapon with an ability, else the first ability item of any
-- kind, else the hidden unarmed weapon. So a fighter defaults to its sword and a mage with no weapon
-- to its attack spell, until the player pins something else.
function Combat.defaultAction(char)
    local slot = char.defaultActionSlot
    if slot then
        local item = char.inventory[slot]
        if item and item.activeAbility then return item end
    end
    for _, item in ipairs(Character.eachItem(char)) do
        if item.type == "weapon" and item.activeAbility then return item end
    end
    for _, item in ipairs(Character.eachItem(char)) do
        if item.activeAbility then return item end
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

-- Public read of the fold above, for a model that needs an effective stat but has no business
-- reaching into this one's internals -- models/status.lua's resist rating, which reads magicDefense /
-- defense / statusResist off a unit exactly as mitigation does. Mirrors Combat.moveBudget: the same
-- single fold (base + item bonuses + status modifiers), exposed rather than duplicated, so a ward
-- granted by armor and a ward granted by a buff can never be counted differently.
function Combat.flatStat(unit, name)
    return flatStat(unit, name)
end

-- Extra damage a strike gets when it is thrown with the wielder's bare fists: the aggregated
-- `unarmedBonus.damage` from passive "fist" items carried in the grid (Iron Fist), plus
-- `unarmedBonus.drunkDamage` while the unit is Drunk (Drunken Fist). 0 for any crafted weapon --
-- an identity check against the hidden unarmed instance keeps the bonus off real blades. The
-- companion range/extra-hit halves live in Combat.abilityRange and data/items/weapon/unarmed.lua.
local function unarmedDamageBonus(user, item)
    if not (user and item and item == user.char.unarmed) then return 0 end
    local ub = user.unarmedBonus
    if not ub then return 0 end
    local bonus = ub.damage or 0
    if ub.drunkDamage and Status.has(user, "drunk") then bonus = bonus + ub.drunkDamage end
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
    local range = base + (Combat.fieldBonus(combat, x or unit.x, y or unit.y).range or 0)
    -- A range-cutting debuff (Blind) shortens the reach, but never below 1: a blinded unit is groping
    -- in the dark, not disarmed, so it can still strike an adjacent foe.
    if unit then range = range - Status.rangeMalus(unit) end
    return math.max(1, range)
end

-- Minimum range of ability `ab`: a fixed "dead zone" a target must be at least this far away to be
-- hit (a bow can't fire point-blank). Defaults to 0 (no restriction). Unlike Combat.abilityRange
-- this gets NO tile field bonus -- a vantage point extends max reach, it doesn't shrink the dead zone.
function Combat.abilityMinRange(ab)
    return (ab and ab.minRange) or 0
end

-- The initiative `item`'s action will bill at end of turn -- normally the ability's own `speed`, but an
-- ability may compute it live through `speedPreview(unit, item)` (Dual Wield: the summed speed of the
-- weapons it will swing). The single reader for the timeline ghost, so the previewed slot matches what
-- endTurn actually charges (which the effect sets via fx.setSpeed to the same number).
function Combat.actionSpeed(unit, ab, item)
    if not ab then return Combat.DEFAULT_SPEED end
    if ab.speedPreview then return ab.speedPreview(unit, item) end
    return ab.speed or Combat.DEFAULT_SPEED
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
    unit.unarmedBonus = { damage = 0, range = 0, hits = 0, drunkDamage = 0 }
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

-- Re-fold ONE unit's passives, for a unit whose grid changed after setup. The grid is fixed for the
-- duration of a battle for everyone who walked into it -- so the only caller is models/transform.lua,
-- where the body itself is exchanged and the "grid" changes wholesale because the character did. A
-- bear carries a bear's hide, not the hunter's chainmail, and `unit.bonus` has to be told.
function Combat.refreshPassives(unit)
    applyUnitPassives(unit)
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
                Combat.releaseClaims(unit.char)
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

-- Is `item`'s reflex still recharging on `unit`, and how far along? A cooldown is keyed on the
-- trait's id and the trait remembers the item that granted it (Trait.instantiate), so this walks the
-- bearer's traits back to the slot they came from -- the read the item grid needs to say "this blade
-- cannot parry again yet". The longest remaining wins when one item grants several reflexes: the slot
-- is ready only once all of them are. Returns nil for a ready item, else:
--   { remaining = ticks left, total = the full cooldown, trait = the reflex that is recharging }
-- `total` is floored at `remaining`, so a def whose magnitude was raised mid-battle can't report a
-- fraction above 1.
function Combat.itemCooldown(unit, item)
    if not unit or not item or not unit.traits then return nil end
    local best
    for _, t in ipairs(unit.traits) do
        if t.item == item then
            local left = unit.cooldowns and unit.cooldowns[t.id]
            if left and left > 0 and (not best or left > best.remaining) then
                best = { remaining = left, total = math.max(t.def.magnitude or left, left), trait = t }
            end
        end
    end
    return best
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

-- Does `unit` cross traps unharmed? True when it carries any item tagged "ignore traps" (Feather
-- Boots). Mirrors the "detect traps" inventory scan in models/trap.lua: a passive keyed off an item
-- sitting in the 3x3 grid, never an equip slot. Read by Combat.enterTile to skip the trap trigger.
local IGNORE_TRAPS_TAG = "ignore traps"
function Combat.ignoresTraps(unit)
    if not (unit and unit.char) then return false end
    for _, item in ipairs(Character.eachItem(unit.char)) do
        if hasTag(item.tags, IGNORE_TRAPS_TAG) then return true end
    end
    return false
end

-- Leave behind whatever ground `unit`'s kit paints on a tile it crosses (Pilgrim's Sandals hallow
-- every print they make). A `trail = { hazard, duration }` on any item in the 3x3 grid -- the same
-- inventory scan as Combat.ignoresTraps above -- drops that hazard on the tile, sided with the wearer
-- so an ally-only zone can never serve the foe walking through it. Called from Combat.enterTile on a
-- ground crossing only: footprints are pressed by feet, so a blink or a swap leaves none.
function Combat.layTrail(combat, unit)
    if not (unit and unit.char) then return end
    for _, item in ipairs(Character.eachItem(unit.char)) do
        local trail = item.trail
        if trail and trail.hazard then
            Hazard.place(combat, unit.x, unit.y, trail.hazard, { side = unit.side, duration = trail.duration })
        end
    end
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

-- The live turn order plus arbitrary GHOST entries, sorted into one strip. `ghosts` is a list of
-- { unit, initiative, label } specs -- each a hypothetical future slot for its own unit (an aim
-- preview projects the actor; an in-progress channel projects the caster's follow-up turn). Returns
-- a list of { unit, preview, initiative, previewLabel } entries in turn order (soonest first).
-- Ordering matches Combat.turnOrder's tie-breaks so the strip agrees with the board's turn numbers;
-- a preview ghost sorts AFTER real entries at an exact tie, so the live card stays lower in a
-- bottom-anchored strip. Every branch is guarded so comparing an entry with itself returns false (a
-- valid weak order -- an unguarded `return not a.preview` here would assert x < x and corrupt sort);
-- two ghosts of the same unit only ever tie if their slots coincide, and then rank equal (fine).
function Combat.buildTimeline(combat, ghosts)
    local entries = {}
    for _, u in ipairs(combat.units) do
        if u.alive then entries[#entries + 1] = { unit = u, preview = false, initiative = u.initiative } end
    end
    for _, g in ipairs(ghosts or {}) do
        entries[#entries + 1] = { unit = g.unit, preview = true, initiative = g.initiative, previewLabel = g.label }
    end
    table.sort(entries, function(a, b)
        if a.initiative ~= b.initiative then return a.initiative < b.initiative end
        if a.preview ~= b.preview then return b.preview end -- real before ghost at a tie
        if a.unit.speed ~= b.unit.speed then return a.unit.speed > b.unit.speed end
        if a.unit.side ~= b.unit.side then return SIDE_RANK[a.unit.side] < SIDE_RANK[b.unit.side] end
        return a.unit.index < b.unit.index
    end)
    return entries
end

-- Like the live turn order, but with extra GHOST copies of `unit` inserted where it would
-- land if it acted. The actor keeps its real slot AND gains a preview slot, so the UI can show
-- "you are here now / you would move to here". `ghosts` is either a single initiative number
-- (one unlabelled ghost) or a list of { initiative, label } specs -- a channeled ability passes
-- two, the slot the spell RESOLVES at and the slot the caster next acts at past it. A thin wrapper
-- over Combat.buildTimeline that stamps `unit` onto each ghost spec.
function Combat.previewTimeline(combat, unit, ghosts)
    if type(ghosts) == "number" then ghosts = { { initiative = ghosts } } end
    local specs = {}
    for _, g in ipairs(ghosts) do
        specs[#specs + 1] = { unit = unit, initiative = g.initiative, label = g.label }
    end
    return Combat.buildTimeline(combat, specs)
end

-- Ghost timeline specs for every unit currently WINDING UP a channel: one per channeler, at the
-- slot it will next act -- its current initiative (the resolution slot, where its real card already
-- sits) plus the channeled cast's own speed AND the move cost the cast deferred past the resolution
-- (both of which Combat.resolveChannel's endTurn charges when the wind-up finishes). Labelled
-- "then acts here" so the two-slot picture the aim preview showed --
-- where the spell resolves, then where the caster regains control -- persists once the cast is
-- committed. The unit resolving THIS beat (initiative 0) is skipped: its follow-up is a hair away
-- and it's the framed current card, so a ghost there is just noise.
function Combat.channelGhosts(combat)
    local specs = {}
    for _, u in ipairs(combat.units) do
        local ch = u.alive and u.channel
        if ch and u.initiative > 0 then
            specs[#specs + 1] = {
                unit = u,
                initiative = u.initiative + Combat.actionSpeed(u, ch.ab, ch.item) + Combat.moveDebt(u),
                label = "then acts here",
            }
        end
    end
    return specs
end

function Combat.currentUnit(combat)
    return Combat.turnOrder(combat)[1]
end

-- Open the current unit's turn: a fresh { unit, moved, moveCost } record the move/action
-- calls read and end. `startX`/`startY` pin the tile the unit stood on as the turn opened, so an
-- effect that must return there (Shadow Strike blinking back after its hit) has a fixed anchor even
-- after the unit has moved. Returns the unit whose turn it is (nil if none are left alive).
function Combat.startTurn(combat)
    local unit = Combat.currentUnit(combat)
    combat.turn = unit and { unit = unit, moved = false, moveCost = 0, startX = unit.x, startY = unit.y } or nil
    -- An Overwatch stance is a one-turn watch: it lapses the moment its holder comes back around to
    -- act, so the unit chooses anew each turn whether to hold the line again.
    if unit then unit.overwatch = nil end
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

-- The ground the active unit covered this turn, in initiative. Shared by every turn-ending path so
-- they price a walk identically.
local function turnMoveCost(combat, unit)
    local moveCost = (combat.turn and combat.turn.unit == unit and combat.turn.moveCost) or 0
    -- A status may charge a move cost even if the unit stayed put (root: as if it moved max).
    return math.max(moveCost, Status.forcedMoveCost(combat, unit))
end

-- End the active unit's turn: set its initiative to (moveCost spent this turn) + the action
-- cost, then rebase so the next unit drops to 0. Shared by useItem and passing.
--
-- `defer` (the channel branch alone) banks this turn's move cost as a DEBT on the unit instead of
-- charging it, so the turn costs the wind-up and nothing else -- see Combat.moveDebt. Any later
-- endTurn settles the debt on top of its own costs, so the ground is paid for exactly once whether
-- the channel resolves or is interrupted.
local function endTurn(combat, unit, actionCost, defer)
    local moveCost = turnMoveCost(combat, unit)
    if defer then
        unit.moveDebt = (unit.moveDebt or 0) + moveCost
        moveCost = 0
    else
        moveCost = moveCost + (unit.moveDebt or 0)
        unit.moveDebt = nil
    end
    Status.onTurnEnd(combat, unit)
    unit.initiative = unit.initiative + moveCost + actionCost
    combat.turnCount = combat.turnCount + 1
    combat.turn = nil
    Combat.rebase(combat)
end

-- The move cost a unit has banked but not yet paid: the ground it covered on the turn it began a
-- channel, deferred past the resolution (see endTurn). 0 for everyone else. The single reader for the
-- timeline's follow-up ghost, so the projected slot matches what the resolving endTurn will charge.
function Combat.moveDebt(unit)
    return unit.moveDebt or 0
end

-- Wait (delay): the acting unit sits at initiative 0, so end the turn by setting its
-- initiative to (next unit's initiative + 1) -- act one tick after them -- but never below the
-- move cost it spent this turn, so a move is still paid. Rebasing then drops the next unit to
-- 0 and the waiter lands just behind it. Falls back to moveCost + WAIT_COST when no other unit
-- is alive. The player's deliberate "delay my turn" action.
function Combat.wait(combat, unit)
    if not unit.alive then return false, "dead" end
    -- A debt banked by an interrupted channel is ground already covered, so it is owed here too: it
    -- rides with the move cost through the floor below, and a wait can never dodge it.
    local moveCost = turnMoveCost(combat, unit) + (unit.moveDebt or 0)
    unit.moveDebt = nil
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
    -- The shield tunes the brace size through waitBehavior.defense (already resolved to this shield's
    -- upgrade level); it rides in as the Defending status's magnitude. nil falls back to the status
    -- def's own magnitude, so a defend item that names no amount still braces.
    Status.apply(combat, unit, "defending", { magnitude = behavior.defense })
    Combat.logEvent(combat, "defend", string.format("%s takes a defensive stance.", unitName(unit)))
    -- A tower shield covers the line, not just the man holding it: `waitBehavior.covers` braces every
    -- ADJACENT ALLY too, for that (smaller) amount. Only the largest shields declare it -- see
    -- data/items/armor/oathkeeper_shield.lua -- and it is what makes bracing a formation decision
    -- rather than a private one: where you stand when you plant decides who else gets the wall.
    if behavior.covers then
        for _, ally in ipairs(Combat.unitsNear(combat, unit.x, unit.y, 1)) do
            if ally ~= unit and ally.side == unit.side then
                Status.apply(combat, ally, "defending", { magnitude = behavior.covers })
                Combat.logEvent(combat, "defend",
                    string.format("%s is covered by the wall.", unitName(ally)))
            end
        end
    end
    endTurn(combat, unit, behavior.speed or Combat.DEFEND_SPEED)
    return true
end

-- Overwatch: end the turn without attacking, entering a watchful stance instead. While it holds, an
-- enemy that WALKS into the bearer's weapon range is shot automatically (Combat.triggerOverwatch, fired
-- from Combat.stepMove) -- each shot spending `staminaPerShot` of the bearer's stamina but none of the
-- timeline, and it keeps firing on each step through range until that stamina runs dry. Setting the
-- stance costs behavior.speed (deliberately steep -- a whole turn spent watching, no move-and-shoot).
-- The stance lapses when the bearer's own next turn opens (Combat.startTurn). The wait swap granted by
-- a sentry item (data/items/utility/overwatch_scope.lua).
function Combat.overwatch(combat, unit)
    if not unit.alive then return false, "dead" end
    local behavior = Combat.waitBehavior(unit)
    unit.overwatch = { staminaPerShot = behavior.stamina or 0 }
    Combat.logEvent(combat, "action", string.format("%s takes overwatch.", unitName(unit)))
    endTurn(combat, unit, behavior.speed or Combat.FOCUS_SPEED)
    return true
end

-- The initiative the unit's "Wait" action would land it at right now, for the timeline ghost.
-- Mirrors whichever of wait/focus/defend/overwatch its waitBehavior selects (and their speed
-- costs) so the preview matches the action that actually runs -- a Focus/Defend/Overwatch swap
-- charges behavior.speed, not the plain delay slot. The unit's committed move (combat.turn.moveCost)
-- is folded in the same way each real action folds it. `moveCostOverride` (a move-initiative value)
-- previews a wait AFTER a not-yet-committed move -- the reposition ghost, before the walk is taken.
function Combat.waitInitiative(combat, unit, moveCostOverride)
    local moveCost = moveCostOverride
        or (combat.turn and combat.turn.unit == unit and combat.turn.moveCost) or 0
    moveCost = math.max(moveCost, Status.forcedMoveCost(combat, unit))
    local behavior = Combat.waitBehavior(unit)
    if behavior.kind == "delay" then
        local nxt = nextUnit(combat, unit)
        return nxt and math.max(moveCost, nxt.initiative + 1) or (moveCost + Combat.WAIT_COST)
    end
    local default = (behavior.kind == "defend" and Combat.DEFEND_SPEED) or Combat.FOCUS_SPEED
    return unit.initiative + moveCost + (behavior.speed or default)
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

-- The full movement graph for a unit this turn: a Dijkstra over the arena weighted by tile
-- `moveCost`, budget = the unit's `movement`. Impassable terrain, walls, and ENEMY-occupied cells
-- bar the way outright; a FRIENDLY unit's cell may be walked THROUGH but not stopped on -- it is
-- expanded like any tile (so allies never wall a corridor) yet carries `occupied = true` so callers
-- can drop it as a landing spot. Returns `{ [key]= { x, y, cost, steps, fromKey, occupied } }`,
-- keyed "x,y", INCLUDING the origin (cost 0) so a path can be traced back through it. Private: the
-- public Combat.reachable filters this down to the tiles a unit may actually stop on.
-- Does `unit` carry something that lifts it off the ground (the `flying` tag -- the Zephyr Striders)?
-- A flier ignores the ground entirely: every tile costs 1 to enter whatever it is made of, and terrain
-- that is merely UNWALKABLE (a river, a chasm, a bog) is crossed as if it were open field. Mirrors
-- Combat.ignoresTraps in shape -- a grid scan for a tag, at the one chokepoint that reads it.
--
-- Deliberately does NOT open a wall, a solid rock face, or an occupied tile: those bar the way by
-- being IN it, not by being poor footing, and a thing that could end its turn inside a wall would
-- break far more than it fixed. The rule is "the ground stops mattering", not "nothing stops you".
function Combat.isFlying(unit)
    if not (unit and unit.char) then return false end
    for _, item in ipairs(Character.eachItem(unit.char)) do
        if hasTag(item.tags, "flying") then return true end
    end
    return false
end

local function moveGraph(combat, unit)
    local arena = combat.arena
    local budget = flatStat(unit, "movement")
    local flying = Combat.isFlying(unit)

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
                    local occ = Combat.unitAt(combat, nx, ny)
                    -- An enemy bars the tile outright; a friendly unit may be passed through (transit
                    -- only). Walls and impassable terrain always bar the way.
                    local enemy = occ ~= nil and occ.side ~= unit.side
                    -- A flier crosses any ground (walkable or not) and is never slowed by it; everyone
                    -- else pays what the terrain asks and stops at what it can't walk on. Walls and
                    -- enemies bar the way for both -- they are obstacles, not footing.
                    local passable = flying or cell.walkable
                    if passable and not enemy and not Wall.blocksAt(combat, nx, ny) then
                        local ncost = cur.cost + (flying and 1 or cell.moveCost)
                        if ncost <= budget then
                            local nk = key(nx, ny)
                            local existing = best[nk]
                            if not existing or ncost < existing.cost then
                                local node = { x = nx, y = ny, cost = ncost, steps = cur.steps + 1,
                                               fromKey = key(cur.x, cur.y), occupied = occ ~= nil }
                                best[nk] = node
                                frontier[#frontier + 1] = node
                            end
                        end
                    end
                end
            end
        end
    end

    return best
end

-- Tiles a unit can reach AND STOP ON this turn: the movement graph (moveGraph) minus the origin and
-- minus any friendly-occupied tile it merely walks through. Returns `{ [key]= { x, y, cost, steps } }`,
-- keyed by "x,y". `cost` is the terrain-weighted path cost: it spends the movement budget AND is the
-- initiative the move costs at end-of-turn (so rough terrain is slower to cross in both reach and
-- time). `steps` is the raw tile count, used only by the enemy AI's pathing.
function Combat.reachable(combat, unit)
    local graph = moveGraph(combat, unit)
    graph[key(unit.x, unit.y)] = nil -- the origin isn't a "move" target
    local out = {}
    for k, node in pairs(graph) do
        -- An ally's tile is a walk-through, never a stopping point: keep it out of the reachable set.
        if not node.occupied then out[k] = node end
    end
    return out
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
-- `reason` says HOW the unit came to be here, for the effects that care about the difference:
--   "walk"   -- it stepped here itself, one metered tile of its move (Combat.stepMove)
--   "forced" -- it was shoved, pulled, or trampled here (knockback / pull / charge)
--   nil      -- it did not cross the ground at all: a blink, a swap, or a summon's arrival
-- Traps, hazards, and auras deliberately ignore `reason` -- the ground does not care how you came to
-- stand on it. Only the two effects of CROSSING it read `reason`, and both take "walk" or "forced"
-- alike: Status.onEnterTile, so that Bleed costs a unit blood for every tile it crosses under its own
-- weight (walked OR dragged) but nothing for a blink, and Combat.layTrail, so a trail is pressed by
-- feet on the ground and never by a blink or a swap. `reason` is optional and
-- defaults to nil (no ground crossing), so a call site that forgets it errs toward firing nothing.
--
-- The unit must already stand on (x, y) when this is called: a trap may kill it, and the death path
-- reads its position. Callers move it first, then announce the arrival.
function Combat.enterTile(combat, unit, x, y, reason)
    local trap = Trap.at(combat, x, y)
    -- Feather Boots walk over any trap unharmed. The guard sits at this one chokepoint, so the wearer
    -- is spared whether it strode onto the trap, was shoved onto it, or was conjured on top of one --
    -- but hazards (a spreading fire, quicksand) still bite: the boots dodge blades, not the ground.
    if trap and not Combat.ignoresTraps(unit) then Trap.trigger(combat, trap, unit) end
    -- Ground the unit's own kit paints under it (Pilgrim's Sandals). Laid BEFORE the hazard/aura pass
    -- below, so a trail granting an aura status is already under the unit's feet when Combat.updateAuras
    -- decides what to keep -- otherwise the wearer's own blessing would be stripped on the very tile
    -- that just granted it. Placing fires the fresh hazard's onEnter for the occupant, and the
    -- Hazard.onEnter pass below reaches it a second time: a refresh, which neither stacks nor logs.
    if unit.alive and (reason == "walk" or reason == "forced") then Combat.layTrail(combat, unit) end
    if unit.alive then
        Hazard.onEnter(combat, unit, x, y)
        Combat.updateAuras(combat, unit)
    end
    -- Last, and re-checking `alive`: a trap or hazard may already have killed the unit on this very
    -- tile, and a corpse does not bleed.
    if unit.alive and (reason == "walk" or reason == "forced") then
        Status.onEnterTile(combat, unit)
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
    -- Trace through the full graph (allies are walk-through transit nodes), not the filtered
    -- reachable set, so a path may route past a friendly unit -- but the destination itself must be
    -- a tile the unit can stop on (the origin has no fromKey; an ally's tile is `occupied`).
    local graph = moveGraph(combat, unit)
    local node = graph[key(x, y)]
    if not node or not node.fromKey then return nil, "unreachable" end
    if node.occupied then return nil, "occupied" end

    -- Walk the fromKey chain back from the destination -- it stops at the origin (which has no
    -- fromKey) -- then reverse it and put the origin on the front, so `path` reads in the order the
    -- unit's feet take it.
    local back = {}
    local n = node
    while n and n.fromKey do
        back[#back + 1] = n
        n = graph[n.fromKey]
    end
    local path = { { x = unit.x, y = unit.y } }
    for i = #back, 1, -1 do path[#path + 1] = { x = back[i].x, y = back[i].y } end

    return { unit = unit, path = path, cost = node.cost }
end

-- Validate an EXPLICIT, caller-supplied route for `unit` this turn: the same legality gate as
-- planMove, but the path is given (a player-steered walk that may deliberately wander -- Advance
-- Wars style -- rather than the shortest-path tree's pick) instead of derived. The UI's route is
-- never trusted blind: `cells` (an origin-first list of { x, y }) must start on the unit, step one
-- tile at a time, never double back over itself, and cross only legal walk tiles, with the summed
-- terrain cost staying inside the movement budget -- so a hand-built detour costs exactly what it
-- would if the unit walked it. Returns { unit, path, cost } or nil + a reason.
function Combat.planMoveVia(combat, unit, cells)
    if not unit.alive then return nil, "dead" end
    if not combat.turn or combat.turn.unit ~= unit then return nil, "not this unit's turn" end
    if combat.turn.moved then return nil, "already moved" end
    if Status.blocksMove(unit) then return nil, "rooted" end
    if not cells or #cells < 2 then return nil, "no path" end
    if cells[1].x ~= unit.x or cells[1].y ~= unit.y then return nil, "not from origin" end

    local arena = combat.arena
    local budget = flatStat(unit, "movement")
    -- The same exemption moveGraph grants a flier, for the same reason: this is an independent
    -- re-derivation of the identical legality question (a steered route rather than a derived one),
    -- so the two must answer it the same way or a flier's own move band would refuse its own route.
    local flying = Combat.isFlying(unit)
    local seen = { [key(unit.x, unit.y)] = true }
    local cost = 0
    for i = 2, #cells do
        local c, p = cells[i], cells[i - 1]
        if math.abs(c.x - p.x) + math.abs(c.y - p.y) ~= 1 then return nil, "not contiguous" end
        if c.x < 1 or c.x > arena.cols or c.y < 1 or c.y > arena.rows then return nil, "off grid" end
        local tile = arena.tiles[c.y][c.x]
        if not (flying or tile.walkable) then return nil, "blocked" end
        local k = key(c.x, c.y)
        if seen[k] then return nil, "revisit" end -- catch a double-back (incl. onto the origin) first
        local occ = Combat.unitAt(combat, c.x, c.y)
        if occ and occ ~= unit then
            -- The mover may pass THROUGH a friendly unit but must not stop on one (the destination is
            -- the last cell); an enemy bars the way outright, transit or not.
            if i == #cells or occ.side ~= unit.side then return nil, "occupied" end
        end
        if Wall.blocksAt(combat, c.x, c.y) then return nil, "wall" end
        seen[k] = true
        cost = cost + (flying and 1 or tile.moveCost)
        if cost > budget then return nil, "too far" end
    end

    local path = {}
    for i = 1, #cells do path[i] = { x = cells[i].x, y = cells[i].y } end
    return { unit = unit, path = path, cost = cost }
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
    Combat.enterTile(combat, walk.unit, tile.x, tile.y, "walk")
    -- A unit walking into an opposing Overwatch stance's firing line is shot for it. Only a walk
    -- triggers this (not a knockback or a summon appearing), so it lives here rather than in enterTile.
    Combat.triggerOverwatch(combat, walk.unit)
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
-- Push ability override it with their own damage (opts.amount).
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
    Combat.enterTile(combat, unit, nx, ny, "forced")
    -- Being knocked off your feet shatters a channel you were winding up. Idempotent, so a
    -- multi-tile slide (knockback/pull/charge all route here) only fizzles the channel once.
    if unit.channel then Combat.interruptChannel(combat, unit, "knocked off balance") end
    return true
end

-- Knock `target` up to `distance` tiles directly away from `source`. The direction is fixed at the
-- start (a straight line, however far it travels). A shove barred by the map edge, impassable
-- terrain, or another unit stops there and hurts EVERYONE involved -- the target and, if there was
-- one, whatever it slammed into. Returns (tilesMoved, collided).
function Combat.knockback(combat, source, target, distance, opts)
    opts = opts or {}
    if not (target and target.alive) then return 0, false end
    local amount = opts.amount or Combat.COLLISION_DAMAGE
    local dx, dy = signDominant(target.x - source.x, target.y - source.y)
    if dx == 0 and dy == 0 then return 0, false end

    local moved = 0
    for _ = 1, (distance or 1) do
        local ok, blocker = canShoveInto(combat, target.x + dx, target.y + dy)
        if not ok then
            Combat.logEvent(combat, "damage",
                string.format("%s slams into %s.", unitName(target),
                    blocker and unitName(blocker) or "an obstacle"))
            Combat.dealFlatDamage(combat, target, amount, { "physical", "impact" }, "the impact")
            if blocker and blocker.alive then
                Combat.dealFlatDamage(combat, blocker, amount, { "physical", "impact" }, "the impact")
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
    -- No `reason`: a leap crosses no ground, so it springs the tile it lands on but never fires a
    -- per-tile status. Bleeding out of a melee costs blood; blinking out of one does not.
    Combat.enterTile(combat, unit, x, y)
    -- Teleport sets x,y directly rather than through shoveStep, so break a channel here too.
    if unit.channel then Combat.interruptChannel(combat, unit, "displaced") end
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
        -- Both are "forced": neither crossing is a metered walk. The target is driven backwards, and
        -- the charger is carried along by its own rush rather than spending movement -- but both are
        -- on the ground the whole way, so both pay a bleed for every tile of it.
        Combat.enterTile(combat, target, fx_, fy_, "forced")
        if user.alive then
            user.x, user.y = oldTx, oldTy
            Combat.enterTile(combat, user, oldTx, oldTy, "forced")
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

-- Does an aura block `a` (declared on a neighbor item) apply to the cast `item`? The item's type must
-- be listed in `a.appliesTo`, it must carry EVERY tag in `a.requiresTags`, and none of `a.exceptTags`.
--
-- `requiresTags` narrows an aura to a SCHOOL rather than to a type -- what a relic that sharpens
-- magic and nothing else needs (the Resonance Prism: "adjacent magical things", which is a property of
-- the tags, since a spell and an enchanted blade are different types and the same school). The two tag
-- filters are opposites and both are needed: `exceptTags` carves an exception out of a broad aura,
-- `requiresTags` states a narrow one positively.
function Combat.auraApplies(a, item)
    if not (a and item) then return false end
    local ok = false
    for _, t in ipairs(a.appliesTo or {}) do
        if t == item.type then ok = true break end
    end
    if not ok then return false end
    -- Read across the item's tags AND its ability's, so a neighbour aura sees a cast the same way
    -- Combat.dealDamage's collectTags does -- an ability that declares `magical` on the ability
    -- rather than on the item is still magic, and a school aura must not miss it on a technicality.
    for _, t in ipairs(a.requiresTags or {}) do
        local ab = item.activeAbility
        local onAbility = ab ~= nil and ab.tags ~= nil and hasTag(ab.tags, t)
        if not (hasTag(item.tags, t) or onAbility) then return false end
    end
    for _, t in ipairs(a.exceptTags or {}) do
        if hasTag(item.tags, t) then return false end
    end
    return true
end

-- Aggregate the adjacency auras affecting a cast of `item` from `char`'s grid: the extra tags to
-- fold into the attack, the statuses to inflict on a damaged target, and the numeric modifiers a
-- neighboring charm grants the cast. Returns (tags, statuses, mods) where mods is
-- { amount, range, preserve }: `amount`/`range` add to the ability's magnitude and reach (an Alchemic
-- Mastery / Long-Fuse Reagent charm buffing an adjacent bomb), and `preserve` spares a consumable's
-- stack when it is used (an Everflask). All three are additive across every applicable neighbor.
local function adjacencyAura(char, item)
    local tags, statuses = {}, {}
    local mods = { amount = 0, range = 0, preserve = false, lifesteal = 0 }
    local idx = char and Character.slotIndex(char, item)
    if idx then
        for _, nb in ipairs(Character.adjacentItems(char, idx)) do
            if nb.aura and Combat.auraApplies(nb.aura, item) then
                for _, t in ipairs(nb.aura.grantTags or {}) do tags[#tags + 1] = t end
                if nb.aura.status then statuses[#statuses + 1] = nb.aura.status end
                mods.amount = mods.amount + (nb.aura.amountBonus or 0)
                mods.range = mods.range + (nb.aura.rangeBonus or 0)
                mods.lifesteal = mods.lifesteal + (nb.aura.lifesteal or 0) -- Vampiric Strike: heal a share of damage
                if nb.aura.preserve then mods.preserve = true end
            end
        end
    end
    -- LIFESTEAL, the keyword (see docs/weapons.md): an ability may declare `lifesteal` itself and heal
    -- its user for that share of what it deals, with no charm beside it -- a weapon that drinks on its
    -- own. Folded into the same `mods.lifesteal` the Vampiric Strike aura feeds, so the two simply ADD
    -- (charm a hungry weapon and it drinks deeper), and every reader -- the live cast AND the damage
    -- preview -- honours a declared lifesteal for free rather than each having to learn the keyword.
    local ab = item and item.activeAbility
    if ab and ab.lifesteal then mods.lifesteal = mods.lifesteal + ab.lifesteal end
    return tags, statuses, mods
end

-- The magnitude a cast of `ab` at (tx, ty) actually lands with: its declared amount (nil for an
-- amount-less effect -- a pure summon or cleanse -- so a bonus can never conjure damage out of
-- nothing), raised by a neighbouring charm's `amount` aura, then by FRENZY.
--
-- FRENZY, the keyword (see docs/weapons.md): `ab.frenzy` is a fraction, and every body the cast's area
-- catches BEYOND THE FIRST adds that share of the magnitude to what each of them takes. A swing into
-- one foe is ordinary; a swing into three lands harder on all three. It is the inversion that makes a
-- crowd something a weapon WANTS -- being surrounded stops being the danger and becomes the point.
--
-- It counts bodies, not enemies: an area has never cared whose side it sweeps, and neither does this.
-- An ally caught in the arc feeds it exactly as a foe would.
--
-- One funnel for all three cast paths (the preview, Combat.strikeWith, and resolveCast), so the number
-- the tooltip promises is the number the swing delivers. `combat` may be absent in a board-less
-- preview, where there is nothing to count and frenzy folds to nothing.
local function castAmount(combat, unit, ab, tx, ty, auraMods)
    local declared = Combat.abilityMagnitude(ab)
    if not declared then return nil end
    local amount = declared + auraMods.amount
    if ab.frenzy and combat then
        local caught = #Combat.aoeUnits(combat, ab, tx, ty, unit)
        if caught > 1 then
            amount = amount + math.floor(amount * ab.frenzy) * (caught - 1)
        end
    end
    return amount
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

-- Would `item` have its adjacency requirement satisfied if it sat in cell `index` of `char`'s grid?
-- Hypothetical: `index` need not be where the item currently is, which is what lets the loadout light
-- the cells a held item COULD be dropped into (Combat.adjacencyCandidateCells). The item is ignored
-- as its own neighbor, so a grid it's already in answers the same as one it isn't.
function Combat.adjacencyMetAt(char, item, index)
    local ab = item and item.activeAbility
    local req = ab and ab.requiresAdjacent
    if not req then return true end
    if not (char and index) then return false end
    for _, i in ipairs(Character.adjacentIndices(index)) do
        local nb = char.inventory[i]
        if nb ~= nil and nb ~= item and Combat.matchesAdjacency(nb, req) then return true end
    end
    return false
end

-- Is `item`'s adjacency requirement satisfied where it sits in `char`'s grid right now? True when the
-- ability declares no `requiresAdjacent`, or when at least one adjacent item matches it. The gate the
-- cast, the arm and the grayed slot all read.
function Combat.adjacencyMet(char, item)
    local ab = item and item.activeAbility
    if not (ab and ab.requiresAdjacent) then return true end
    local idx = char and Character.slotIndex(char, item)
    if not idx then return false end
    return Combat.adjacencyMetAt(char, item, idx)
end

-- Every cell of `char`'s grid where `item` would meet its adjacency requirement, as a set keyed by
-- cell index. Empty when the item has no requirement (nothing to point at -- every cell is equally
-- fine, so the loadout highlights none of them rather than all nine). What the loadout paints green
-- while an item is held: a Rain of Arrows lights only the cells that touch a bow.
function Combat.adjacencyCandidateCells(char, item)
    local out = {}
    local ab = item and item.activeAbility
    if not (char and ab and ab.requiresAdjacent) then return out end
    for i = 1, Character.MAX_INVENTORY do
        if Combat.adjacencyMetAt(char, item, i) then out[i] = true end
    end
    return out
end

-- The active adjacency relationships in `char`'s grid, for UI connector lines. Returns a list of
-- { from, to, kind } where from/to are 1-based cell indices and `kind` is one of:
--   "aura"        -- the item at `from` has an aura that applies to the item at `to`,
--   "boost"       -- the ability at `from` scales off / draws on the item at `to`,
--   "requirement" -- the ability at `from`'s requiresAdjacent is met by the item at `to`.
-- An ability may pin the EXACT neighbors its boost draws on with `adjacencyUses(char, item)`, returning
-- the item instances it will actually use (Dual Wield: only the weapons it will swing, capped by level).
-- When present, that explicit set wins over the broad `adjacencyScaling` predicate, so the lines never
-- promise a weapon the cast won't touch.
function Combat.adjacencyLinks(char)
    local links = {}
    for i = 1, Character.MAX_INVENTORY do
        local item = char.inventory[i]
        if item then
            local ab = item.activeAbility
            local usesSet
            if ab and ab.adjacencyUses then
                usesSet = {}
                for _, it in ipairs(ab.adjacencyUses(char, item)) do usesSet[it] = true end
            end
            for _, j in ipairs(Character.adjacentIndices(i)) do
                local nb = char.inventory[j]
                if nb then
                    if item.aura and Combat.auraApplies(item.aura, nb) then
                        links[#links + 1] = { from = i, to = j, kind = "aura" }
                    end
                    if usesSet then
                        if usesSet[nb] then links[#links + 1] = { from = i, to = j, kind = "boost" } end
                    elseif ab and ab.adjacencyScaling and Combat.matchesAdjacency(nb, ab.adjacencyScaling) then
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
        Status.remove(combat, caster, "invisible")
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
    if unit.channel then Combat.interruptChannel(combat, unit, "dismissed") end
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
    -- A caster cut down mid-channel drops the spell -- clear the pending payload and badge so nothing
    -- detonates from a corpse and the turn order stays clean.
    if target.channel then Combat.interruptChannel(combat, target, "death") end

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
        -- Animation cue: fade the fallen unit's sprite (and its timeline card) to black and animate
        -- it out. A corpse token, when one is left, takes over once the fade completes.
        Combat.pushFx(combat, { type = "death", unit = target })
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
    -- A ward may stand for several blows (its `magnitude`, which the granting spell raises as it is
    -- forged), so spend ONE hit rather than the whole status and say what is left standing.
    local barrier = Status.barrierAgainst(target, hasTag(tags or {}, "magical"))
    if barrier then
        local left = Status.consumeBarrier(combat, target, barrier)
        local note = ""
        if left > 0 then note = string.format(" (%d left)", left) end
        Combat.logEvent(combat, "status",
            string.format("%s's %s absorbs the blow%s.", unitName(target), barrier.name or barrier.id, note))
        return 0
    end
    -- A standing Dodge reflex (a trait on cooldown, not a consumed status) voids a physical blow
    -- outright. Like the barrier above it returns BEFORE the trait damage dispatch -- an evaded hit is
    -- not a wound survived, so it grants no rage, advances no threshold phase, and provokes no counter.
    if Trait.tryEvade(combat, target, tags) then
        return 0
    end
    -- A carried smoke charge (Smoke Bomb) negates an incoming ATTACK outright and blinks the bearer
    -- clear. Like the Dodge reflex above it returns BEFORE mitigation and the trait damage dispatch,
    -- so a vanished blow grants no rage and provokes no counter; only a real strike (a known attacker)
    -- fires it, so a poison tick or trap can't waste the one charge.
    if Trait.trySmoke(combat, target, attacker) then
        return 0
    end
    -- A duelist's blade (the Riposte Blade) turns an incoming melee blow aside and answers it in the
    -- same motion. Like the two reflexes above it returns BEFORE mitigation and the trait damage
    -- dispatch -- a blow that never landed is not a wound survived, so it grants no rage and provokes
    -- no second counter on top of the riposte's own.
    if Trait.tryRiposte(combat, target, attacker, tags) then
        return 0
    end
    -- A preternatural reflex (Keen Senses) answers an incoming attack BEFORE it lands, spending stamina.
    -- Unlike the three reflexes above it does not negate the blow: it only goes first, so it returns
    -- true -- and stops the hit here -- purely in the case where its counter killed the attacker and
    -- the swing died with them. A counter that merely wounds falls through, and the blow lands on top
    -- of it as normal.
    if Trait.tryPreempt(combat, target, attacker) then
        return 0
    end
    local dmg = Combat.mitigatedDamage(target, base, tags, opts)
    local hp = target.char.stats.health
    hp.current = hp.current - dmg
    -- Animation cue: the blow that actually landed (post-mitigation), flagged lethal so the view
    -- can punch a killing hit harder. The matching death cue is pushed by killUnit below.
    Combat.pushFx(combat, { type = "damage", unit = target, amount = dmg,
        lethal = hp.current <= 0, attacker = attacker })
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
        -- ...and the statuses riding the survivor get the same news, for the ones a blow is supposed
        -- to BREAK (Sleep). Fired after the traits, so a reflex that answers the blow is not robbed of
        -- its trigger by the very hit that wakes its bearer.
        Status.onDamaged(combat, target, dmg, tags)
    end
    return dmg
end

-- The magnitude an ability declares, whatever it drives -- a weapon/spell's `damage`, a potion's
-- `healing`, a draught's `restore`, or a scroll's `reviveHealth`. Exactly one is authored per ability;
-- this returns its (already leveled) value, or nil for an ability that grants no magnitude (a pure
-- displacement/cleanse, or a summon/placement that scales off the item's upgrade level via fx.level
-- instead). The single reader, so the concrete field an item chose is looked up in one place --
-- fx.amount, the primary-stat headline, and dealDamage all agree.
function Combat.abilityMagnitude(ab)
    if not ab then return nil end
    return ab.damage or ab.healing or ab.restore or ab.reviveHealth or ab.hits
end

-- Is `ab` aimed at exactly one body? An ability declaring no `aoe` footprint strikes only what it is
-- pointed at. The single reader for "single-target", which is the whole domain of the two wards below:
-- a mirror turns a spell back at the one who threw it, and that only means anything when there IS one
-- thing thrown at one target. A fireball has no single caster-target thread to run backwards along, so
-- neither ward touches an area cast -- which is also what keeps them from being flatly better than a
-- barrier rather than differently good.
function Combat.isSingleTarget(ab)
    return ab ~= nil and ab.aoe == nil
end

-- The two wards that answer a single-target blow BEFORE it lands, tried in order: Counter Magic (a
-- trait -- unravels the spell for nothing at all, at the price of mana and a cooldown) and then a
-- mirror status (Reflect Magic / Reflect Steel -- throws it back). True when one of them ate the blow,
-- in which case the target takes nothing.
--
-- `base` is what the ATTACKER's swing was worth, so a reflected spell hits its caster with exactly the
-- blow they threw -- mitigated by their OWN magic defense on the way in. Deliberately not re-scaled off
-- the reflector: a knight who mirrors a fireball returns the mage's fireball, not the knight's idea of
-- one, and a mirror is therefore worth exactly as much as what it is pointed at.
--
-- Lives here in dealDamage rather than in dealFlatDamage because only this path knows the ITEM, and
-- both wards are keyed on the cast being a single-target ability. A trap, a Burn tick, or a falling
-- rock reaches the flat path with no ability at all, and is (rightly) unmirrorable.
local function tryWardSpell(combat, user, target, item, tags, base, opts)
    local ab = item and item.activeAbility
    if not Combat.isSingleTarget(ab) then return false end
    if not user or user == target or user.side == target.side then return false end
    if Trait.tryCounterMagic(combat, target, user, tags) then return true end
    -- A mirror never answers a mirror: without this, two reflecting mages bounce one spell between
    -- them until the stack gives out. The first mirror to catch it is the one that gets to throw it.
    if combat._reflecting then return false end
    local mirror = Status.reflectorAgainst(target, hasTag(tags, "magical"))
    if not mirror then return false end
    Combat.logEvent(combat, "status", string.format("%s's %s turns the blow back on %s!",
        unitName(target), mirror.name or mirror.id, unitName(user)))
    combat._reflecting = true
    -- A beat later than the blow it turned, so the view plays the return after the cast (as a riposte
    -- does). The caster is passed as `attacker` = the reflector, so the returned blow is a blow from
    -- the mirror's holder -- it can be barriered, dodged, and counted like any other.
    Combat.beginBeat(combat)
    Combat.dealFlatDamage(combat, user, base, tags, mirror.name or mirror.id, target, opts)
    Combat.endBeat(combat)
    combat._reflecting = nil
    return true
end

function Combat.dealDamage(combat, user, target, item, opts)
    opts = opts or {}
    local tags = collectTags(item, opts)
    local magical = hasTag(tags, "magical")
    local atkStat = magical and "magicDamage" or "damage"
    local ab = item and item.activeAbility
    -- Additive: the ability's damage plus the attacker's attack stat (opts.amount overrides the
    -- declared damage for a one-off hit). Mitigation then subtracts the target's defense + resists.
    local base = (opts.amount or (ab and ab.damage) or 0) + flatStat(user, atkStat) + unarmedDamageBonus(user, item)
    -- A counter or a mirror may unmake the cast entirely before it reaches the target's armor.
    if tryWardSpell(combat, user, target, item, tags, base, opts) then return 0 end
    -- `user` rides along as the attacker so a reaction trait (a counter) knows who struck, and how
    -- far away they stood. A flat source (a trap, a burn) passes no attacker and provokes no counter.
    local dealt = Combat.dealFlatDamage(combat, target, base, tags, nil, user, opts)
    -- Let the attacker's statuses record what they just did (Fury banks damage dealt to heal from
    -- later). Fired here, where the attacker is known, only for a survived-or-not real hit.
    Status.onDealDamage(combat, user, dealt)
    return dealt
end

-- Pure: the post-mitigation damage `user` striking `target` with `item` (and `opts`, e.g.
-- { amount = 0.5 }) WOULD deal, computed exactly like Combat.dealDamage but without touching HP or
-- the log. Drives the target-hover damage preview so its number always matches the real hit.
function Combat.computeDamage(combat, user, target, item, opts)
    opts = opts or {}
    local tags = collectTags(item, opts)
    local magical = hasTag(tags, "magical")
    local atkStat = magical and "magicDamage" or "damage"
    local ab = item and item.activeAbility
    local base = (opts.amount or (ab and ab.damage) or 0) + flatStat(user, atkStat) + unarmedDamageBonus(user, item)
    return Combat.mitigatedDamage(target, base, tags, opts)
end

-- Pure: the damage `unit` striking a trap with `weapon` would deal -- the weapon's attack stat
-- (magical weapons route through magicDamage), floored at 1. Traps carry no defense, so this is
-- the raw stat. Mirrors the math inside Combat.strikeTrap so the strike-trap hover preview matches.
function Combat.computeTrapDamage(unit, weapon)
    local tags = collectTags(weapon, {})
    local atkStat = hasTag(tags, "magical") and "magicDamage" or "damage"
    local ab = weapon and weapon.activeAbility
    local dmg = (ab and ab.damage) or 0
    return math.max(1, math.floor(dmg + flatStat(unit, atkStat) + 0.5))
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
        Combat.pushFx(combat, { type = "heal", unit = target, amount = healed })
    end
    return healed
end

-- Strip every debuff from `unit` and log it (Cure). Delegates the removal to Status.cleanse -- the
-- single rule for what counts as a debuff -- and adds the log line the spell wants. Returns the count.
function Combat.cleanse(combat, unit)
    local n = Status.cleanse(combat, unit)
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
        amount = opts.amount,
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
    -- Fold in a neighboring Alchemic Mastery charm's magnitude bonus (and any frenzy) exactly as
    -- Combat.useItem does, so the previewed number matches the hit the player is about to land.
    local effectiveAmount = castAmount(combat, unit, ab, tx, ty, auraMods)
    local fx = {
        user = unit, target = target, item = item, combat = combat, tx = tx, ty = ty,
        amount = effectiveAmount, -- the ability's scaled magnitude; effects derive heal/status/etc. from it
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
            if opts.amount == nil then opts.amount = effectiveAmount end
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
        -- Read-only, so the dry run may answer truthfully; the mutating ones are inert.
        hasStatus = function(tgt, id) return tgt ~= nil and Status.has(tgt, id) end,
        clearStatus = function() end,
        swap = function() return false end,
        drain = function() return 0 end,
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
        -- Dual Wield's preview: a sub-strike shows the weapon's post-mitigation damage on the target,
        -- so the tooltip totals the swings. setSpeed is inert here (the timeline isn't previewed).
        strikeWith = function(weapon)
            local wab = weapon and weapon.activeAbility
            if not (wab and target) then return { damageDealt = 0 } end
            local d = Combat.computeDamage(combat, unit, target, weapon, { amount = Combat.abilityMagnitude(wab) })
            entryFor(target).damage = entryFor(target).damage + d
            return { damageDealt = d }
        end,
        setSpeed = function() end,
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

-- Pure: what `target` would throw BACK if `unit` struck it with `item` right now -- the standing
-- reflexes (a parry, a riposte, thorns, a shield bash) that answer the blow -- as the ordered list
-- Trait.counterPreview returns, or nil when nothing answers. The companion to previewAbility: that
-- one says what the swing does, this one says what it costs you to have swung, so the hover preview
-- can price a trade rather than half of one.
--
-- `opts.entry` is the target's own previewAbility entry, since what comes back depends on what goes
-- out: a blow that FELLS its target is answered by nothing (the on-hit hooks never fire on a kill),
-- and a reflecting reflex throws back a share of the damage dealt. `opts.fromX/fromY` is the tile the
-- blow is thrown FROM when that isn't where the actor stands yet -- a click-to-use folds an approach
-- into the strike, and every reflex is gated on the distance at the moment of the hit, so a preview
-- weighed from the actor's current tile would promise the wrong answer for the walk-and-strike.
function Combat.previewCounters(combat, unit, item, target, opts)
    opts = opts or {}
    if not unit or not item or not target or not target.alive then return nil end
    if target.side == unit.side then return nil end -- an ally doesn't answer a heal
    local entry = opts.entry
    local list = Trait.counterPreview(combat, target, unit, {
        tags = collectTags(item, {}),
        damage = entry and entry.damage or 0,
        lethal = entry and entry.lethal,
        fromX = opts.fromX, fromY = opts.fromY,
    })
    return (#list > 0) and list or nil
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
-- stand-in (so `damage` is the pre-armor ability damage + attack stat) and captures the `fx.amount`-
-- derived heal and status too, so it stays correct for AoE / multi-hit / heal / buff abilities alike.
-- `unit` may be nil (a shop with no unit selected, an Armory hover with no acting member): it falls
-- back to a zero-stat stand-in caster, so `out.damage` is exactly the item's raw damage -- which is
-- what the primary-stat row quotes regardless. Returns { damage, heal, statuses = { { id, def, opts } },
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
        amount = Combat.abilityMagnitude(ab),
        level = item and item.level or 0, -- so a summon/hazard/trap effect can quote its level-scaled output
        unitAt = function() return nil end,
        unitsNear = function() return { dummy } end,
        -- There is no board here, so hand back the cell itself: an effect that goes on to place
        -- something there must not bail before it has told us what it would have placed.
        openTileNear = function(x, y) return x, y end,
        aoeUnits = function() return { dummy } end,
        -- One stand-in cell so an area effect that paints the ground (Sanctuary, Rain, a Fireball's
        -- embers) runs its placement once and records WHAT hazard it lays -- the tooltip needs that.
        -- Every data effect only loops aoeCells to place hazards, so a single cell can't inflate damage.
        aoeCells = function() return { { x = 0, y = 0 } } end,
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
        hasStatus = function() return false end,
        clearStatus = function() end,
        swap = function() return false end,
        drain = function() return 0 end,
        restore = function(_, _, amount) return amount or 0 end,
        adjacentItems = function() return {} end,
        adjacentMatching = function() return 0 end,
        -- Record WHICH trap the ability would place, and the item-level-scaled magnitude it carries, so
        -- the inventory tooltip can name it and quote what crossing it does (via Trap.preview) at this
        -- upgrade level -- the way `summon` records its creature.
        placeTrap = function(_, _, id, opts)
            out.trap = id
            out.trapAmount = opts and opts.amount
            return nil
        end,
        -- Record WHAT hazard the ability would lay, and for how long / how hard, so the tooltip can name
        -- the ground it paints and quote its lifespan and effect (via Hazard.preview) at this level.
        placeHazard = function(_, _, id, opts)
            out.hazard = id
            out.hazardDuration = opts and opts.duration
            out.hazardAmount = opts and opts.amount
            return nil
        end,
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
        -- Dual Wield's raw-output row: add each swung weapon's pre-armor damage against the stand-in.
        -- With no acting unit (or its weapons not beside it) the effect finds nothing to swing and the
        -- row reads 0 -- honest, since Dual Wield's output IS whatever weapons sit next to it.
        strikeWith = function(weapon)
            local wab = weapon and weapon.activeAbility
            if not wab then return { damageDealt = 0 } end
            local d = Combat.computeDamage(nil, unit, dummy, weapon, { amount = Combat.abilityMagnitude(wab) })
            out.damage = out.damage + d
            return { damageDealt = d }
        end,
        setSpeed = function() end,
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

-- Drain up to `amount` of a resource from `char`, returning how much was actually removed (never more
-- than it held). The mirror of Combat.restoreResource, which refuses negatives -- so Drain Mana reads
-- what it took here and hands exactly that much back to its caster. A {max,current} pool loses from
-- `current` (floored at 0); a plain-number stat is decremented the same way.
function Combat.drainResource(char, stat, amount)
    if not amount or amount <= 0 then return 0 end
    local res = char.stats[stat]
    if type(res) == "table" then
        local before = res.current
        res.current = math.max(0, res.current - amount)
        return before - res.current
    end
    local before = res or 0
    char.stats[stat] = math.max(0, before - amount)
    return before - math.max(0, before - amount)
end

-- Swap two units' tiles (the Rogue's Swap). Both arrivals spring whatever waits on the tile they land
-- on (Combat.enterTile: traps, hazards), exactly as a walk or a shove would -- so trading places into a
-- trap is as real as stepping onto one, unless Feather Boots carry the mover clear. Positions are set
-- together FIRST, then arrivals resolved, so enterTile never reads a stale collision mid-swap.
-- Neither passes a `reason`: a swap trades two units through each other without either crossing the
-- ground between, so it springs both tiles but bleeds neither.
function Combat.swapUnits(combat, a, b)
    if not (a and b and a.alive and b.alive) then return false end
    a.x, a.y, b.x, b.y = b.x, b.y, a.x, a.y
    Combat.enterTile(combat, a, a.x, a.y)
    if b.alive then Combat.enterTile(combat, b, b.x, b.y) end
    return true
end

-- One Overwatch reaction: `watcher`, holding the stance, looses a single weapon-scaled shot at `mover`
-- if its default weapon reaches the mover from where it stands and it can pay the stance's per-shot
-- stamina. The shot spends stamina but no timeline. Returns true if it fired. Reads and pays stamina
-- through the same helpers a cast uses, so a summon carrying a flat stamina number and a hero with a
-- pool both resolve.
local function overwatchShot(combat, watcher, mover)
    if not (mover.alive and watcher.alive) then return false end
    local weapon = Combat.defaultWeapon(watcher.char)
    local ab = weapon and weapon.activeAbility
    if not ab then return false end
    local per = (watcher.overwatch and watcher.overwatch.staminaPerShot) or 0
    if resourceValue(watcher.char, "stamina") < per then return false end
    local range = Combat.abilityRange(combat, watcher, ab, watcher.x, watcher.y)
        + Combat.adjacencyRangeBonus(watcher.char, weapon)
    local d = manhattan(watcher.x, watcher.y, mover.x, mover.y)
    if d > range or d < Combat.abilityMinRange(ab) then return false end
    if ab.requiresSight and not Combat.hasLineOfSight(combat, watcher.x, watcher.y, mover.x, mover.y) then
        return false
    end
    if per > 0 then spendResource(watcher.char, "stamina", per) end
    Combat.logEvent(combat, "action", string.format("%s fires on overwatch!", unitName(watcher)))
    Combat.dealDamage(combat, watcher, mover, weapon)
    return true
end

-- Every opposing Overwatch stance reacts to `mover` arriving on its current tile: each watcher whose
-- weapon now reaches the mover looses a shot. Driven per walked tile from Combat.stepMove, so a unit
-- crossing a firing line is shot on each step it spends within range, until a watcher's stamina runs
-- dry. Guarded against re-entrancy so a reaction that shifts a unit can't spiral back through here.
function Combat.triggerOverwatch(combat, mover)
    if not mover or not mover.alive or combat._overwatching then return end
    combat._overwatching = true
    for _, watcher in ipairs(combat.units) do
        if watcher.alive and watcher.overwatch and watcher.side ~= mover.side then
            overwatchShot(combat, watcher, mover)
        end
    end
    combat._overwatching = false
end

-- Overchannel: a mage that casts through its own life when the mana runs dry (the trait of the same
-- name). A capability read, not a dispatched hook -- there is no "onSpend" trait event, so the cost
-- path consults this directly (documented as the one trait that works this way).
function Combat.canOverchannel(unit)
    return Trait.has(unit, "overchannel")
end

-- ---------------------------------------------------------------------------
-- Drinking from the grid. Two reflexes reach past their bearer's turn and pull a potion out of the
-- satchel on their own -- the Survivor's Reflex (a killing blow answered with a healing draught) and
-- the Alchemist's Reservoir (a spell the mana wouldn't cover, paid for out of a flask). Both need the
-- same two things: find a potion that gives the right thing, and drink it. They share them here so
-- "what counts as a mana potion" is answered once, and a new draught is picked up by both for free.
--
-- A reflex-drunk potion is deliberately NOT a cast: it costs no turn, no initiative and no speed, it
-- can't be aimed, and it does only the restoring half of what the item does in your hand. That
-- asymmetry is the price of the automation -- the reflex spends your stock without your say-so, and
-- in exchange it never spends your tempo.
-- ---------------------------------------------------------------------------

-- What resource drinking `item` would give: "health" for a draught declaring `healing`, else whatever
-- its `restoreStat` names (a mana or stamina draught's `restore`). nil for anything that restores
-- nothing. The single reader for "what is in this flask", so a potion is classified the same way by
-- both reflexes and by any future one.
function Combat.restorativeStat(item)
    local ab = item and item.activeAbility
    if not ab then return nil end
    if ab.healing then return "health" end
    if ab.restore then return ab.restoreStat end
    return nil
end

-- The first in-stock consumable in `unit`'s grid that would restore `stat` to whoever drinks it, or
-- nil. Grid order (row-major), so the player chooses which flask a reflex reaches for by where they
-- put it -- the same way the grid already decides a default weapon (Combat.defaultWeapon).
function Combat.carriedRestorative(unit, stat)
    if not (unit and unit.char) then return nil end
    for _, item in ipairs(Character.eachItem(unit.char)) do
        if item.type == "consumable" and not Combat.isDepleted(item)
            and Combat.restorativeStat(item) == stat then
            return item
        end
    end
    return nil
end

-- Drink `item` on the spot: spend one from the stack and hand its magnitude to `unit`. Returns the
-- amount actually restored (a heal routes through applyHeal so it is capped and logged like any
-- other; everything else goes through restoreResource, which respects a reserved ceiling).
function Combat.quaff(combat, unit, item)
    local stat = Combat.restorativeStat(item)
    if not stat then return 0 end
    local ab = item.activeAbility
    local amount = ab.healing or ab.restore or 0
    item.quantity = math.max(0, (item.quantity or 1) - 1)
    Combat.logEvent(combat, "action",
        string.format("%s downs %s.", unitName(unit), item.name or "a potion"))
    if stat == "health" then return Combat.applyHeal(combat, unit, amount) end
    return Combat.restoreResource(unit.char, stat, amount)
end

-- Alchemist's Reservoir: a caster that pays for a spell out of a flask when the mana runs dry (the
-- trait of the same name). Read exactly like Combat.canOverchannel beside it -- a capability the cost
-- path consults directly, since there is no "onSpend" trait event -- and it is the same bargain made
-- from a different pocket: Overchannel spends life it cannot get back, this spends stock it can.
-- True only when a mana draught is actually in the satchel, so an empty alchemist is blocked normally.
function Combat.canDrawOnPotion(unit)
    return Trait.has(unit, "alchemists_reservoir")
        and Combat.carriedRestorative(unit, "mana") ~= nil
end

-- Pay an ability's `cost` for `unit`. Normally a plain spend; but an Overchannel unit short on mana
-- drains what mana it has and pays the shortfall out of health (1 HP per missing point). The single
-- spend path useItem / strikeTrap / strikeWall all route through, so casting-in-blood is uniform.
function Combat.spendCost(combat, unit, cost)
    if not cost then return end
    local char = unit.char
    -- Short on mana with a flask to hand: drink first, then pay as normal. Tried BEFORE Overchannel
    -- because a mage carrying both should reach for the potion before it reaches for its own blood --
    -- stock is the cheaper of the two, and a reflex that burned health while a draught sat unopened in
    -- the satchel would be a bug that reads as one. Drinking may still leave the cast short (a small
    -- flask against a big spell), in which case Overchannel picks up the remainder exactly as it would
    -- have, and a caster with neither is simply refused by costBlock before it ever reaches here.
    if cost.stat == "mana" and resourceValue(char, "mana") < cost.amount and Combat.canDrawOnPotion(unit) then
        Combat.quaff(combat, unit, Combat.carriedRestorative(unit, "mana"))
    end
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
    Combat.enterTile(combat, unit, x, y) -- no `reason`: a blink crosses no ground (see Combat.enterTile)
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
        -- Nor is an Alchemist's Reservoir caster with a mana draught still in stock: spendCost will
        -- open it on the way through. Weighed against what the flask actually holds, so a thimble of
        -- mana against a great working still reports "not enough mana" rather than promising a cast
        -- the spend path would then have to refuse -- this gate and that one must agree.
        local paidInStock = false
        if cost.stat == "mana" and not paidInBlood and Combat.canDrawOnPotion(unit) then
            local flask = Combat.carriedRestorative(unit, "mana")
            local pours = (flask.activeAbility.restore or 0)
            if resourceValue(unit.char, "mana") + pours >= cost.amount then paidInStock = true end
        end
        if not paidInBlood and not paidInStock then
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

-- Is `item` a working of magic -- the thing a denier's armor won't let its wearer touch? True when
-- the item itself is tagged `magical` (a spell, an enchanted blade) or when its ability is paid for
-- in mana (the pool that IS magic in this game: see the silence gate, which draws the same line).
-- Two sources rather than one because the tag and the cost answer different halves of the question --
-- a mana-free `magical` relic is still sorcery, and a mana-cost ability is sorcery whatever it is
-- tagged. Anything else -- a sword, a bomb, a potion, a bandage -- passes.
function Combat.isMagicItem(item)
    if not item then return false end
    if hasTag(item.tags, "magical") then return true end
    local ab = item.activeAbility
    if ab and ab.tags and hasTag(ab.tags, "magical") then return true end
    return ab ~= nil and ab.cost ~= nil and ab.cost.stat == "mana"
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

-- Drop the between-battle leftovers a party character carries out of a finished fight: the mana
-- reservations its summons held, and the `activeSummon` claim each item keeps while its creature
-- stands. Both refer to a field that no longer exists once the battle is over, so leaving them in
-- place makes the overworld read a phantom -- an item tooltip still reporting "is still on the
-- field", a mana ceiling still capped by a reservation. Called when a battle concludes (states/
-- battle.lua) so the party returns clean, and again defensively as each unit is placed in Combat.new.
function Combat.releaseClaims(char)
    if not char then return end
    char.reservations = nil
    for i = 1, Character.MAX_INVENTORY do
        local item = char.inventory[i]
        if item then item.activeSummon = nil end
    end
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

    -- Denied: this unit is cut off from magic outright (the Magic Denied status -- worn by the
    -- Skeptic's Harness, and inflictable by anything else that wants the effect). Broader than the
    -- silence gate above it: that refuses only what is paid for in mana, this refuses the whole craft,
    -- an enchanted blade included. Checked after silence so a mage that is both is told the more
    -- specific thing first.
    if Status.deniesMagic(unit) and Combat.isMagicItem(item) then
        return { kind = "denied", reason = "denies magic",
            text = "Magic isn't real -- this cannot be used" }
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
    -- A custom usability gate the data file owns (Dual Wield: at least two qualifying adjacent weapons,
    -- a rule too dynamic for the static `requiresAdjacent` predicate -- the qualifying set changes with
    -- the item's level). It reads only the unit + its grid, so it stays a pure read like the rest here.
    if ab.usable then
        local ok, text = ab.usable(unit, item)
        if not ok then
            return { kind = "requirement", reason = text or "unusable",
                text = text or "Cannot be used right now" }
        end
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
        -- `noSteal` (a beast's fangs) and `bound` (a signature relic, Item.isBound) are both untakeable:
        -- bound keeps a boss from being stripped of its whole fight in one pickpocket.
        if item and not item.noSteal and not item.bound then
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

-- Forward declaration so Combat.useItem (and Combat.resolveChannel below) can call resolveCast,
-- which is defined just after useItem. `function resolveCast(...)` there assigns to this local.
local resolveCast

-- Strike (tx, ty) with `weapon` as if `user` had cast it: build the weapon's OWN effect context and
-- run its effect, so the weapon's damage, tags, on-hit status, and its own adjacency auras all land
-- exactly as a real cast would. Dual Wield swings several adjacent weapons in one action through this;
-- each sub-strike pays no cost and does not end the turn -- the driving ability owns the resource and
-- timeline accounting. Returns the weapon's result accumulator ({ damageDealt, healed }). This mirrors
-- the damage/status half of resolveCast's fx below (aura tags, on-hit statuses, lifesteal), scoped to
-- the small helper surface a weapon effect actually uses (damage / applyStatus / aoeUnits / knockback).
function Combat.strikeWith(combat, user, weapon, tx, ty)
    local ab = weapon and weapon.activeAbility
    if not ab then return { damageDealt = 0, healed = 0 } end
    local target = Combat.unitAt(combat, tx, ty)
    local auraTags, auraStatuses, auraMods = adjacencyAura(user.char, weapon)
    local effectiveAmount = castAmount(combat, user, ab, tx, ty, auraMods)
    local result = { damageDealt = 0, healed = 0 }
    local fx = {
        user = user, target = target, item = weapon, combat = combat,
        tx = tx, ty = ty, amount = effectiveAmount,
        unitAt = function(x, y) return Combat.unitAt(combat, x, y) end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
        aoeUnits = function() return Combat.aoeUnits(combat, ab, tx, ty, user) end,
        aoeCells = function() return Combat.aoeCells(combat, ab, tx, ty, user) end,
        hasStatus = function(t, id) return t ~= nil and Status.has(t, id) end,
        random = function(n) return Combat.random(n or 1) end,
        log = function(kind, text) return Combat.logEvent(combat, kind, text) end,
        restore = function(t, stat, amount)
            if not t then return 0 end
            return Combat.restoreResource(t.char, stat, amount)
        end,
        heal = function(t, amount)
            if not t then return 0 end
            local h = Combat.applyHeal(combat, t, amount)
            result.healed = result.healed + h
            return h
        end,
        applyStatus = function(t, id, opts)
            if not t then return nil end
            opts = opts or {}
            if opts.applier == nil then opts.applier = user end
            return Status.apply(combat, t, id, opts)
        end,
        knockback = function(t, distance, opts)
            if not t then return 0 end
            return Combat.knockback(combat, user, t, distance, opts)
        end,
        damage = function(tgt, opts)
            if not tgt then return 0 end
            opts = opts or {}
            if opts.amount == nil then opts.amount = effectiveAmount end
            local d = Combat.dealDamage(combat, user, tgt, weapon, withAuraTags(opts, auraTags))
            result.damageDealt = result.damageDealt + d
            if d > 0 then
                for _, st in ipairs(auraStatuses) do
                    Status.apply(combat, tgt, st.id, st.opts)
                end
                if auraMods.lifesteal > 0 then
                    result.healed = result.healed + Combat.applyHeal(combat, user, math.floor(d * auraMods.lifesteal))
                end
            end
            return d
        end,
    }
    if ab.effect then ab.effect(fx) end
    return result
end

-- Perform an item action: validate range + target kind + resource cost, spend the cost,
-- run the ability's effect(fx), push the actor back by the ability speed, and consume the
-- item if it's a consumable. Returns (true, result) or (false, reason). `result` is
-- { damageDealt, healed } aggregated across the effect's helper calls. A channeled ability
-- instead winds up here and resolves later via Combat.resolveChannel (see the channel branch).
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

    -- A channeled ability (a large AOE spell) doesn't resolve now: the caster winds up for
    -- `ab.channel` ticks, during which every other unit gets to act and may walk out of the
    -- threatened tiles. Everything is committed at cast-start -- the cost is spent above, and a
    -- consumable is spent here too -- so an interrupted channel is a fully-wasted cast. The effect
    -- itself runs later, from Combat.resolveChannel when the caster's slot comes back around, and
    -- only THEN is ab.speed charged. Ending the turn by ab.channel (not ab.speed) is what places
    -- the caster back in the order at exactly its resolution slot, so no separate scheduler exists.
    --
    -- The wind-up is `ab.channel` ticks and nothing else: the turn's move cost is DEFERRED past the
    -- resolution (endTurn's `defer`) rather than stacked onto it. Walking before a cast must not
    -- stretch the caster's own telegraph -- that would hand the foes under the blast extra turns to
    -- stroll out of it, and silently punish repositioning. The ground is still paid for, on the far
    -- side: the debt lands on the resolving turn, so the caster's NEXT action comes at the same tick
    -- either way and only the resolution slot moves earlier.
    if ab.channel and ab.channel > 0 then
        if ab.consumesItem then item.quantity = math.max(0, (item.quantity or 1) - 1) end
        unit.channel = { item = item, ab = ab, tx = tx, ty = ty }
        Status.apply(combat, unit, "channeling", { duration = ab.channel + 1 })
        -- The wind-up is an action too: a cast beat on begin-channel, then a second when it resolves
        -- (resolveCast, turns later). So a channeled spell reads both as it is loosed and as it lands.
        Combat.pushFx(combat, { type = "cast", unit = unit, tx = tx, ty = ty,
            support = Combat.isSupportAbility(ab) })
        Combat.logEvent(combat, "action",
            string.format("%s begins channeling %s.", unitName(unit), item.name or "an ability"))
        endTurn(combat, unit, ab.channel, true)
        return true, { channeling = true }
    end

    return resolveCast(combat, unit, item, ab, tx, ty)
end

-- ---------------------------------------------------------------------------
-- Tile tags & elemental spread. A tile is not just its terrain type: what the ground is MADE of at
-- (x, y) is the union of three sources, any of which may carry the same tag --
--   * the terrain itself     (Arena.TILE_PROPS[t].tags -- a river is "conductable", forest "burnable"),
--   * any hazard on the tile (def.tags -- a Rain cloud is "conductable" too),
--   * whoever stands there   (a status's `tileTags` -- Wet makes its bearer's cell "conductable").
-- Combat.tileHasTag asks all three at once, so an effect keyed off a tag never has to care which one
-- answered: a bolt treats a soaked knight, a rain cloud and a river identically. Fire creeping into
-- "burnable" (Hazard.spread) and lightning arcing into "conductable" (below) are the same mechanism
-- pointed at different tags -- a new interaction is a new tag on the data, not a new branch here.
-- ---------------------------------------------------------------------------

-- Does the ground at (x, y) carry `tag`, from terrain, a hazard, or its occupant's statuses? False
-- off the map. Pure, so the battle UI can light the tiles a tag covers and tests can assert it.
function Combat.tileHasTag(combat, x, y, tag)
    local row = combat.arena and combat.arena.tiles and combat.arena.tiles[y]
    local cell = row and row[x]
    if not cell then return false end -- off the map
    if hasTag(cell.tags, tag) then return true end
    for _, h in ipairs(Hazard.allAt(combat, x, y)) do
        if hasTag(h.tags, tag) then return true end
    end
    local occupant = Combat.unitAt(combat, x, y)
    return occupant ~= nil and Status.hasTileTag(occupant, tag)
end

-- Orthogonal neighbors, matching the movement DIRS and Hazard.spread: an element crosses an edge,
-- not a corner, so it can't cut diagonally past a gap.
local SPREAD_DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- The tiles carrying `tag` that a footprint of `cells` reaches: every orthogonally-adjacent tagged
-- tile that isn't itself part of the footprint (those already took the direct hit). Deduped, so a
-- tile touching two blasted cells is only returned once.
function Combat.taggedCellsAround(combat, cells, tag)
    local inFootprint, seen, out = {}, {}, {}
    for _, c in ipairs(cells) do inFootprint[c.x .. "," .. c.y] = true end
    for _, c in ipairs(cells) do
        for _, d in ipairs(SPREAD_DIRS) do
            local nx, ny = c.x + d[1], c.y + d[2]
            local k = nx .. "," .. ny
            if not inFootprint[k] and not seen[k] and Combat.tileHasTag(combat, nx, ny, tag) then
                seen[k] = true
                out[#out + 1] = { x = nx, y = ny }
            end
        end
    end
    return out
end

-- Fraction of the cast's magnitude an arc carries. Below 1 so conducting stays a bonus for setting
-- the water up, never better than aiming the bolt at the target itself.
Combat.CONDUCT_FACTOR = 0.5

-- The tag a lightning cast arcs through; see the section header for what may carry it.
Combat.CONDUCT_TAG = "conductable"

-- Arc a lightning cast out of `cells` into the conductable ground around them, striking whoever
-- stands in it. The arc carries the CAST's own tags, so a Wet victim's `vulnerable = { lightning }`
-- amplifies it exactly as it would the direct hit. Side-agnostic, like the fire it mirrors: a charge
-- in a puddle doesn't check whose boots are in it, so soaking the ground beside your own line is a
-- real risk. Returns the total damage dealt.
function Combat.conductLightning(combat, unit, cells, tags, amount, source)
    if not amount or amount <= 0 then return 0 end
    local base = math.max(1, math.floor(amount * Combat.CONDUCT_FACTOR))
    local total = 0
    for _, c in ipairs(Combat.taggedCellsAround(combat, cells, Combat.CONDUCT_TAG)) do
        local victim = Combat.unitAt(combat, c.x, c.y)
        if victim and victim.alive then
            Combat.logEvent(combat, "action",
                string.format("The charge arcs through the water into %s.", unitName(victim)))
            total = total + Combat.dealFlatDamage(combat, victim, base, tags, source, unit)
        end
    end
    return total
end

-- Resolve a cast's actual effect: build the effect context, run the ability, settle the water/fire
-- interaction and reaction traits, then end the turn by charging ab.speed. Shared by an instant cast
-- (Combat.useItem calls it immediately) and a channel that has finished winding up (Combat.resolveChannel
-- calls it turns later). `target` and `reserve` are derived HERE, not at cast-start, so a channel reads
-- the LIVE board -- a foe that stepped out of the blast is simply gone from fx.aoeUnits(). `alreadyConsumed`
-- is set by the channel path (which spent the stack at cast-start) so the stack isn't decremented twice.
function resolveCast(combat, unit, item, ab, tx, ty, alreadyConsumed)
    local target = Combat.unitAt(combat, tx, ty)
    local reserve = Combat.abilityReserve(unit, ab)

    -- A visible "someone is acting" beat on the CASTER, pushed for every ability -- a heal, a summon,
    -- a self-buff, a strike alike -- so the view can lean/pulse the actor toward the targeted cell and
    -- glow it (green for a friendly cast, warm for an offensive one). Previously only a blow that drew
    -- blood animated the actor (the view derived a lunge from the damage cue); a cure or a summon
    -- resolved with the caster standing dead still. See ui/combat_fx.
    Combat.pushFx(combat, { type = "cast", unit = unit, tx = tx, ty = ty,
        support = Combat.isSupportAbility(ab) })

    -- Effect context: bound helpers let a data-file effect compose damage/heal/AoE
    -- without touching this module. Results are accumulated for the caller/UI.
    -- Adjacency auras from neighboring items (e.g. a Fire Stone next to this weapon) fold extra
    -- tags into every hit and inflict their status on any target this cast damages.
    local auraTags, auraStatuses, auraMods = adjacencyAura(unit.char, item)
    -- The cast's effective magnitude (see castAmount): the ability's own declared amount, raised by a
    -- neighboring Alchemic Mastery charm and by any `frenzy` the ability declares. An amount-less
    -- effect (a pure summon or cleanse) stays nil, so a bonus never conjures damage out of nothing.
    -- Threaded into fx.amount (for effects that read it directly, e.g. a heal) AND into fx.damage's
    -- default opts.amount below -- Combat.dealDamage bases its hit on opts.amount/ab.damage, not on
    -- fx.amount, so a damage bomb needs it fed in there too.
    local effectiveAmount = castAmount(combat, unit, ab, tx, ty, auraMods)
    local result = { damageDealt = 0, healed = 0 }
    -- The initiative this action bills at end of turn, defaulting to the ability's own speed. An effect
    -- may override it (Dual Wield sets the summed speed of the weapons it swings) through fx.setSpeed.
    local ctl = { speed = ab.speed or Combat.DEFAULT_SPEED }
    local fx = {
        user = unit, target = target, item = item, combat = combat,
        tx = tx, ty = ty, -- the targeted cell, for tile-targeted abilities (e.g. placing a trap)
        amount = effectiveAmount, -- effects derive heal/status/restore magnitude from it
        -- The item's upgrade level (0..N). What a summon/hazard/trap/wall scales off: the stronger the
        -- forged item, the tougher the creature it calls and the harder/longer-lived the ground it lays.
        level = item.level or 0,
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
            -- Default the hit's amount to the cast's effective magnitude (which folds in the Alchemic
            -- Mastery bonus); an effect that passes its own `opts.amount` still overrides. Normally
            -- effectiveAmount == ab.damage, so this is a no-op for every cast with no charm beside it.
            opts = opts or {}
            if opts.amount == nil then opts.amount = effectiveAmount end
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
        -- Apply a status effect (models/status.lua) to a unit. The caster rides along as `applier`, so
        -- a standing reaction can tell "I inflicted this" from "this landed on me" (Trait.onStatusApplied).
        applyStatus = function(tgt, id, opts)
            if not tgt then return nil end
            opts = opts or {}
            if opts.applier == nil then opts.applier = unit end
            return Status.apply(combat, tgt, id, opts)
        end,
        -- Does `tgt` currently carry status `id`? What a conditional strike keys its bonus off (a blow
        -- that bites harder against a burned, poisoned or marked foe).
        hasStatus = function(tgt, id) return tgt ~= nil and Status.has(tgt, id) end,
        -- Strip exactly one status by id (Shatter consuming the freeze it shatters, Detonate the DoT it
        -- sets off). Unlike fx.cleanse (every debuff at once) this removes only the named one.
        clearStatus = function(tgt, id)
            if tgt then Status.remove(combat, tgt, id) end
        end,
        -- Trade tiles with `tgt` (the Rogue's Swap); both arrivals spring what waits on the new tile.
        swap = function(tgt)
            if not tgt then return false end
            return Combat.swapUnits(combat, unit, tgt)
        end,
        -- Drain up to `amount` of a resource from `tgt`, returning what was actually taken -- so a siphon
        -- (Drain Mana) can hand exactly that much back to the caster with fx.restore.
        drain = function(tgt, stat, amount)
            if not tgt then return 0 end
            return Combat.drainResource(tgt.char, stat, amount)
        end,
        -- Summon a trap on a tile, owned by the acting unit's side (fx.item's placer). Only a
        -- party placement is logged with its location -- an enemy trap stays hidden until it is
        -- detected or triggers, so surfacing its tile here would leak the detect-traps mechanic.
        placeTrap = function(px, py, id, opts)
            -- opts.amount (an item-level-scaled magnitude) rides onto the trap, so a forged Spike Trap
            -- stabs harder; the trap's own effect reads trap.amount, falling back to its blueprint.
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
        -- Banish a summoned creature: take it off the field without a kill (no corpse, no death
        -- reactions), the same unwinding a lapsed binding gets (Combat.dismiss). Only a `summoned`
        -- unit can be banished -- a real combatant is not a conjuration and is left untouched -- so an
        -- AoE that sweeps friend and foe alike (Banish) only ever unmakes the conjured among them.
        dismiss = function(tgt)
            if tgt and tgt.alive and tgt.summoned then
                Combat.dismiss(combat, tgt,
                    string.format("%s banishes %s.", unitName(unit), unitName(tgt)))
                return true
            end
            return false
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
        -- Exchange a unit's BODY for another character blueprint's (models/transform.lua) -- the same
        -- unit, in a different shape, keeping its tile, its turn and its health pool. What Wild Shape
        -- (the caster becomes a beast) and Polymorph (a victim becomes a pig) both run through.
        --
        -- A SELF-transform holds the ability's reservation for as long as the shape lasts, exactly as
        -- a summoned creature holds it for as long as it stands -- wearing a bear and having a bear
        -- are the same commitment, so they are priced the same way. An INFLICTED shape reserves
        -- nothing: it is a debuff its victim wears, not an upkeep its caster pays, and the caster
        -- already paid at cast time. Both are the status's to end, and reverting releases the lien.
        transform = function(tgt, charId, opts)
            if not tgt then return nil end
            opts = opts or {}
            if opts.reserve == nil and tgt == unit then opts.reserve = reserve end
            return Transform.apply(combat, tgt, charId, opts)
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
        -- Strike the aimed tile with another of the caster's weapons, running ITS own ability effect --
        -- its damage, tags, and on-hit status all land (Combat.strikeWith). Dual Wield swings several
        -- adjacent weapons in one action this way; each sub-strike pays no cost and doesn't end the turn.
        -- Its damage/heal fold into this cast's result so the caller/UI tallies the whole flurry.
        strikeWith = function(weapon)
            local r = Combat.strikeWith(combat, unit, weapon, tx, ty)
            result.damageDealt = result.damageDealt + (r.damageDealt or 0)
            result.healed = result.healed + (r.healed or 0)
            return r
        end,
        -- Override the initiative this action bills at end of turn (Dual Wield: the summed speed of the
        -- weapons it swung). Defaults to ab.speed.
        setSpeed = function(n) ctl.speed = n end,
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
    local footprint = ab.aoe and Combat.aoeCells(combat, ab, tx, ty, unit) or { { x = tx, y = ty } }
    if hasTag(castTags, "water") then
        Hazard.douse(combat, footprint, castTags)
    end

    -- Water carries a charge: a cast carrying the "lightning" tag arcs out of its footprint into any
    -- adjacent water -- wet ground, a rain cloud, or a Wet unit (Combat.conductLightning). Runs after
    -- the effect, so a bolt that soaks as it lands electrifies the puddle it just made.
    if hasTag(castTags, "lightning") then
        result.damageDealt = result.damageDealt + Combat.conductLightning(
            combat, unit, footprint, castTags, effectiveAmount, item.name)
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

    -- Using an item ends the turn: advance by (this turn's move cost) + the ability speed (or the
    -- speed an effect chose through fx.setSpeed -- Dual Wield's summed weapon speeds).
    endTurn(combat, unit, ctl.speed)

    -- Consume one use: decrement the stack (a bundle of consumables), floored at 0. The spent
    -- slot STAYS in the inventory as an empty stack -- Combat.isDepleted then blocks activation
    -- until it's restocked (Character.addItem merges a fresh stack back in). Non-stacked items
    -- carry quantity 1, so this leaves an empty, greyed-out slot after their single use.
    if ab.consumesItem and not auraMods.preserve and not alreadyConsumed then
        item.quantity = math.max(0, (item.quantity or 1) - 1)
    end

    return true, result
end

-- Resolve the ability a unit has been channeling now that its wind-up is over. Clears the pending
-- payload and the "channeling" badge, then runs the deferred effect through resolveCast -- which is
-- where the effect finally fires and, via endTurn, ab.speed is charged (the recovery cost is paid on
-- resolution, never on cast-start). The stack was already consumed at cast-start, so pass
-- alreadyConsumed. Returns resolveCast's (true, result), or false if the unit wasn't channeling.
function Combat.resolveChannel(combat, unit)
    local pending = unit.channel
    if not pending then return false end
    unit.channel = nil
    Status.remove(combat, unit, "channeling")
    Combat.logEvent(combat, "action",
        string.format("%s's %s resolves.", unitName(unit), pending.item.name or "channel"))
    return resolveCast(combat, unit, pending.item, pending.ab, pending.tx, pending.ty, true)
end

-- Cancel a channel in progress: drop the pending payload and the badge, and log the fizzle. A hard
-- commit -- the mana (and any consumable) spent to begin the channel are gone, NOT refunded, so an
-- interrupt is a fully-wasted cast. Idempotent (a multi-tile knockback calls it once). Returns true if
-- a channel was actually interrupted. `reason` is a short phrase for the log ("stunned", "displaced").
function Combat.interruptChannel(combat, unit, reason)
    if not unit.channel then return false end
    unit.channel = nil
    Status.remove(combat, unit, "channeling")
    Combat.logEvent(combat, "status",
        string.format("%s's channel is interrupted (%s)!", unitName(unit), reason or "disrupted"))
    return true
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
    Combat.pushFx(combat, { type = "cast", unit = unit, tx = x, ty = y, support = false })
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
    Combat.pushFx(combat, { type = "cast", unit = unit, tx = x, ty = y, support = false })
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
        -- Every ILLUSION on the unit comes apart, not just Invisible: a status declaring
        -- `illusion = true` is a lie told about a body, and this spell's whole job is that anything
        -- untrue in the area stops being so. Invisible is only the first such lie -- the shapes
        -- (Polymorph, Wild Shape) are the others, and they unravel here for free, reverting through
        -- the same onExpire every other removal path fires. See Status.illusionsOn.
        for _, s in ipairs(Status.illusionsOn(u)) do
            Status.remove(combat, u, s.id)
            Combat.logEvent(combat, "status",
                string.format("%s's %s comes apart!", unitName(u), s.name or s.id))
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
