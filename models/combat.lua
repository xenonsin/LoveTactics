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
local Prop = require("models.prop")
local Character = require("models.character")
local Item = require("models.item") -- for Item.costs: the one place an ability's costs are normalized
local Discipline = require("models.discipline") -- growthClasses: which classes a use tallies

local Combat = {}

-- Random source, in two layers, because two callers want different things from it.
--
-- `combat.rng` is the real one: a generator seeded off the arena and installed by Combat.new, so
-- every draw a battle makes is a function of that battle's seed. The same seed replays the same
-- fight -- which is what lets a bug report be reproduced, and what lets two machines run one duel
-- without quietly drifting apart.
--
-- `Combat.random` is the module-level source, kept because a spec needs to force a particular draw
-- ("steal takes the SECOND item") from outside, before any combat exists to reach into. Replacing
-- it OUTRANKS the per-battle generator: a caller that reached in and pinned the module's source
-- meant it. Left alone it is plain math.random -- the fallback for a combat built without a seed
-- (a scripted board names its layout outright and needs none).
--
-- Draw with Combat.roll(combat, n) -> 1..n, never by calling either source directly.
local DEFAULT_RANDOM = math.random
Combat.random = DEFAULT_RANDOM

-- A pure-Lua Park-Miller generator (16807 / 2^31-1) using Schrage's trick, which keeps every
-- intermediate product under 2^31 so the arithmetic stays exact in a double and yields the same
-- stream on every platform we ship. love.math is deliberately not used: this module is pure Lua
-- (see the header) and has to load headless.
function Combat.newRandom(seed)
    local state = math.floor(math.abs(seed or 1)) % 2147483646 + 1
    return function(n)
        local hi = math.floor(state / 127773)
        local lo = state % 127773
        state = 16807 * lo - 2836 * hi
        if state <= 0 then state = state + 2147483647 end
        if not n or n <= 1 then return 1 end
        return (state % n) + 1
    end
end

-- One draw in 1..n for this battle. See the comment above for which of the two sources answers.
function Combat.roll(combat, n)
    n = n or 1
    if Combat.random ~= DEFAULT_RANDOM then return Combat.random(n) end
    if combat and combat.rng then return combat.rng(n) end
    return Combat.random(n)
end

-- Ability-speed fallback for a unit that carries no ability item at all.
Combat.DEFAULT_SPEED = 5

-- Initiative cost of the Focus / Defend wait-behaviors (see Combat.focus / Combat.defend) when
-- the granting item doesn't specify its own. Both cost more than a plain wait's near-zero delay.
-- Focus costs the most (a real turn's worth of tempo): recovering mana for free should give up a
-- whole turn. Defend is a cheap guard -- clearly less than an attack (DEFAULT_SPEED), clearly more
-- than a Wait -- so bracing lands you back on the timeline soon to re-brace or reassess, rather
-- than freezing you out for a full round (the brace itself lasts only until that next turn).
Combat.FOCUS_SPEED = 10
Combat.DEFEND_SPEED = 3

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

-- Unwrap a hit's `opts.inflicts` -- the status(es) a blow CARRIES (see Combat.dealFlatDamage) -- into
-- a list of { id, opts } pairs, one per status, where `opts` is the Status.apply table it rides with.
-- Accepts a bare id ("status_stun"), a single table naming one ({ id = "status_stun", magnitude = 6 }),
-- or a LIST mixing the two ({ "status_bleed", { id = "status_poison", duration = 8 } }) -- an envenomed
-- blade that carries two riders on one hit. Returns an empty list for a hit that carries nothing.
--
-- Shared by the live path and BOTH damage previews, which is the whole reason it is a function: a
-- carried status is invisible to the tooltip's fx.applyStatus recorder, so a preview that didn't
-- unwrap it here would quietly stop naming the stun the player is about to land.
local function carriedStatuses(opts)
    local carried = opts and opts.inflicts
    if not carried then return {} end
    if type(carried) == "string" then return { { id = carried } } end
    if carried.id then return { { id = carried.id, opts = carried } } end
    local out = {}
    for _, c in ipairs(carried) do
        if type(c) == "string" then
            out[#out + 1] = { id = c }
        elseif c.id then
            out[#out + 1] = { id = c.id, opts = c }
        end
    end
    return out
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

-- ---------------------------------------------------------------------------
-- Footprints: a unit occupies a w×h block of cells anchored at its top-left (unit.x, unit.y).
-- Absent w/h reads as 1×1, so every single-tile unit -- which is every unit today -- and every
-- caller that still reasons in single points behaves exactly as before. Only code that asks "which
-- cells?" or "how close?" needs the helpers below.
-- ---------------------------------------------------------------------------

-- The cells a w×h box anchored at (ax, ay) covers. No board clamp: callers that care about bounds
-- test each cell (footprintFree / footprintCanShift), and the reach/move math wants the raw cells so
-- an off-board one reads as "not free" rather than silently dropping out.
function Combat.cellsAt(w, h, ax, ay)
    w, h = w or 1, h or 1
    local out = {}
    for j = 0, h - 1 do
        for i = 0, w - 1 do
            out[#out + 1] = { x = ax + i, y = ay + j }
        end
    end
    return out
end

-- Every cell a unit's body stands on, from its anchor and footprint.
function Combat.unitCells(unit)
    return Combat.cellsAt(unit.w, unit.h, unit.x, unit.y)
end

-- Min Manhattan distance from point (x, y) to the nearest cell of `unit`'s footprint -- 0 when the
-- point lies inside the body. The footprint-aware stand-in for manhattan(x, y, unit.x, unit.y):
-- range, earshot and aura checks measure to the nearest cell, so a big body counts as "in reach"
-- when any part of it is. Computed as the distance to an axis-aligned box (0 within the span on an
-- axis, else the overshoot), which for a 1×1 unit is exactly the old manhattan.
function Combat.cellGap(x, y, unit)
    local w, h = unit.w or 1, unit.h or 1
    local dx = math.max(unit.x - x, x - (unit.x + w - 1), 0)
    local dy = math.max(unit.y - y, y - (unit.y + h - 1), 0)
    return dx + dy
end

-- The cell of `unit`'s footprint nearest to (x, y) -- the cell a strike aimed at this body should
-- land on, so the range re-check in Combat.useItem (measured to that cell) agrees with whatever
-- planned the shot. Ties break toward the smaller coordinate; a 1×1 body returns its one cell.
function Combat.nearestCell(x, y, unit)
    local best, bx, by
    for _, c in ipairs(Combat.unitCells(unit)) do
        local d = math.abs(c.x - x) + math.abs(c.y - y)
        if not best or d < best then best, bx, by = d, c.x, c.y end
    end
    return bx, by
end

-- Min Manhattan distance between two units' footprints (nearest cell to nearest cell). A gap of 1
-- means orthogonally adjacent bodies -- the melee-reach test for units of any size; 0 only if they
-- overlap, which the occupancy rules never allow for two living units.
function Combat.unitGap(a, b)
    local bw, bh = b.w or 1, b.h or 1
    local best
    for j = 0, bh - 1 do
        for i = 0, bw - 1 do
            local d = Combat.cellGap(b.x + i, b.y + j, a)
            if not best or d < best then best = d end
        end
    end
    return best or 0
end

-- Can a w×h body come to REST at anchor (ax, ay)? Every covered cell must be on the board, walkable,
-- clear of blocking objects, and clear of any OTHER unit (`ignoreUnit`'s own cells don't count, so a
-- unit tests tiles it already stands on as free for itself). This is the "footing" predicate shared
-- by placement finders and the forced-movement / stop checks; a flier's PATH crossing non-walkable
-- ground is moveGraph's business, but where it finally stops still answers to this.
function Combat.footprintFree(combat, w, h, ax, ay, ignoreUnit)
    local arena = combat.arena
    for _, c in ipairs(Combat.cellsAt(w, h, ax, ay)) do
        local row = arena and arena.tiles and arena.tiles[c.y]
        local cell = row and row[c.x]
        if not (cell and cell.walkable) then return false end
        if Combat.objectBlocksAt(combat, c.x, c.y) then return false end
        local occ = Combat.unitAt(combat, c.x, c.y)
        if occ and occ ~= ignoreUnit then return false end
    end
    return true
end

-- Does any cell of `unit`'s body have a clear line to (x, y)? A wide body sees -- and shoots, and is
-- shot -- from whichever part of it can, so line of sight is the union over its footprint cells. For
-- a 1×1 unit this is a single Combat.hasLineOfSight from its one cell.
function Combat.unitHasSight(combat, unit, x, y)
    for _, c in ipairs(Combat.unitCells(unit)) do
        if Combat.hasLineOfSight(combat, c.x, c.y, x, y) then return true end
    end
    return false
end

-- Can unit `a` see unit `b` -- any cell of a's body to any cell of b's? The two-body form of
-- unitHasSight, for the target checks (targeting, overwatch) where both ends may be wide.
function Combat.unitsSighted(combat, a, b)
    for _, c in ipairs(Combat.unitCells(b)) do
        if Combat.unitHasSight(combat, a, c.x, c.y) then return true end
    end
    return false
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
--
-- `subjects` names the unit (or units) the line is ABOUT -- the mover, the struck, the healed. Pure
-- references, kept so the log panel can point back at who a hovered line means: hovering "Rowan takes
-- 7 damage" rings Rowan on the board and on the initiative strip (ui/combat_log.lua feeds
-- states/battle.lua's overlays). Optional everywhere; a line with no subject simply can't be pointed
-- at. Stored as a list on entry.units, nils dropped, so callers can pass a maybe-target directly.
function Combat.logEvent(combat, kind, text, subjects)
    if not text then return end
    local log = combat.log
    if not log then log = {}; combat.log = log end
    local entry = { kind = kind or "system", text = text, turn = combat.turnCount or 0 }
    if subjects then
        local units = subjects.char and { subjects } or subjects -- a bare unit, or a list of them
        local kept = {}
        for _, u in ipairs(units) do
            if type(u) == "table" and u.char then kept[#kept + 1] = u end
        end
        if #kept > 0 then entry.units = kept end
    end
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

-- A purely VISUAL detonation on tile (x, y): the board paints a burst there (ui/combat_fx.lua reads the
-- cue), shaped and tinted by `tags` -- fire blooms orange. It deals nothing itself; the wound a blast
-- inflicts rides on its own damage cues, one per body caught. What a self-destruct
-- (data/items/ability/ability_self_destruct.lua) and a Volatile bearer's death
-- (data/traits/trait_volatile.lua) reach for, so the explosion reads from the tile it went off on even
-- when the ring catches nobody at all. Carries its own coordinates rather than a unit reference, so it
-- still draws after the bomber that raised it has already left the board (fx.expendSelf dismissed it).
-- Headless-safe: pushFx is a no-op on a combat with no fx sink, and the two dry-run contexts stub
-- fx.burst inert so a hovered/AI-previewed cast never queues a boom the board would then draw.
function Combat.spawnBurst(combat, x, y, tags, opts)
    opts = opts or {}
    return Combat.pushFx(combat, {
        type = "burst", x = x, y = y, tags = tags,
        lethal = opts.lethal, radius = opts.radius,
    })
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
        total = total + ((cell and cell.sightCost) or 0)
            + Wall.sightCostAt(combat, x, y) + Prop.sightCostAt(combat, x, y)
            -- ...and the ground itself, for the one zone that is opaque (Darkness). Terrain, walls,
            -- furniture and hazards are four ways of standing between two people, and sight has no
            -- reason to tell them apart.
            + Hazard.sightCostAt(combat, x, y)
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

-- The weapon `unit` would ANSWER with against a blow struck from `dist` tiles away, or nil when
-- nothing in hand reaches that far. Unlike Combat.defaultWeapon -- which takes the first weapon in
-- slot order, and so answers a bowshot with a sword when the sword happens to sort first -- this asks
-- the question a counter actually asks: "can I reach back from where I stand?". A unit carrying both
-- a sword and a bow answers an adjacent blow with the sword and a distant one with the bow, whichever
-- order the grid holds them in, because reach is the whole gate on answering now (see Trait.mayCounter).
--
-- `minRange` is honoured here and nowhere else in the reach math: an archer cannot answer a foe
-- standing on top of it. That dead zone is what makes closing the distance on an archer the correct
-- play rather than a wash, so it has to bind the answer as well as the aimed shot.
--
-- Falls back to the hidden unarmed weapon only for a unit carrying NO weapon at all -- never as a
-- second chance for an armed one. An archer with a foe in its face does not drop the bow to throw a
-- punch: the dead zone has to actually cost it the answer, or closing the distance buys nothing and
-- the rule teaches nobody anything.
function Combat.answeringWeapon(combat, unit, dist)
    local function reaches(item)
        local ab = item and item.activeAbility
        return ab ~= nil
            and dist >= Combat.abilityMinRange(ab)
            and dist <= Combat.abilityRange(combat, unit, ab)
    end
    local armed = false
    for _, item in ipairs(Character.eachItem(unit.char)) do
        if item.type == "weapon" and item.activeAbility then
            armed = true
            if reaches(item) then return item end
        end
    end
    if not armed and reaches(unit.char.unarmed) then return unit.char.unarmed end
    return nil
end

-- Throw an ANSWER with `weapon`: the blow itself, and then the step back a hit-and-run weapon takes
-- however it is swung. A weapon declaring `hitAndRun = n` gives ground n tiles from whatever it just
-- bit -- the wolf's Fangs (data/items/weapon/weapon_wolf_fangs.lua), whose own ability effect calls
-- fx.retreat for exactly the same reason. Without this the step-back would be a property of the
-- wolf's TURN rather than of its teeth: it darts in and out on its own initiative, then counters a
-- blow and stands there in reach to be worked over, which is the one thing a wolf never does.
--
-- The retreat rides here rather than inside `dealDamage` because only an answer may safely move its
-- thrower. An on-hit reflex is dispatched once the whole action has resolved (Combat.beginAnswers),
-- so the board is settled and the bearer's tile is nobody's business but its own. The two reflexes
-- that fire MID-action instead -- the riposte that deflects a blow and Keen Senses' preempt, both
-- thrown from inside dealFlatDamage before the strike has landed -- deliberately do not route here:
-- moving their bearer would shift a cast's geometry out from under the effect still resolving it.
--
-- Giving ground after the answer is what makes it stick: any answer to THIS answer re-checks reach
-- against the final board too, and finds the bearer a tile further off than it swung from.
-- Returns the damage dealt, exactly as dealDamage does.
function Combat.answerStrike(combat, unit, target, weapon)
    if not (unit and target and weapon) then return 0 end
    local dealt = Combat.dealDamage(combat, unit, target, weapon)
    local back = weapon.hitAndRun
    -- Nothing to disengage from once the foe is down, and a bearer felled by its own exchange (a
    -- counter to the counter) stays where it fell.
    if back and back > 0 and unit.alive and target.alive then
        Combat.knockback(combat, target, unit, back, { amount = 0 })
    end
    return dealt
end

-- The character's player-chosen DEFAULT ACTION: the ability used by the click-to-use basic action
-- and the effective-range band shown on its turn. Unlike defaultWeapon this can be ANY ability item
-- (a spell, a heal, a consumable), pinned in the Loadout screen via `char.defaultActionSlot`.
-- Selection: the pinned slot (only while it still holds an ability item -- a stale pin silently
-- falls back), else the first inventory weapon with an ability, else the first ability item of any
-- kind, else the hidden unarmed weapon. So a fighter defaults to its sword and a mage with no weapon
-- to its attack spell, until the player pins something else.
--
-- A signature still charging toward its in-battle `unlock` is passed over at every step, the pin
-- included -- the same reading Combat.initiative already takes of a locked ability when it sets the
-- opening tempo. The default action is the click-to-use BASIC action, and a move the unit has to earn
-- cannot be the one it opens with: a bearer carrying nothing else would be left with no basic attack
-- at all, and a kill-gated signature (Borrowed Time) deadlocks outright, since the kills that open it
-- can only be taken with it. Passing the live `unit` asks the lock rather than assuming it -- so the
-- pin comes back the moment the signature opens, and the turn after it charges auto-arms the
-- marquee swing. Without a unit (the Loadout screen, which has no battle to ask) a locked ability is
-- simply not the default.
function Combat.defaultAction(char, unit)
    local function ready(item)
        local ab = item and item.activeAbility
        if not ab then return false end
        if not ab.unlock then return true end
        if not unit then return false end
        return Combat.unlockMet(unit, item) and true or false
    end
    local slot = char.defaultActionSlot
    if slot and ready(char.inventory[slot]) then return char.inventory[slot] end
    for _, item in ipairs(Character.eachItem(char)) do
        if item.type == "weapon" and ready(item) then return item end
    end
    for _, item in ipairs(Character.eachItem(char)) do
        if ready(item) then return item end
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
        local sum, n = 0, 0
        for _, item in ipairs(items) do
            -- A signature gated behind an in-battle requirement (an `unlock`) is not a move the unit
            -- can make at the start, so it doesn't set the OPENING tempo -- carrying a locked ultimate
            -- never silently slows a unit's first turn. An always-available ability counts as before.
            if not item.activeAbility.unlock then
                sum = sum + (item.activeAbility.speed or Combat.DEFAULT_SPEED)
                n = n + 1
            end
        end
        -- Everything it carries is a locked signature: fall back to the unarmed basic-attack tempo,
        -- the same floor a unit with no ability items at all uses.
        if n == 0 then
            avg = (char.unarmed and char.unarmed.activeAbility.speed) or Combat.DEFAULT_SPEED
        else
            avg = sum / n
        end
    end
    return avg - Combat.speed(char)
end

-- Effective flat stat for a unit: the character's base plus aggregated item bonuses
-- (armor) plus any active status modifier (e.g. Defending's temporary +defense). Resource
-- stats ({max,current}) are never read through here.
-- base + what the grid grants + what a status lends + what the BOARD is worth right now. The fourth
-- term is the live-passive read (Trait.liveBonus): a standing rule whose value is a claim about the
-- field as it currently stands -- "1 defense per adjacent enemy" -- rather than a number banked when
-- something happened. Pure, and 0 for any body carrying no such trait, which is nearly all of them.
local function flatStat(unit, name)
    local base = unit.char.stats[name] or 0
    return base + ((unit.bonus and unit.bonus[name]) or 0) + Status.statBonus(unit, name)
        + Trait.liveBonus(unit, name)
end

-- The per-item breakdown of the equipment bonus to `name`: one { label, value } per grid item that
-- moves the stat, named after the item itself (a Ring of Power, a hauberk), so the damage-breakdown
-- tooltip can point at the actual gear instead of a bare "Equipment". Sums to the aggregate
-- applyUnitPassives folded into unit.bonus[name]; the tooltip books any unattributed remainder (a
-- summon or a test fixture whose bonus was set without backing items) under a generic label.
local function equipmentStatParts(unit, name)
    local parts = {}
    if not (unit.char and unit.char.inventory) then return parts end
    for _, item in ipairs(Character.eachItem(unit.char)) do
        local v = item.bonus and item.bonus[name]
        if v and v ~= 0 then parts[#parts + 1] = { label = item.name or "Equipment", value = v } end
    end
    return parts
end

-- The unit's effective movement budget (base + item bonus). Public so status hooks (root's
-- "pay as if you moved max spaces") can read it without duplicating the passive folding.
--
-- FLOORED AT ZERO, because armor movement penalties STACK: applyUnitPassives sums `bonus.movement`
-- across every item in the 3x3 grid, so a body in two heavy plates and a cloth robe is genuinely
-- capable of totalling below nothing. Immobility is a legitimate outcome of over-armouring and is left
-- alone -- what the clamp forbids is a NEGATIVE budget, which reads as "less than planted" in every
-- caller (the Dijkstra in moveGraph, Root's "pay as if you walked max", the reachable preview) and
-- means nothing in any of them. Deliberately clamped here rather than in applyUnitPassives, so the
-- Loadout screen can still show a -5 and tell the player what they have done to themselves.
function Combat.moveBudget(unit)
    local m = flatStat(unit, "movement")
    return m > 0 and m or 0
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
-- companion range/extra-hit halves live in Combat.abilityRange and data/items/weapon/weapon_unarmed.lua.
local function unarmedDamageBonus(user, item)
    if not (user and item and item == user.char.unarmed) then return 0 end
    local ub = user.unarmedBonus
    if not ub then return 0 end
    local bonus = ub.damage or 0
    if ub.drunkDamage and Status.has(user, "status_drunk") then bonus = bonus + ub.drunkDamage end
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

-- The share of a tile's `range` field bonus an ability is actually entitled to. High ground is a
-- VANTAGE: it buys you a longer sightline, so it lengthens the things that travel along one -- an
-- arrow, a bolt, a thrown flask, everything that already declares `requiresSight`. It does nothing
-- for a blade. Standing on a rock does not make your arm longer, and without this gate a range-1
-- sword on a mountain reached two tiles and stabbed straight THROUGH the ally in between, which is
-- what sent someone looking for a range bug.
--
-- `requiresSight` is the gate rather than "base range > 1" on purpose: it is already the flag that
-- means "this is a shot with a line to trace", so a reach weapon (a spear held at arm's length) is
-- correctly left out -- its two tiles are anatomy, not trajectory.
--
-- One helper for all three readers of the bonus (Combat.abilityRange, Combat.attackReach, and the
-- battle state's per-stand-tile standCanHit), because a highlight that disagreed with the gate would
-- read as exactly the bug this fixes.
function Combat.fieldRangeBonus(combat, requiresSight, x, y)
    if not requiresSight then return 0 end
    return Combat.fieldBonus(combat, x, y).range or 0
end

-- Effective range of ability `ab` for `unit` acting from tile (x, y) -- the ability's base range
-- plus whatever `range` field bonus that tile grants a SIGHTED ability (high ground, a vantage
-- object -- see Combat.fieldRangeBonus; a melee swing gets none of it). Defaults to the unit's
-- current tile. The single source of truth for reach, so a positional buff extends targeting, the
-- threat/range highlights, and the enemy AI's planning alike.
function Combat.abilityRange(combat, unit, ab, x, y)
    local base = (ab and ab.range) or 1
    -- A "fist" item (Shadow Fist) that lengthens the bare-handed strike: add its range only when
    -- `ab` is this unit's own hidden unarmed ability, so a crafted weapon's reach is untouched.
    if unit and unit.unarmedBonus and unit.unarmedBonus.range
        and unit.char.unarmed and ab == unit.char.unarmed.activeAbility then
        base = base + unit.unarmedBonus.range
    end
    local range = base + Combat.fieldRangeBonus(combat, ab and ab.requiresSight,
        x or unit.x, y or unit.y)
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
--
-- A neighbouring charm's `speedBonus` aura is folded in LAST and floored at 1: a Quickened Sigil buys
-- tempo back on the spell beside it, but no arrangement of the grid may ever make an action free. A
-- zero-speed cast would let a unit act, keep initiative 0, and act again forever -- the floor is what
-- makes that unreachable by arithmetic rather than by a rule anyone has to remember.
function Combat.actionSpeed(unit, ab, item)
    if not ab then return Combat.DEFAULT_SPEED end
    local base
    if ab.speedPreview then base = ab.speedPreview(unit, item)
    else base = ab.speed or Combat.DEFAULT_SPEED end
    local bonus = (unit and unit.char and item) and Combat.adjacencySpeedBonus(unit.char, item) or 0
    return math.max(1, base + bonus)
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
--   * "cone"             -- a triangle fanning out from (tx, ty): `length` rows deep along the facing,
--                           each row one tile wider to either side than the last (row 0 is the aimed
--                           cell alone, row 1 is 3 wide, row 2 is 5 wide -- a widening follow-through).
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

    -- A data-file footprint: cells too dynamic for radius/shape to describe (the Wolfsong Horn's howl
    -- reaches around BOTH the caster and her wolf). The function owns the geometry and is handed the
    -- caster for context; we still clamp to the board and de-dup here, so the preview highlight and
    -- fx.aoeUnits sweep one and the same set.
    if aoe and aoe.cells then
        local seen = {}
        for _, cell in ipairs(aoe.cells(combat, tx, ty, unit) or {}) do
            local key = cell.x .. ":" .. cell.y
            if not seen[key] then seen[key] = true; add(cell.x, cell.y) end
        end
        return cells
    end

    local shape = aoe and aoe.shape
    if shape == "line" or shape == "front" or shape == "cone" then
        local dx, dy = 0, 0
        if unit then dx, dy = stepToward(unit.x, unit.y, tx, ty) end
        if dx == 0 and dy == 0 then add(tx, ty) return cells end -- no facing: just the aimed cell
        local px, py = -dy, dx -- the facing rotated 90 degrees: the perpendicular (widening) axis
        if shape == "line" then
            local length = (aoe and aoe.length) or 1
            for i = 0, length - 1 do add(tx + dx * i, ty + dy * i) end
        elseif shape == "cone" then
            -- Rows deep along the facing; row i spans perpendicular offsets [-i, i], so the fan widens
            -- one tile each side per step out (Chebyshev cone). Duplicate cells can't occur -- each
            -- (i, j) maps to a distinct cell -- so no de-dup is needed.
            local length = (aoe and aoe.length) or 1
            for i = 0, length - 1 do
                local cx, cy = tx + dx * i, ty + dy * i
                for j = -i, i do add(cx + px * j, cy + py * j) end
            end
        else -- "front": a width-wide line perpendicular to the facing, centred on the aimed cell
            local width = (aoe and aoe.width) or 1
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
    local out, seen = {}, {}
    for _, c in ipairs(Combat.aoeCells(combat, ab, tx, ty, unit)) do
        local u = Combat.unitAt(combat, c.x, c.y)
        -- A wide body can lie under several of the blast's cells; it is caught ONCE. Dedup by the
        -- unit's stable index (every unit has one -- Combat.addUnit / addSide) so a 2×2 target in a
        -- fireball takes a single hit, not one per covered tile.
        if u and not seen[u.index] then seen[u.index] = true; out[#out + 1] = u end
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
    -- The meal the company ate before this quest (models/meal.lua), stamped onto the unit at spawn by
    -- battle setup. Folded in HERE, beside the grid, on purpose: a supper's +2 defense has to be the
    -- same quantity a coat's +2 is, or the damage breakdown, the mitigation maths and the loadout
    -- tooltip would each need a case of their own. Rebuilt from scratch every setup like everything
    -- above it, so the meal is re-eaten at each bell of the quest and never compounds across its fights.
    -- The platter's SKILL half is a trait instead (Trait.attach). Nil for every enemy, and for any
    -- battle fought without one.
    local meal = unit.meal
    if meal then
        for stat, amount in pairs(meal.bonus or {}) do
            unit.bonus[stat] = (unit.bonus[stat] or 0) + amount
        end
        for tag, amount in pairs(meal.resist or {}) do
            unit.resist[tag] = (unit.resist[tag] or 0) + amount
        end
        for stat, amount in pairs(meal.maxBonus or {}) do
            maxBonus[stat] = (maxBonus[stat] or 0) + amount
        end
    end
    unit.char.maxBonus = maxBonus
end

function Combat.applyPassives(combat)
    for _, unit in ipairs(combat.units) do applyUnitPassives(unit) end
end

-- The health an item wants to lock at setup: a share of the bearer's MAX health (item.healthReserve
-- .percent), floored the same way an ability's reserve reads its pool (Combat.abilityReserve). This is
-- the NOMINAL amount -- the never-lethal clamp against current health is applied where it is spent, in
-- applyReservations. Reading off max (not the maxBonus-raised ceiling) keeps the toll a fixed fraction of
-- the body itself, unmoved by whatever else is on the grid. The tooltip resolves the same number here.
function Combat.healthReserveAmount(char, item)
    local r = item and item.healthReserve
    if not r or not r.percent then return 0 end
    local hp = char.stats.health
    local max = (type(hp) == "table") and hp.max or (hp or 0)
    return math.floor(max * r.percent)
end

-- Item-carried health reservations: a fighter's guard charm (data/items/utility/utility_bloodlock_bracing.lua)
-- locks a share of its bearer's health away for the whole battle, and its `bonus` grants the armor that
-- lock buys. Runs once at setup, AFTER applyPassives has folded the defense/magicDefense in and Combat.new's
-- releaseClaims has cleared any stale reservation -- so the lock is re-taken fresh every battle and never
-- compounds. The bearer is its own holder: the reservation stands for as long as the unit is on the board,
-- which for its own fight is the whole of it, and releaseClaims frees it at the bell regardless. It is
-- never lethal and never larger than the bearer actually holds -- a fighter that walks in already wounded
-- reserves only down to its last point of life, exactly the floor Combat.canReserve keeps for health.
function Combat.applyReservations(combat)
    for _, unit in ipairs(combat.units) do
        for _, item in ipairs(Character.eachItem(unit.char)) do
            local want = Combat.healthReserveAmount(unit.char, item)
            if want > 0 then
                local hp = unit.char.stats.health
                local current = (type(hp) == "table") and hp.current or 0
                local amount = math.min(want, math.max(0, current - 1))
                if amount > 0 then Combat.reserve(unit.char, "health", amount, unit) end
            end
        end
    end
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

-- Does this unit ride the initiative timeline? Every real combatant does -- including a control-"none"
-- decoy, which must LOOK like a unit taking turns for the deception to work. A `timeless` unit does
-- not: it is scenery with health, a planted OBJECT rather than a body that acts (a banner). It stands
-- on the board, blocks its tile, takes damage and dies, but never takes a turn, never appears in the
-- turn order, and wears no turn number.
--
-- The single gate for all three: Combat.rebase's minimum, the turn order, and the timeline strip.
-- Rebase is the load-bearing one -- a unit that never acts is never charged an initiative, so leaving
-- one in the minimum would peg it at 0 forever, stop the clock, and freeze every duration in the
-- battle. Anything a timeless unit is meant to DO must therefore ride the clock rather than its turn:
-- a banner does nothing at all, and simply owns the ground that does the work (models/hazard.lua).
function Combat.inTimeline(unit)
    return unit ~= nil and unit.alive and not unit.timeless
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
-- duration (ticks it may stand before it fades; nil = until something kills it -- see Summon.tick),
-- timeless (an object, not a body: it stands outside the turn order entirely -- see Combat.inTimeline).
function Combat.addUnit(combat, char, side, x, y, opts)
    opts = opts or {}
    local fp = char.footprint or { w = 1, h = 1 }
    local unit = {
        char = char, side = side,
        x = x, y = y,
        -- Board footprint (from the blueprint, via Character.instantiate). The unit occupies the w×h
        -- block whose top-left corner is its anchor (x, y). 1×1 for every ordinary body.
        w = fp.w, h = fp.h,
        initiative = math.max(0, Combat.initiative(char)),
        speed = Combat.speed(char),
        alive = true,
        statuses = {},
        control = opts.control or (side == "party" and "player" or "ai"),
        summoner = opts.summoner,
        fragile = opts.fragile,
        summoned = opts.summoned,
        summonRemaining = opts.duration, -- nil for an indefinite summon; ticks down in rebase
        timeless = opts.timeless, -- stands outside the initiative timeline (Combat.inTimeline)
        -- Where this unit was put down. The AI's leashed postures measure from it (models/ai.lua:
        -- a `guard` holds a radius around its anchor, a `holdGround` never leaves it), so it has to
        -- be the tile it STARTED on and not wherever it happens to stand now.
        anchorX = x, anchorY = y,
        -- An enemy's own gold pool, spent by money abilities on the enemy side (Combat.spendPurse) --
        -- Aurea's interim coffer, until her full gold-ward finale subsystem lands (docs/roadmap.md #15).
        -- nil for anyone who is not a walking treasury; the party never uses this (it shares combat.purse).
        coffer = opts.coffer or char.coffer,
        -- Carried onto a body that ARRIVES mid-fight rather than starting on the board: a rotation off
        -- the bench brings the run's relic traits and the quest's meal back on with it (see sendIn).
        -- Both were dropped on the floor here until the meal needed the same seam -- which meant a
        -- benched member rotated in wearing none of the relics the rest of the line was wearing,
        -- against the promise in models/relic.lua's own header.
        relicTraits = opts.relicTraits,
        meal = opts.meal,
    }
    unit.index = #combat.units + 1
    combat.units[unit.index] = unit
    applyUnitPassives(unit)
    -- Traits are attached but their opener is NOT fired: a summon arriving mid-battle did not start
    -- the battle. Its reactive hooks (onDamaged / onCast / onDeath) are live from this moment.
    Trait.attach(unit, combat)
    return unit
end

-- The unit table a body takes when it is on the board FROM THE OPENING BELL -- built by Combat.new for
-- every side, and by Combat.deployUnit for a party member the player stands during the deployment phase.
-- Distinct from Combat.addUnit's arrival above in one way that matters: initiative is the char's natural
-- one, UNCLAMPED. A battle-start unit has no "current actor" to cut ahead of -- the opening spread is
-- normalized by the rebase in Combat.openBattle -- while an arrival must not jump the queue.
local function buildOpeningUnit(combat, u, side)
    local fp = u.char.footprint or { w = 1, h = 1 }
    local unit = {
        char = u.char, side = side,
        x = u.x, y = u.y,
        w = fp.w, h = fp.h, -- board footprint; see Combat.addUnit
        initiative = Combat.initiative(u.char),
        speed = Combat.speed(u.char), -- primary tie-break
        alive = true,
        statuses = {},
        -- Side implies control, except where the caller overrides it: an escorted
        -- ally fights on the party's side but runs itself (control = "ai"/"none").
        control = u.control or ((side == "party") and "player" or "ai"),
        anchorX = u.x, anchorY = u.y, -- start tile; the leashed AI postures measure from it
        -- An enemy's own gold pool for money abilities (Combat.spendPurse reads it) -- Aurea's
        -- coffer. Seated here as well as in Combat.addUnit, because a battle-start unit is built
        -- by this path and never passes through addUnit; nil for anyone but a treasury.
        coffer = u.coffer or u.char.coffer,
        -- Trait ids granted by the run's relics (models/relic.lua), resolved per-char by battle
        -- setup. Trait.attach folds them in alongside the char's own; nil for enemies.
        relicTraits = u.relicTraits,
        -- The meal blueprint the company ate before this quest (models/meal.lua), stamped by battle
        -- setup. One platter for the whole party, so unlike relicTraits it needs no per-char map.
        meal = u.meal,
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
    -- Every side, for the same reason the refill below is: a leftover reservation or summon
    -- claim belongs to whatever battle made it, and the only reason this was ever written as
    -- the party's business is that the party was the only side reusing instances that had
    -- been anywhere. Clearing nothing on a freshly instantiated enemy costs nothing.
    Combat.releaseClaims(unit.char)
    local st = unit.char.stats.stamina
    if type(st) == "table" then st.current = st.max end
    return unit
end

-- Stand a party member on the board during the DEPLOYMENT PHASE, before the battle opens
-- (states/battle.lua; docs/deployment.md). The same body Combat.new would have built inline, added to a
-- combat that was constructed with `deferOpen` and is therefore not yet open: no passives applied, no
-- opener fired, no rebase. Combat.openBattle does all of that once, for everyone, when the player commits.
--
-- Deliberately NOT Combat.addUnit: that one is for a body arriving into a fight already under way (a
-- summon, a reinforcement, a rotation), and it clamps initiative and skips the battle opener for exactly
-- that reason. A unit placed at the opening bell is not arriving; it is starting.
function Combat.deployUnit(combat, char, x, y, opts)
    opts = opts or {}
    return buildOpeningUnit(combat, {
        char = char, x = x, y = y,
        control = opts.control,
        relicTraits = opts.relicTraits,
        meal = opts.meal,
        coffer = opts.coffer,
    }, opts.side or "party")
end

-- Take a unit back OFF an unopened board -- the deployment phase's undo, when the player picks a placed
-- member back up. Only legal before Combat.openBattle: `combat.units` is append-only once the fight is
-- running (unit.index is a stable identity that AoE dedupe and the turn strip both key off), which is why
-- a mid-battle withdrawal flags the body instead of removing it (Combat.withdraw). Nothing has been
-- applied to this unit yet, so there is nothing to unwind. Returns true if it was there.
function Combat.undeployUnit(combat, unit)
    if combat.opened then return false end
    for i, u in ipairs(combat.units) do
        if u == unit then
            table.remove(combat.units, i)
            -- Re-stamp the indices the removal shifted, so index stays "position in combat.units".
            for j = i, #combat.units do combat.units[j].index = j end
            return true
        end
    end
    return false
end

-- Build combat state. partyUnits/enemyUnits are lists of { char = <instance>, x, y }
-- (exactly what states/battle.lua keeps as partyUnits/enemyUnits).
--
-- `opts.deferOpen` builds the board and STOPS before opening it: the world (traps, hazards, walls, props)
-- is laid down, but no passives are applied, no opener trait fires, and the timeline is not rebased. That
-- is what lets the deployment phase run on a real, drawable combat with no party on it yet -- the player
-- stands their company through Combat.deployUnit and Combat.openBattle finishes the job. Every other
-- caller passes nothing and gets a fully opened battle, exactly as before.
function Combat.new(arena, partyUnits, enemyUnits, opts)
    opts = opts or {}
    local combat = {
        arena = arena,
        objective = (arena and arena.objective) or { type = "killAll" },
        units = {},
        -- The side the local player is running, and so the side "win" and "loss" are spoken from.
        -- Always the party in campaign play; a duel sets it per machine, which is how one board
        -- reads as a victory to one player and a defeat to the other.
        playerSide = "party",
        -- Is there a PERSON on the other side of this board? True for a draft match and a duel, nil
        -- for every campaign fight. Only the AI reads it, and only to decide how hard to play: an
        -- opponent going for the body that ends the match is right, and a campaign enemy that walks
        -- past the party to swarm the one body the player cannot move is a fight nobody can defend
        -- (models/ai.lua, AI.spared). Set by whoever starts the fight -- states/battle.lua from
        -- `opts.draft` / `opts.session` -- because the combat model has no way to know on its own.
        versus = opts.versus or nil,
        -- This battle's own draw sequence, a function of the seed that built the board. Absent for
        -- a combat with no seeded arena (a scripted layout), which falls back to Combat.random.
        rng = (arena and arena.seed) and Combat.newRandom(arena.seed) or nil,
        clock = 0,      -- accumulated elapsed initiative (drives `survive`)
        -- Per-wave firing state for objective.waves ({ fires, nextAt, committed }), owned by whoever
        -- walks the waves on (states/battle.lua spawnWaves). It lives HERE rather than in the battle
        -- state because "has that reinforcement arrived yet?" is a question the win conditions ask
        -- (Combat.allWavesArrived) -- and once a wave can be pulled forward off its authored tick, the
        -- clock is no longer an honest answer to it.
        waveState = {},
        turnCount = 0,  -- number of actions taken
        turn = nil,     -- the in-progress turn: { unit, moved, moveCost } (see startTurn)
        log = {},       -- rolling event log for the combat-log panel (Combat.logEvent)
        -- The company members standing off the board, ready to rotate in. Seeded by battle setup from
        -- whoever the player did NOT deploy; see the bench section below and docs/deployment.md.
        bench = {},
        -- Tiles the player may stand a body on: the deployment phase places here, and a rotation and a
        -- reinforcement both happen here too. One geometry, three uses. Set by battle setup from
        -- arena.deployZone; nil for a combat built without one (a duel, a test), which simply refuses
        -- to rotate rather than offering the whole board.
        deployZone = arena and arena.deployZone or nil,
        opened = false, -- Combat.openBattle has run; see Combat.new's `deferOpen`
    }

    local function addSide(list, side)
        for _, u in ipairs(list or {}) do buildOpeningUnit(combat, u, side) end
    end
    addSide(partyUnits, "party")
    addSide(enemyUnits, "enemy")

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

    -- Props: the board's own furniture (models/prop.lua) -- barrels and crates the map generator
    -- scattered off the biome (Arena.generateLayout), or a curated map authored by hand. Sideless, so
    -- there is nothing to tag them with; in-combat placement adds more via fx.placeProp. Placed AFTER
    -- the walls so the two layers can't both claim a tile, and after the units so a scatter that landed
    -- on a spawn is quietly dropped rather than burying somebody under a crate.
    combat.props = {}
    for _, p in ipairs((arena and arena.props) or {}) do
        Prop.place(combat, p.x, p.y, p.id, { amount = p.amount, health = p.health })
    end

    if not opts.deferOpen then Combat.openBattle(combat) end
    return combat
end

-- Ring the opening bell on a built board: normalize the timeline, apply everyone's passives, and fire
-- the battle openers. Everything here is about WHO IS STANDING, which is why it is separable from
-- Combat.new at all -- a battle built with `deferOpen` has its ground but not its party, and the
-- deployment phase (states/battle.lua) calls this once the player commits.
--
-- Idempotent by the `opened` flag: an opener that fired once must never fire twice (Envy would copy the
-- party's strongest unit a second time), and a second rebase would bank the normalization offset as
-- elapsed time.
function Combat.openBattle(combat)
    if combat.opened then return combat end
    combat.opened = true

    -- Rebase so the fastest unit starts at initiative 0 (the current-actor convention). The
    -- initial offset isn't elapsed battle time, so reset the clock to 0 afterwards -- and flag the
    -- call, so the objective counters don't bank that offset either (see Combat.rebase).
    Combat.rebase(combat, true)
    combat.clock = 0
    Combat.applyPassives(combat)
    Combat.applyReservations(combat)

    -- Passives (above) established each unit's resource ceilings, including any Endurance/Attunement
    -- raise. Stamina refills to its full effective ceiling for the party here -- the unit build topped it
    -- to the BASE max before maxBonus existed, so a fresh battle's stamina pool includes the bonus.
    -- Mana is deliberately left where it stood (it persists between battles); the extra mana ceiling
    -- is headroom to recover into, exactly like the extra health ceiling.
    -- Every unit, not just the party's. This reads to its full EFFECTIVE ceiling, so it is only a
    -- no-op for the other side while no enemy carries a stamina maxBonus -- none does today, and
    -- Endurance's own promise is "refills to its full effective ceiling at the start of each
    -- battle", which was never meant to be a promise made to the party alone. The narrow rule was
    -- an accident that cost nothing while every enemy was instantiated fresh at full stamina; it
    -- stops costing nothing the moment the far side of the board is somebody's real roster, which
    -- is a duel -- those units would take the field already short of wind.
    for _, unit in ipairs(combat.units) do
        local st = unit.char.stats.stamina
        if type(st) == "table" then st.current = Combat.unreservedMax(unit.char, "stamina") end
    end

    -- Censers lay the ground they carry (Combat.layIncense), and it has to happen AFTER the hazard table
    -- exists (Combat.new builds it) and after the rebase above, which would otherwise throw the cloud
    -- away a moment after it was laid. From here on the bearer keeps it -- from Combat.enterTile as they
    -- move, and from Combat.rebase for one who never does.
    for _, unit in ipairs(combat.units) do
        Combat.layIncense(combat, unit)
    end

    -- Authored traps were placed WITHOUT logging (they're hidden until detected); the log
    -- opens on a clean "battle begins" line so the panel isn't empty on the first frame.
    Combat.logEvent(combat, "system", "The battle begins.")

    -- Last, so an opener that reads or reshapes the field (Envy copying your strongest unit) finds
    -- every unit, passive, trap and hazard already in place. Its lines follow the "battle begins".
    Trait.setup(combat)

    return combat
end

-- Subtract the lowest living initiative from every living unit so the next actor sits at 0,
-- and add that amount to the elapsed clock. Called at construction and after each turn ends.
--
-- `initial` marks that construction call. Its offset is a NORMALIZATION of the starting initiative
-- spread, not elapsed battle time -- Combat.new resets the clock to 0 the line after -- so no objective
-- counter may bank it. Without the guard, a field whose fastest unit opens on a negative initiative
-- (Combat.initiative subtracts the speed stat, and a battle-start unit is not clamped the way
-- Combat.addUnit's later arrivals are) banks that negative tick to whoever stands on the objective
-- ground, off a momentarily NEGATIVE clock -- which points controlNodeIndex at the wrong waypoint too,
-- and records a lastHolder that never held anything. That is how a draft battle opened with the player
-- already on minus points.
function Combat.rebase(combat, initial)
    local minInit
    for _, u in ipairs(combat.units) do
        if Combat.inTimeline(u) and (not minInit or u.initiative < minInit) then minInit = u.initiative end
    end
    if not minInit then return end
    for _, u in ipairs(combat.units) do
        if Combat.inTimeline(u) then u.initiative = u.initiative - minInit end
    end
    combat.clock = combat.clock + minInit
    if not initial then
        -- Bank the same elapsed time toward a `hold` objective, if the party held the ground across it.
        -- Here rather than in Combat.evaluate because this is the only place that knows how much time
        -- passed; evaluate runs per action and cannot tell a long one from a short one.
        Combat.accrueHold(combat, minInit)
        -- The multiplayer `control` objective banks the same elapsed time toward whichever side held the
        -- moving score node across it. Same reasoning as accrueHold: rebase is the only place that knows
        -- how much time just passed. Both are no-ops unless the arena authored that objective.
        Combat.accrueControl(combat, minInit)
    end
    -- Re-lay every censer's smoke around its bearer BEFORE the zone cycle below. This is the half that
    -- movement cannot cover: Combat.enterTile keeps the cloud under a bearer that walks, but a bearer
    -- that never moves needs its ground to still be there when Hazard.tick asks who is standing in
    -- what -- and this runs at construction too, so the smoke is up before the first turn is taken.
    for _, u in ipairs(combat.units) do
        if u.alive then Combat.layIncense(combat, u) end
    end
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
-- silent until it counts back to 0 -- the countdown Combat.tickCooldowns runs from rebase, beside
-- Status.tick. Deliberately generic: any future "once every N ticks" effect hangs its key here
-- rather than inventing its own clock.
-- ---------------------------------------------------------------------------

-- Put `key` on cooldown for `ticks` on `unit` (refreshes to the longer of any existing remaining).
function Combat.setCooldown(unit, key, ticks)
    unit.cooldowns = unit.cooldowns or {}
    unit.cooldowns[key] = math.max(unit.cooldowns[key] or 0, ticks or 0)
end

-- Wipe every standing cooldown on `unit` and report how many there were. The one thing in this
-- game that gives an action BACK rather than making one bigger (data/items/utility/utility_hour_
-- returned.lua) -- and the reason it is worth its own helper is that "a cooldown" here is one table
-- keyed two ways: a trait's own id, and an item's reflex key (see Combat.itemCooldown). A refresh that
-- knew about only one of those would silently leave half a kit still cooling.
function Combat.clearCooldowns(unit)
    if not (unit and unit.cooldowns) then return 0 end
    local n = 0
    for key in pairs(unit.cooldowns) do
        unit.cooldowns[key] = nil
        n = n + 1
    end
    return n
end

-- Is `key` still on cooldown on `unit`? False once it has counted back to 0 (or was never set).
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

-- Is `item`'s reflex still on cooldown on `unit`, and how far along? A cooldown is keyed on the
-- trait's id and the trait remembers the item that granted it (Trait.instantiate), so this walks the
-- bearer's traits back to the slot they came from -- the read the item grid needs to say "this blade
-- cannot parry again yet". The longest remaining wins when one item grants several reflexes: the slot
-- is ready only once all of them are. Returns nil for a ready item, else:
--   { remaining = ticks left, total = the full cooldown, trait = the reflex that is spent }
-- `total` comes off the def's declared `cooldown` -- never `magnitude`, which on some traits is the
-- effect's own size (the Stayed Hand's health fraction) and would report a nonsense fraction. It is
-- floored at `remaining`, so a def whose cooldown was raised mid-battle can't report above 1.
function Combat.itemCooldown(unit, item)
    if not unit or not item or not unit.traits then return nil end
    local best
    for _, t in ipairs(unit.traits) do
        if t.item == item then
            local left = unit.cooldowns and unit.cooldowns[t.id]
            if left and left > 0 and (not best or left > best.remaining) then
                best = { remaining = left, total = math.max(t.def.cooldown or left, left), trait = t }
            end
        end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- Per-unit event tallies & signature unlocks. A signature ability may gate itself behind a
-- requirement fulfilled DURING the battle -- land N blows, heal N times, take N hits, live to a
-- later turn -- rather than (or as well as) a resource cost. Each qualifying event is counted here
-- on the unit that caused it, cumulative for the battle; the unit wrapper is rebuilt each
-- Combat.new, so every tally starts at 0 and resets for free. Read by Combat.unlockMet to open a
-- locked ability, and by the item grid to show its progress. The event names are a small vocabulary
-- an ability's `unlock.event` draws from, tallied at the seams where each already passes:
--   hitDealt / damageDealt  -- landed a damaging blow          (Combat.dealDamage)
--   hitTaken / damageTaken  -- ate a blow and lived            (raiseAnswer)
--   kill                    -- felled a foe                    (Combat.dealFlatDamage kill branch)
--   allyDown                -- an ally of this unit fell        (killUnit)
--   healDone                -- healed someone                  (the cast's fx.heal)
--   cast                    -- committed to an ability         (Combat.useItem)
--   turnTaken               -- began a turn                    (Combat.startTurn)
--   companionDamage         -- a summon of this unit drew blood (Combat.dealDamage)
--   allyStruck              -- a blow landed on the ally beside it (Combat.dealDamage)
--   unarmedHit              -- landed a blow with its own fists   (Combat.dealDamage)
--   repeatStrike            -- struck the same body twice running (Combat.dealDamage)
--   answered                -- turned a blow aside / countered    (Trait's tallyAnswer)
--   foeDown                 -- an enemy of this unit fell         (killUnit)
--   allyHealed              -- someone on its side was healed     (Combat.applyHeal)
-- ---------------------------------------------------------------------------

-- Add `n` (default 1) to `unit`'s running count of `event`. Nil-safe on both the unit and its
-- lazily-created table, so a seam can call it without checking whether the unit tracks anything yet.
function Combat.tally(unit, event, n)
    if not unit then return end
    unit.tally = unit.tally or {}
    unit.tally[event] = (unit.tally[event] or 0) + (n or 1)
end

-- How many of `event` `unit` has racked up this battle (0 if none).
function Combat.tallyCount(unit, event)
    return (unit and unit.tally and unit.tally[event]) or 0
end

-- CHI: the monk's charge, and the one tally that is a spendable POOL rather than a running total.
--
-- Every tally above is monotonic on purpose -- "how many blows have you landed this battle" is a
-- question whose answer never goes down -- and the signature system reads it through a PER-ITEM
-- baseline (unit.unlockBase) so each relic counts from where it last fired. That is exactly wrong for
-- chi, which has to be ONE pool shared by every monk ability: a Flurry and an Asura Strike must draw on
-- the same charge, or "spend your chi" means a different thing in each file.
--
-- So chi keeps a single baseline on the unit (`chargeSpent.chi`) rather than a per-item one, and is DERIVED
-- rather than stored: banked unarmed blows less what has been spent. Combat.dealDamage banks
-- "unarmedHit" only for a blow thrown with the bearer's own fists, so chi is built by punching and by
-- nothing else -- a monk who picks up a sword stops charging.
--
-- CAPPED, because a charge that grew all battle would make the last turn of a long fight the only one
-- that mattered. Overflow past the cap is simply never banked -- landing another punch on a full pool
-- wastes it, which is the pressure that makes spending it a decision.
Combat.CHI_MAX = 10

-- The pools the ENGINE defines, rather than an item. Exactly one: chi predates the general mechanism
-- below and its source is a fact about the body (bare hands), not about anything you can buy -- there
-- is no fist charm to declare it on, and a monk who owns no charms still charges. Everything else
-- declares its own pool in data (see Combat.chargeDef).
Combat.CHARGE_DEFS = {
    chi = { from = { "unarmedHit" }, max = Combat.CHI_MAX },
}

-- One free action per turn. The resource cost on a free ability bounds how often you can AFFORD to
-- press it, never how often you can press it -- a free ability priced at nothing would loop forever,
-- and even a priced one turns a full stamina bar into an unanswerable burst. Tracked on the unit and
-- cleared in Combat.startTurn (see resolveCast and Combat.itemBlockReason).
Combat.FREE_ACTIONS_PER_TURN = 1

-- The tags that count as an ELEMENT for the purposes of "what did you last throw" (the Battlemage's
-- Resonant Grip). A closed set rather than "any tag on the cast": a strike must not start carrying
-- `utility` or `charm` around, and armour `resist` is keyed on exactly these words, so widening the set
-- would quietly change what plate turns aside.
Combat.ELEMENT_TAGS = {
    fire = true, ice = true, lightning = true, water = true,
    dark = true, holy = true, acid = true, poison = true,
}

-- How many free actions `unit` has left this turn. The single reader for both the spend in resolveCast
-- and the grey-out in Combat.itemBlockReason, so the button and the rule can never disagree.
function Combat.freeActionsLeft(unit)
    if not unit then return 0 end
    return math.max(0, Combat.FREE_ACTIONS_PER_TURN - (unit.freeActionsUsed or 0))
end

-- The merged definition of pool `key` for this unit: every item in the grid that declares
-- `charge = { key = ..., from = ..., max = ... }`, folded together with the engine's own defs.
--
-- Merged rather than first-wins so a second charm can DEEPEN a pool instead of opening a rival one:
-- `from` unions (Crusader's Tabard banks Zeal on kills, Vow of the March adds nearby heals, and a
-- Crusader holding both banks on either) and the highest `max` wins. Two items disagreeing about what
-- a pool is would otherwise mean "your zeal" named a different number in each file -- the exact bug
-- chi's single-baseline design exists to avoid.
--
-- Returns nil when nothing declares the key: no charm, no pool. That is the discipline contract doing
-- its job (the mechanic rides on the item), and it is why Combat.charge answers 0 rather than erroring.
function Combat.chargeDef(unit, key)
    local builtin = Combat.CHARGE_DEFS[key]
    local from, max = nil, nil
    if builtin then
        from = {}
        for _, t in ipairs(builtin.from) do from[t] = true end
        max = builtin.max
    end
    if unit and unit.char then
        for _, item in ipairs(Character.eachItem(unit.char)) do
            local c = item.charge
            if c and c.key == key then
                from = from or {}
                -- `from` may be a single tally name or a list of them; both read the same way here.
                if type(c.from) == "table" then
                    for _, t in ipairs(c.from) do from[t] = true end
                elseif c.from then
                    from[c.from] = true
                end
                if c.max and (not max or c.max > max) then max = c.max end
            end
        end
    end
    if not from then return nil end
    return { from = from, max = max or Combat.CHI_MAX }
end

-- What `unit` currently holds of pool `key`: floored at 0, capped at the pool's max.
--
-- DERIVED rather than stored, exactly as chi always was -- banked tallies less what has been spent --
-- so nothing has to remember to credit the pool at the moment a blow lands. Capped, because a charge
-- that grew all battle would make the last turn of a long fight the only one that mattered; overflow
-- past the cap is simply never banked, which is the pressure that makes spending it a decision.
--
-- `chargePool` rather than `charge` because Combat.charge is already the Charge ABILITY -- pinning a
-- body and driving it down the lane. Two unrelated meanings of one short word, and the older one has
-- an ability file and an fx helper named after it; the pool takes the longer name rather than shadow
-- a working function. (This is not hypothetical: it shadowed it for one test run.)
function Combat.chargePool(unit, key)
    if not unit then return 0 end
    local def = Combat.chargeDef(unit, key)
    if not def then return 0 end
    local banked = 0
    for tally in pairs(def.from) do
        banked = banked + Combat.tallyCount(unit, tally)
    end
    local spent = (unit.chargeSpent and unit.chargeSpent[key]) or 0
    return math.max(0, math.min(banked - spent, def.max))
end

-- Display names for the pools, for the badge and tooltip row that quote them. A pool the table does
-- not name falls back to its capitalised key, so a new pool is legible the day it is declared and
-- only needs an entry here when the key is not the word the player should read.
Combat.CHARGE_LABEL = {
    chi = "Chi", zeal = "Zeal", arcane = "Arcane", defiance = "Defiance", tempo = "Tempo",
}

function Combat.chargeLabel(key)
    if not key then return nil end
    return Combat.CHARGE_LABEL[key] or (key:sub(1, 1):upper() .. key:sub(2))
end

-- Which pool does this item traffic in, if any -- the key whose count its badge and tooltip should
-- quote. Two sources, because banking and spending are declared in different places:
--
--   `item.charge.key`        -- the item DECLARES (or deepens) the pool. Every banker names itself
--                               here, and so does every spender, since a spender that banked nothing
--                               would be inert until you happened to own the banker too.
--   `activeAbility.spendsCharge` -- the item only SPENDS a pool it cannot declare. Exactly one pool is
--                               like that: chi's source is the body rather than anything you can buy
--                               (Combat.CHARGE_DEFS), so a fist ability has nothing to declare and
--                               would otherwise show no count at all.
--
-- The rule this exists to serve: a resource that accrues has to be readable. A pool the player cannot
-- see the size of is a pool they cannot decide about -- whether to spend now or bank one more turn is
-- the whole of what these items ask, and it is unanswerable off a hidden number.
function Combat.itemChargeKey(item)
    if not item then return nil end
    if item.charge and item.charge.key then return item.charge.key end
    local ab = item.activeAbility
    return ab and ab.spendsCharge or nil
end

-- What `unit` holds of `item`'s pool, and the pool's ceiling: `count, max, label`, or nil when the
-- item traffics in no pool. The ceiling comes from the MERGED def (Combat.chargeDef), so a Crusader
-- wearing two Zeal charms is quoted the deeper cap both of them actually bank into -- not the one
-- printed in whichever file the badge happened to read.
function Combat.itemChargeReadout(unit, item)
    local key = Combat.itemChargeKey(item)
    if not key then return nil end
    local def = Combat.chargeDef(unit, key)
    local max = def and def.max
    if not max then
        -- Nobody to merge against -- a shop shelf, an Armory row with no member picked. Fall back to
        -- the ceiling the item declares for itself, so the count is still quotable off the board: what
        -- a thing banks INTO is a fact about the thing, and a buyer is deciding on exactly that.
        local builtin = Combat.CHARGE_DEFS[key]
        max = (item.charge and item.charge.max) or (builtin and builtin.max)
    end
    if not max then return nil end
    return Combat.chargePool(unit, key), max, Combat.chargeLabel(key)
end

-- Spend `n` of pool `key` (default: ALL of it), returning how much was actually spent.
--
-- Spending ALL of it moves the baseline to the whole tally rather than subtracting the capped figure,
-- so a pool that had overflowed past the cap is emptied outright and cannot leave a hidden remainder
-- behind. A partial spend just advances the baseline by what it took.
--
-- Mutating, so an ability effect must reach it through `fx.spendCharge` and never call it directly:
-- the damage preview runs effects too, and a pool that emptied itself under the cursor would be a bug
-- that read as one (the same rule the coatings follow -- see Combat.auraSpent).
function Combat.spendCharge(unit, key, n)
    if not unit then return 0 end
    local have = Combat.chargePool(unit, key)
    unit.chargeSpent = unit.chargeSpent or {}
    if not n then
        local def = Combat.chargeDef(unit, key)
        local banked = 0
        if def then
            for tally in pairs(def.from) do banked = banked + Combat.tallyCount(unit, tally) end
        end
        unit.chargeSpent[key] = banked
        return have
    end
    local take = math.max(0, math.min(n, have))
    unit.chargeSpent[key] = (unit.chargeSpent[key] or 0) + take
    return take
end

-- Empty pool `key` outright without spending it on anything: the baseline jumps to whatever is banked,
-- so the charge is gone rather than merely capped. What a pool declaring `resetOn` loses when its
-- condition breaks -- the Duelist's Tempo evaporating the moment the blade finds a different throat.
--
-- Deliberately NOT the same call as spendCharge(unit, key): a spend hands back what it took so an
-- effect can scale off it, while this is a forfeit and returns nothing, and a reader that confuses the
-- two would silently pay out for a pool that was thrown away.
function Combat.resetCharge(unit, key)
    if not unit then return end
    local def = Combat.chargeDef(unit, key)
    if not def then return end
    local banked = 0
    for tally in pairs(def.from) do banked = banked + Combat.tallyCount(unit, tally) end
    unit.chargeSpent = unit.chargeSpent or {}
    unit.chargeSpent[key] = banked
end

-- Every pool in `unit`'s grid that declares `resetOn = reason`, emptied. Data-declared rather than
-- named in the engine: combat.lua must not know what "tempo" is, only that some pool asked to be
-- forfeit when a streak breaks. A new discipline can invent its own condition without touching this.
function Combat.resetChargesOn(unit, reason)
    if not (unit and unit.char) then return end
    for _, item in ipairs(Character.eachItem(unit.char)) do
        local c = item.charge
        if c and c.key and c.resetOn == reason then Combat.resetCharge(unit, c.key) end
    end
end

-- Chi, kept as its own name because two dozen monk files and the battle UI call it that. It is now the
-- general mechanism above with a built-in definition, so the monk shelf did not change and does not
-- know it moved.
function Combat.chi(unit) return Combat.chargePool(unit, "chi") end
function Combat.spendChi(unit, n) return Combat.spendCharge(unit, "chi", n) end

-- The battle PURSE: the player's campaign gold, made spendable inside a fight so the greed (rogue)
-- money kit can turn coin into damage (fx.spendPurse). It is INJECTED, never required: states/battle.lua
-- hands combat a `combat.purse = { get = fn, spend = fn }` over models/player for a campaign fight, and
-- for nothing else -- a duel spends the ladder's stakes, a draft run spends DraftRun's own pool. So
-- combat.lua stays ignorant of progression, and a money ability outside the campaign simply finds no
-- purse: purseAvailable returns 0 and spendPurse takes nothing, so the ability spends nothing and does
-- nothing, exactly the way a chi-dump on a unit that never banked any is inert rather than an error.
--
-- SIDE-AWARE. The party shares one bank (the injected `combat.purse`). An ENEMY draws on its own
-- `unit.coffer` instead -- a body like Aurea, general of Greed, is a walking treasury, not a shareholder
-- in your gold -- so the caster's side decides which pot a money ability reaches, and the two never
-- touch. `unit` is optional; with none, or a party caster, it is the shared purse.
function Combat.purseAvailable(combat, unit)
    if unit and unit.side ~= "party" then return unit.coffer or 0 end
    local p = combat and combat.purse
    return (p and p.get()) or 0
end

-- Spend up to `n` gold from the caster's purse (all of it when n is nil), and hand back what was ACTUALLY
-- taken -- the same shape as Combat.spendChi, so a money ability scales its payoff off the return. Clamped
-- to what is on hand, so a broke party spends its last coppers and the blow simply lands soft. An enemy
-- spends its own coffer (see purseAvailable). Reached from an effect ONLY through fx.spendPurse and never
-- here directly: the damage preview runs effects against an inert context, and a purse that emptied itself
-- under the cursor would be a bug that read as one -- the rule chi, the charge pools and the coatings keep.
function Combat.spendPurse(combat, unit, n)
    local avail = Combat.purseAvailable(combat, unit)
    local take = n and math.max(0, math.min(n, avail)) or avail
    if take > 0 then
        if unit and unit.side ~= "party" then
            unit.coffer = (unit.coffer or 0) - take
        else
            combat.purse.spend(take)
        end
        Combat.logEvent(combat, "system",
            string.format("%s spends %dg.", unitName(unit), take), unit)
    end
    return take
end

-- Verb fragments for the auto-generated lock label, when an unlock declares no `text` of its own.
local UNLOCK_LABELS = {
    hitDealt = "Land", damageDealt = "Deal", hitTaken = "Weather", damageTaken = "Soak",
    kill = "Fell", allyDown = "Lose", healDone = "Heal", cast = "Cast", turnTaken = "Hold",
}

-- Evaluate a raw `unlock` descriptor for `unit`, with per-`key` baseline bookkeeping. `key` is
-- whatever OWNS the unlock -- an item instance for an active signature (gated through
-- Combat.itemBlockReason), a trait instance for a reactive one (gated from its hook via ctx.unlockMet)
-- -- so the two never share a baseline. Returns `met`, plus the current/target counts for a progress
-- badge (nil counts for a board-state `when` predicate, which is a yes/no rather than a tally). Pure:
-- safe for the item scan, previews and the AI. A nil unlock is always met. `combat` is optional --
-- only a `when` predicate reading the board needs it; count-based unlocks ignore it.
function Combat.unlockReady(unit, unlock, key, combat)
    if not unlock then return true end
    -- A `once` signature that has already opened stays open the rest of the battle.
    if unlock.once and unit and unit.unlockOpen and unit.unlockOpen[key] then return true, 1, 1 end
    -- A board-state predicate (HP threshold, an adjacent foe, a living companion) gates the ability.
    local gateOk = (not unlock.when) or (unlock.when(unit, combat) and true or false)
    -- A pure `when` (no count) is the whole yes/no test. Alongside a `count` the gate must ALSO pass
    -- for the charge to fire -- the Wolfsong Horn is charged by the wolf's blows AND only while the
    -- wolf still stands.
    if unlock.when and not unlock.count then
        return gateOk
    end
    local count = unlock.count or 1
    local base = (unit and unit.unlockBase and unit.unlockBase[key]) or 0
    local progress = math.max(0, Combat.tallyCount(unit, unlock.event) - base)
    return (gateOk and progress >= count), math.min(progress, count), count
end

-- Has `unit` met the unlock requirement on `item`'s ability? Thin wrapper over Combat.unlockReady
-- keyed by the item instance -- the read Combat.itemBlockReason and the grid badge use.
function Combat.unlockMet(unit, item, combat)
    local ab = item and item.activeAbility
    return Combat.unlockReady(unit, ab and ab.unlock, item, combat)
end

-- The label a locked ability's grid badge and tooltip show, with progress. Uses the unlock's own
-- `text` when given, else builds one from the event verb and count. Returns `label, met`.
function Combat.unlockLabel(unit, item, combat)
    local ab = item and item.activeAbility
    local unlock = ab and ab.unlock
    if not unlock then return nil, true end
    local met, cur, total = Combat.unlockMet(unit, item, combat)
    local base = unlock.text
    if not base then
        if unlock.when then base = "Not ready"
        else base = string.format("%s %d", UNLOCK_LABELS[unlock.event] or unlock.event, unlock.count or 1) end
    end
    if total then return string.format("%s (%d/%d)", base, cur or 0, total), met end
    return base, met
end

-- Fire-time bookkeeping for a raw unlock, keyed like Combat.unlockReady: a repeatable unlock
-- rebaselines to the current tally (so the requirement must be met AGAIN before the next use -- the
-- cooldown feel), while a `once` unlock latches open for the rest of the battle. A `when`-gated or
-- absent unlock needs nothing. The shared core of Combat.unlockConsume (and ctx.unlockConsume).
function Combat.unlockSpend(unit, unlock, key)
    if not unlock or unlock.when then return end
    if unlock.once then
        unit.unlockOpen = unit.unlockOpen or {}
        unit.unlockOpen[key] = true
    else
        unit.unlockBase = unit.unlockBase or {}
        unit.unlockBase[key] = Combat.tallyCount(unit, unlock.event)
    end
end

-- Re-lock (or latch open) an active signature after `unit` commits to using `item`. Keyed by the
-- item instance. Called from Combat.useItem after the cost is paid, so it never fires on a refused
-- or previewed action.
function Combat.unlockConsume(unit, item)
    local ab = item and item.activeAbility
    Combat.unlockSpend(unit, ab and ab.unlock, item)
end

-- Mana regenerated per tick by an Arcane Reservoir bearer -- the lone exception to "mana never
-- regenerates". Everyone else's rate is zero, so the global rule holds; the trait is what bends it.
Combat.ARCANE_REGEN = 1
-- Stamina per tick for a character whose blueprint declares no `staminaRegen` (see Combat.regenerate).
-- The party's own sheets declare 1-3; this is the floor an unstated one falls back to.
Combat.DEFAULT_STAMINA_REGEN = 1
-- Health an adjacent Sanctified Presence restores per tick, to each ally it wards (and to the priest).
Combat.SANCTIFY_HEAL = 1
-- Health an Unspent Heart restores per tick to a wearer nobody has touched lately. Several times the
-- priest's rate, and that gap is the item: this is the only recovery in the game that can be switched
-- off by hitting somebody, so it is allowed to be worth switching off.
Combat.UNSPENT_HEART_REGEN = 4

-- Is `u` warded by a Sanctified Presence this tick? True if it bears the trait itself (the priest is
-- its own font) or stands orthogonally adjacent to a living ally that does.
local function nearSanctifier(combat, u)
    if Trait.has(u, "trait_sanctified_presence") then return true end
    for _, o in ipairs(combat.units) do
        if o.alive and o ~= u and o.side == u.side and Trait.has(o, "trait_sanctified_presence")
            and Combat.unitGap(o, u) == 1 then
            return true
        end
    end
    return false
end

-- Passive recovery each rebase: every living unit regains its staminaRegen rate per elapsed tick
-- (clamped to max). Mana deliberately does NOT regenerate -- except for an Arcane Reservoir bearer.
-- A unit under a Sanctified Presence also heals a little health. Called from rebase with the ticks
-- that just elapsed (the same amount fed to Status.tick), so recovery scales with time on the clock.
function Combat.regenerate(combat, elapsed)
    if not elapsed or elapsed <= 0 then return end
    for _, u in ipairs(combat.units) do
        if u.alive then
            -- A blueprint that never mentions staminaRegen gets the baseline rather than zero. Most
            -- enemy characters don't declare one, and since answering a blow is now paid for in
            -- stamina and nothing else (see Trait.answerCost), a silent zero would hand every one of
            -- them a strictly finite number of counters per battle that nobody authored. An explicit
            -- 0 is still honoured -- that is a real authoring choice, and the specs rely on it.
            local rate = flatStat(u, "staminaRegen")
            if u.char.stats.staminaRegen == nil then rate = rate + Combat.DEFAULT_STAMINA_REGEN end
            Combat.restoreResource(u.char, "stamina", rate * elapsed)
            -- Quiet heals (no per-tick log line, like stamina): the badge/aura is the tell, not the log.
            if Trait.has(u, "trait_arcane_reservoir") then
                Combat.restoreResource(u.char, "mana", Combat.ARCANE_REGEN * elapsed)
            end
            if nearSanctifier(combat, u) then
                Combat.restoreResource(u.char, "health", Combat.SANCTIFY_HEAL * elapsed)
            end
            -- The Unspent Heart: a much larger recovery that is only paid while its wearer has been
            -- left alone. The trait's own onDamaged puts its id on cooldown for every wound
            -- taken, so the rate here is simply gated on that timer having run out -- which is the
            -- whole mechanic, and why the trait file itself has nothing in it but the shutting.
            --
            -- Sits with the recoveries rather than in the trait because this is where recovery lives:
            -- a trait has no per-tick hook (and deliberately shouldn't -- see models/trait.lua), and a
            -- status would put a countdown on the badge row that told the enemy exactly when the heart
            -- comes back.
            if Trait.has(u, "trait_unspent_heart") and not Combat.onCooldown(u, "trait_unspent_heart") then
                Combat.restoreResource(u.char, "health", Combat.UNSPENT_HEART_REGEN * elapsed)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

-- The living unit whose BODY covers (x, y) -- for a big unit, any of its footprint cells, not just
-- its anchor. This is the engine's one occupancy question: pathing block-checks, forced-movement
-- collision, spawn placement, click-to-select and AoE all route through it, so making it read the
-- whole footprint is what lets a 2×2 body block, be selected, and be hit from any of its four cells.
-- A 1×1 unit's single cell is its anchor, so this is exactly the old x==,y== test for them.
function Combat.unitAt(combat, x, y)
    for _, u in ipairs(combat.units) do
        if u.alive then
            local w, h = u.w or 1, u.h or 1
            if x >= u.x and x <= u.x + w - 1 and y >= u.y and y <= u.y + h - 1 then
                return u
            end
        end
    end
    return nil
end

-- The standing OBJECT on (x, y) -- a conjured wall (models/wall.lua) or a scattered prop
-- (models/prop.lua) -- as (object, kind), or nil. Two layers, one question: something with HP is
-- standing on that tile and it is not a body. Every caller that cares whether the way is barred, what a
-- shove slams into, or what a line of sight crosses asks through this pair rather than naming the
-- layers itself, so a third kind of standing object would be wired in one place.
function Combat.objectAt(combat, x, y)
    local w = Wall.at(combat, x, y)
    if w then return w, "wall" end
    local p = Prop.at(combat, x, y)
    if p then return p, "prop" end
    return nil
end

-- Does a standing object bar movement onto (x, y)? The gate every path, reach, shove and blink reads.
-- A wall's `blocksMove` and a prop's are the same field asked of two layers.
function Combat.objectBlocksAt(combat, x, y)
    return Wall.blocksAt(combat, x, y) or Prop.blocksAt(combat, x, y)
end

-- Damage whatever standing object `obj` is, in its own layer's currency. The one place a caller that
-- has an object without knowing its kind (a collision, a hurl) can hurt it.
function Combat.damageObject(combat, obj, kind, amount, source)
    if not (obj and obj.alive) then return 0 end
    if kind == "prop" then return Prop.damage(combat, obj, amount, source) end
    if kind == "trap" then return Trap.damage(combat, obj, amount) end
    return Wall.damage(combat, obj, amount)
end

-- The object on (x, y) that can be PICKED UP AND THROWN, as (object, kind) -- a prop or a trap, in
-- that order, or nil. A wall is deliberately absent: a conjured barrier is anchored where it was
-- raised, and a thing you can carry off is a thing you could have walked around.
--
-- A trap only answers to a `side` that can SEE it (Trap.visibleTo): you cannot heave what you have not
-- found, and letting a throw grab a hidden trap would leak the detect-traps mechanic exactly as
-- surfacing an enemy placement in the log would. Omitting `side` skips the check (an effect that
-- already knows what it is holding).
function Combat.throwableAt(combat, x, y, side)
    local p = Prop.at(combat, x, y)
    if p then return p, "prop" end
    local t = Trap.at(combat, x, y)
    if t and (not side or Trap.visibleTo(combat, t, side)) then return t, "trap" end
    return nil
end

-- The first walkable, unoccupied tile in the 8-neighbourhood of (x, y), or nil when the spot is
-- hemmed in. The same standard `useItem` enforces for a `target = "tile"` cast -- so an effect that
-- has to PUT something down beside a unit it picked by name (the Philosopher's Stone copying a foe
-- onto the ground next to its caster) can honour that standard without re-deriving it.
--
-- Orthogonals before diagonals: a body set down beside you should read as beside you.
-- The first open tile in the ring around (x, y) a w×h body would fit on -- the anchor it can be set
-- down at. `w`/`h` default to 1×1, so every existing summon/spawn caller is unchanged; a large body
-- passes its footprint so the whole block is checked, not just the ring cell itself.
function Combat.openTileNear(combat, x, y, w, h)
    w, h = w or 1, h or 1
    local ring = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 }, { 1, -1 }, { 1, 1 }, { -1, 1 }, { -1, -1 } }
    for _, d in ipairs(ring) do
        local nx, ny = x + d[1], y + d[2]
        if Combat.footprintFree(combat, w, h, nx, ny) then
            return nx, ny
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Reinforcement edges: which side of the board a wave walks on from.
-- ---------------------------------------------------------------------------
-- A reinforcement wave (objective.waves; walked on by states/battle.lua) can name the edge it
-- arrives from. The default keeps every existing encounter unchanged -- reserves come in from behind
-- the enemy's opening line -- but a wave's `from` descriptor can send them at any side, and its
-- DYNAMIC forms read the live board, so the same fight throws its reinforcements at whichever flank
-- the battle has actually opened up rather than always down the top of the screen.
--
--   nil / "back"                  -- behind the enemy's opening line (legacy default, unchanged)
--   "top" / "bottom" / "left" / "right"  -- that edge, always
--   "random"                      -- a seeded edge (Combat.roll), reproducible from the arena seed
--   "flank"                       -- the edge nearest the living party's centre of mass, so reserves
--                                    close in beside/behind the party instead of the far line
--   "open"                        -- the emptiest edge, so a large wave always has room to land
--   "surround" / "all"            -- units spread across the edges at once, closing a ring
--   function(combat, ctx) -> edge -- a fully authored condition (e.g. the side the healer is on)

Combat.EDGES = { "top", "bottom", "left", "right" }

-- Ordered candidate tiles along `edge`: the outermost line first, then inward up to `depth` lines.
-- Every walkable cell regardless of who currently stands on it (the caller drops occupied ones), so
-- this stays a pure question about the ground. `depth` lets a packed front spill a line deeper.
function Combat.edgeTiles(combat, edge, depth)
    local arena = combat.arena
    if not (arena and arena.tiles) then return {} end
    depth = depth or 3
    local cols, rows = arena.cols, arena.rows
    local function walkable(x, y)
        local row = arena.tiles[y]
        local cell = row and row[x]
        return cell and cell.walkable
    end
    local vertical = (edge == "top" or edge == "bottom")   -- edge runs along a row (top/bottom) vs a column
    local span  = vertical and cols or rows                -- cells strung along the edge itself
    local lines = vertical and rows or cols                -- how far inward we can step
    local near  = (edge == "top" or edge == "left")        -- does this edge start at line 1?
    local first = near and 1 or lines
    local step  = near and 1 or -1
    local out = {}
    for d = 0, depth - 1 do
        local line = first + step * d
        if line >= 1 and line <= lines then
            for i = 1, span do
                local x = vertical and i or line
                local y = vertical and line or i
                if walkable(x, y) then out[#out + 1] = { x = x, y = y } end
            end
        end
    end
    return out
end

-- A free walkable tile for a reinforcement arriving from `edge`: the outermost open cell on that
-- side, spilling inward when the front line is packed. Nil when the whole edge is full, in which case
-- the caller skips that arrival rather than stacking it onto an occupied tile.
function Combat.freeEdgeTile(combat, edge, w, h)
    w, h = w or 1, h or 1
    for _, t in ipairs(Combat.edgeTiles(combat, edge, 3)) do
        if Combat.footprintFree(combat, w, h, t.x, t.y) then return t.x, t.y end
    end
    return nil
end

-- The edge the enemy formation opened against, read off the arena's AUTHORED enemy spawns rather
-- than the live units (a defend fight may already have cleared them) so a default wave still arrives
-- from behind where the enemy line stood. Top vs bottom only: that is the axis openings are seated on.
function Combat.enemyHomeEdge(combat)
    local spawns = (combat.arena and combat.arena.enemies) or {}
    local sum, n = 0, 0
    for _, e in ipairs(spawns) do sum, n = sum + e.y, n + 1 end
    local rows = (combat.arena and combat.arena.rows) or 8
    local fromTop = (n == 0) or (sum / n) <= rows / 2
    return fromTop and "top" or "bottom"
end

-- How many free (walkable, empty) tiles a wave would find on `edge` right now -- how much room it
-- has to land. Two lines deep, matching where freeEdgeTile actually seats arrivals.
function Combat.edgeOpenness(combat, edge)
    local free = 0
    for _, t in ipairs(Combat.edgeTiles(combat, edge, 2)) do
        if not Combat.unitAt(combat, t.x, t.y) then free = free + 1 end
    end
    return free
end

-- The living party's centre of mass, or nil if none stand. Flanking waves aim at it.
local function partyCentroid(combat)
    local sx, sy, n = 0, 0, 0
    for _, u in ipairs(combat.units) do
        if u.alive and u.side == "party" then sx, sy, n = sx + u.x, sy + u.y, n + 1 end
    end
    if n == 0 then return nil end
    return sx / n, sy / n
end

-- The edge a point has drifted closest to. Used by `flank` to bring reserves in beside the party, and
-- by states/battle.lua to point the arrival arrow of a telegraph whose landing cell was AUTHORED
-- rather than resolved from an edge (a scripted lesson's reinforcement): the marker still has to say
-- which side the body marches in from, and the nearest edge to the cell is that side.
function Combat.nearestEdge(combat, px, py)
    local cols = (combat.arena and combat.arena.cols) or 8
    local rows = (combat.arena and combat.arena.rows) or 8
    local dist = { top = py - 1, bottom = rows - py, left = px - 1, right = cols - px }
    local best, bestD = "top", math.huge
    for _, e in ipairs(Combat.EDGES) do
        if dist[e] < bestD then best, bestD = e, dist[e] end
    end
    return best
end

-- Resolve a wave's `from` descriptor to a concrete edge, reading live board state for the dynamic
-- forms. See the section header for the descriptors. An unrecognised name falls back to the enemy's
-- home edge, so a typo degrades to the default rather than erroring mid-battle.
function Combat.resolveWaveEdge(combat, from, ctx)
    if type(from) == "function" then from = from(combat, ctx or {}) end
    if from == nil or from == "back" then return Combat.enemyHomeEdge(combat) end
    if from == "top" or from == "bottom" or from == "left" or from == "right" then return from end
    if from == "random" then return Combat.EDGES[Combat.roll(combat, #Combat.EDGES)] end
    if from == "flank" then
        local px, py = partyCentroid(combat)
        if not px then return Combat.enemyHomeEdge(combat) end
        return Combat.nearestEdge(combat, px, py)
    end
    if from == "open" then
        local best, bestFree = Combat.enemyHomeEdge(combat), -1
        for _, e in ipairs(Combat.EDGES) do
            local f = Combat.edgeOpenness(combat, e)
            if f > bestFree then best, bestFree = e, f end
        end
        return best
    end
    return Combat.enemyHomeEdge(combat)
end

-- Assign an edge to each of `count` units in a wave. Most modes give every unit the same edge;
-- `surround`/`all` distributes them across the sides (the emptiest first, then cycling) so a wave
-- closes in from several directions at once. Returns a list of edge names, length `count`.
function Combat.waveEdges(combat, from, count, ctx)
    local edges = {}
    if from ~= "surround" and from ~= "all" then
        local edge = Combat.resolveWaveEdge(combat, from, ctx)
        for i = 1, count do edges[i] = edge end
        return edges
    end
    local order = { "top", "bottom", "left", "right" }
    table.sort(order, function(a, b)
        return Combat.edgeOpenness(combat, a) > Combat.edgeOpenness(combat, b)
    end)
    for i = 1, count do edges[i] = order[((i - 1) % #order) + 1] end
    return edges
end

-- The tile a single reinforcement lands on, given the edge Combat.waveEdges resolved for it. For the
-- default (behind the enemy line) an unused ORIGINAL enemy spawn is preferred -- reserves filling the
-- holes the opening formation left -- before falling back to the outermost open cell on the edge. Nil
-- when there is nowhere to stand. `freeFn(w, h, x, y)` decides whether a footprint may land: it
-- defaults to the live board, but Combat.previewWaveArrival passes one that also refuses tiles an
-- earlier unit in the SAME wave has already claimed, so a previewed wave never doubles two bodies onto
-- one cell. Pure -- the headless suite reaches it directly. (states/battle.lua's old private waveTile,
-- lifted here so the preview and the spawn choose ground by one rule.)
function Combat.waveArrivalTile(combat, from, edge, w, h, freeFn)
    w, h = w or 1, h or 1
    freeFn = freeFn or function(fw, fh, x, y) return Combat.footprintFree(combat, fw, fh, x, y) end
    if from == nil or from == "back" then
        for _, e in ipairs((combat.arena and combat.arena.enemies) or {}) do
            if freeFn(w, h, e.x, e.y) then return e.x, e.y end
        end
    end
    for _, t in ipairs(Combat.edgeTiles(combat, edge, 3)) do
        if freeFn(w, h, t.x, t.y) then return t.x, t.y end
    end
    return nil
end

-- Resolve a whole wave's arrival WITHOUT spawning it: where each unit would land, read off the live
-- board. This is what makes a reinforcement telegraph honest -- states/battle.lua commits the result a
-- couple of turns early and then BOTH draws it and spawns from it, so the marker the player sees and
-- the bodies that arrive are one and the same (see spawnWaves/fireWave). Resolving a dynamic edge
-- (flank/open/random) once, here, is also what fixes it: the preview cannot drift from the reality
-- because there is only ever one resolution.
--
-- Returns { edge, tiles = { { x, y, w, h }, ... }, ids, chars } or nil for an empty wave / no room.
-- `chars` are instantiated once here and reused at spawn time, so a `composition` function is
-- evaluated a single time and a random roster is fixed the moment it is committed. Units for which no
-- tile is open (a packed edge) are dropped from the plan, exactly as the old fire-time path skipped an
-- arrival with nowhere to stand. Pure and headless-safe (Character.instantiate needs no window).
function Combat.previewWaveArrival(combat, wave, ctx)
    local ids = wave.composition
    if type(ids) == "function" then ids = ids(ctx or {}) end
    ids = ids or {}
    if #ids == 0 then return nil end
    local from = wave.from
    local edges = Combat.waveEdges(combat, from, #ids, ctx)
    local reserved = {}
    local function freeFn(w, h, x, y)
        if not Combat.footprintFree(combat, w, h, x, y) then return false end
        for dx = 0, w - 1 do
            for dy = 0, h - 1 do
                if reserved[(x + dx) .. "," .. (y + dy)] then return false end
            end
        end
        return true
    end
    local tiles, chars, keptIds = {}, {}, {}
    for i, id in ipairs(ids) do
        local char = Character.instantiate(id)
        local fp = char.footprint or { w = 1, h = 1 }
        local w, h = fp.w or 1, fp.h or 1
        local x, y = Combat.waveArrivalTile(combat, from, edges[i], w, h, freeFn)
        if x then
            for dx = 0, w - 1 do
                for dy = 0, h - 1 do reserved[(x + dx) .. "," .. (y + dy)] = true end
            end
            tiles[#tiles + 1] = { x = x, y = y, w = w, h = h }
            chars[#chars + 1] = char
            keptIds[#keptIds + 1] = id
        end
    end
    if #tiles == 0 then return nil end
    return { edge = edges[1], tiles = tiles, ids = keptIds, chars = chars }
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
-- every print they make). A `trail = { hazard, duration }` or `trail = { trap = ... }` on any item in
-- the 3x3 grid -- the same inventory scan as Combat.ignoresTraps above -- drops that ground on the
-- tile, sided with the wearer so an ally-only zone, or a trap, can never serve the foe walking
-- through it. Called from Combat.enterTile on a ground crossing only: footprints are pressed by feet,
-- so a blink or a swap leaves none.
--
-- The two kinds of ground a trail can leave are the two kinds this game has, and which one an item
-- picks says what its footprints ARE:
--   hazard -- ground that CHANGES while it lasts: a puddle, a bed of cinders. Ages out on the clock,
--             cannot be destroyed, fires for everyone who crosses it until it fades.
--   trap   -- an OBJECT left lying there: caltrops. No duration at all, hidden from the enemy unless
--             they carry a detector, breakable, and spent on the one foe it bites.
-- A trail lays only ONE trap per tile: a wearer pacing the same corridor would otherwise heap a fresh
-- caltrop on the pile every crossing, since traps -- unlike hazards, which dedupe by refreshing -- have
-- no notion of an identical one already being here.
--
-- A trail is always laid BEHIND: on the tile the unit just LEFT (`fromX, fromY`), never the one it is
-- standing on. One rule, no per-item choice, and it is what lets a trail be something the wearer could
-- not survive standing in -- the Cinderstride Boots leave real, unsided, spreading fire and need no
-- immunity of any kind, because the wearer is simply never on it. It stays one step ahead of its own
-- ground. Walk back over what you left and you take it exactly as anyone else would: the protection is
-- position, and it is given up by turning around.
--
-- The corollary is that a trail can no longer do anything FOR its wearer through the ground -- you
-- cannot stand in your own print any more. `selfStatus = { id, duration }` is the honest way to say
-- what the walking does to the walker: a status applied straight to the unit, refreshed on every tile
-- it crosses, so it holds while it keeps moving and fades once it stops. The Pilgrim's Sandals' healing
-- is that (see the blueprint) -- it used to fall out of standing in the hallowed tile, and now it is
-- stated rather than implied.
--
-- Laying behind needs a tile to have come FROM, so the ground half lays nothing when the caller hands
-- over no origin -- a summon's arrival, a blink. Same rule the trail already obeys through `reason`:
-- ground is pressed by feet, and a unit that crossed nothing left nothing. `selfStatus` does not read
-- the origin: Combat.enterTile has already established that a real crossing happened, and the walking
-- is what blesses the walker, not the tile it came off.
--
-- A trail lays only ONE trap per tile: a wearer pacing the same corridor would otherwise heap a fresh
-- caltrop on the pile every crossing, since traps -- unlike hazards, which dedupe by refreshing -- have
-- no notion of an identical one already being here.
function Combat.layTrail(combat, unit, fromX, fromY)
    if not (unit and unit.char) then return end
    for _, item in ipairs(Character.eachItem(unit.char)) do
        local trail = item.trail
        if trail then
            if trail.selfStatus then
                Status.apply(combat, unit, trail.selfStatus.id, { duration = trail.selfStatus.duration })
            end
            if fromX and fromY then
                if trail.hazard then
                    Hazard.place(combat, fromX, fromY, trail.hazard,
                        { side = unit.side, duration = trail.duration })
                end
                if trail.trap and not Trap.at(combat, fromX, fromY) then
                    Trap.place(combat, fromX, fromY, trail.trap, unit.side)
                end
            end
        end
    end
end

-- Lay the ground a unit's kit carries WITH it. An `incense = { hazard, radius, amount }` on any item in
-- the 3x3 grid -- a censer (docs/weapons.md) -- lays that hazard in a square around the bearer, OWNED
-- by them. Same inventory scan as Combat.layTrail directly above, and the deliberate contrast to it:
--
--   a banner is ground that STAYS      -- owned by a body planted in it (data/hazards/hazard_rally.lua)
--   a trail  is ground you LEAVE       -- unowned, it outlives your passing (Pilgrim's Sandals)
--   incense  is ground that WALKS      -- lifted from where you were, laid where you are
--
-- The ownership is what does the work. Lifting last beat's cloud by owner+id before laying the next is
-- the whole of "it follows you" -- without it the smoke would accumulate into a wake, which is what a
-- trail already is. Narrowed to this censer's own hazard id so a bearer holding other ground open
-- (a banner it planted, ground a future ability sides to its caster) never has it lifted from under it.
--
-- Called from Combat.enterTile, BEFORE that function's Hazard.reap pass, for the same reason layTrail
-- is: the bearer stands in the middle of its own cloud, and a reap that ran first would strip the
-- blessing the censer is in the act of granting. Unlike a trail it ignores `reason` entirely -- smoke
-- is not pressed by feet, so it keeps up with a blink or a shove as readily as a step. Also called
-- from Combat.rebase, which is the half movement cannot cover: a bearer who never moves at all still
-- holds its ground, and construction routes through there too, so the smoke is up before the first turn.
function Combat.layIncense(combat, unit)
    if not (unit and unit.char and unit.alive) then return end
    for _, item in ipairs(Character.eachItem(unit.char)) do
        local inc = item.incense
        if inc and inc.hazard then
            Hazard.dropOwnedBy(combat, unit, inc.hazard)
            local r = inc.radius or 1
            for dy = -r, r do
                for dx = -r, r do
                    -- Chebyshev square, matching Combat.aoeCells' default shape. Off-grid and wall
                    -- cells are Hazard.place's problem -- it skips them -- so the edge of the map
                    -- simply clips the cloud rather than needing a bounds check here.
                    Hazard.place(combat, unit.x + dx, unit.y + dy, inc.hazard, {
                        owner = unit,
                        side = unit.side, -- so an ally-only cloud can never serve the foe standing in it
                        amount = inc.amount,
                    })
                end
            end
        end
    end
end

function Combat.unitsNear(combat, x, y, radius)
    radius = radius or 0
    local out = {}
    for _, u in ipairs(combat.units) do
        -- Nearest cell of the body, so a big unit is "near" (x, y) when any part of it is in radius.
        if u.alive and Combat.cellGap(x, y, u) <= radius then out[#out + 1] = u end
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

-- Order the units that ride the timeline (Combat.inTimeline -- living, and not a timeless object like
-- a banner) by turn using `initOf(unit)` for each unit's initiative: lowest first, then higher `speed`
-- (the faster unit wins a tie), then the deterministic tie-break (party before enemy, then index).
-- `initOf` lets previewOrder substitute a hypothetical initiative for one unit without mutating.
local function orderBy(combat, initOf)
    local order = {}
    for _, u in ipairs(combat.units) do
        if Combat.inTimeline(u) then order[#order + 1] = u end
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
        if Combat.inTimeline(u) then
            entries[#entries + 1] = { unit = u, preview = false, initiative = u.initiative }
        end
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
                initiative = u.initiative + Combat.actionSpeed(u, ch.ab, ch.item) + Combat.tempoDebt(u),
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
    -- Decided in the block below, granted past Status.onTurnStart at the foot of this function.
    local veil = false
    -- An Overwatch stance is a one-turn watch: it lapses the moment its holder comes back around to
    -- act, so the unit chooses anew each turn whether to hold the line again.
    -- Free actions refresh on the same beat and for the same reason (Combat.FREE_ACTIONS_PER_TURN).
    -- Cleared at turn START rather than in endTurn because a free cast never REACHES endTurn -- that is
    -- the whole point of it -- and a turn can also close through wait, death or a rout.
    if unit then
        unit.overwatch = nil
        unit.freeActionsUsed = nil
        -- ...and the `soleAction` latch beside it (Harrier's Bow): a free action that still SPENDS the
        -- turn's action, leaving only the move. Cleared here for the same reason -- a sole action never
        -- reaches endTurn either, so turn start is the one beat that can refresh it.
        unit.actionSpent = nil
        -- THE IDLE VEIL (the Ninja's Smoke Mantle): a bearer who drew no blood on its previous turn
        -- opens this one unseen. Measured off the `hitDealt` tally rather than a flag, because the
        -- tally is already kept and already monotonic -- "did the count move since I last stood here"
        -- is the same question as "did I attack", and needs nothing new to remember it.
        --
        -- DECIDED here and APPLIED at the bottom of this function, past Status.onTurnStart. That is
        -- not tidiness: status_invisible self-expires in onTurnStart (it lasts until its holder's next
        -- turn), so a veil granted before that call is stripped by it on the same beat. The bookmark
        -- has to be read here, before anything else this turn can move the tally, and the grant has to
        -- happen there, after the expiry sweep has run.
        local hits = Combat.tallyCount(unit, "hitDealt")
        veil = Trait.flag(unit, "veilsWhenIdle") and unit.lastTurnHits and hits == unit.lastTurnHits
        -- Written unconditionally, so a ninja who spends three turns hiding is veiled on each of them
        -- rather than only the first.
        unit.lastTurnHits = hits
    end
    -- Answers are paced by an escalating price rather than a cooldown (see Trait.answerCost): each
    -- answer since the bearer last acted costs double the one before it, and coming back around to
    -- act is what clears the tally. So a unit surrounded by three foes answers the first blow at
    -- price, the second at double and the third at quadruple, and runs itself dry holding the
    -- doorway -- the job the old per-trait cooldown did, but visible in a pool the player can watch.
    if unit then unit.answersThisRound = 0 end
    -- Coming around to act is a `turnTaken` -- what a signature gated "not on turn 1" or on outlasting
    -- the opening counts (see Combat.tally). Counted before the turn's own actions, so its own cast
    -- can't be the turn that unlocked it.
    if unit then Combat.tally(unit, "turnTaken", 1) end
    -- WHERE IT STOOD LAST TIME. Two tiles, kept on the unit: where this turn opened, and where the
    -- PREVIOUS one did. Combat.recall (the Backward Glance) sends a unit to the older of the two --
    -- deliberately not to where it opened this turn, which for a unit that has not moved yet is simply
    -- where it is standing and would make the spell do nothing.
    --
    -- Two tiles rather than a ring buffer because two is the whole question the spell asks. A longer
    -- history would be a longer promise about a board that has since changed underneath it, and the
    -- one-turn version is already the hardest thing on the field to plan around: it takes back the
    -- approach an enemy just spent its turn making.
    if unit then
        unit.priorX, unit.priorY = unit.turnStartX, unit.turnStartY
        unit.turnStartX, unit.turnStartY = unit.x, unit.y
        -- The once-per-turn stamps (Combat.firstThisTurn), cleared here and ONLY here -- which is what
        -- makes an extra action part of the same turn rather than a new one, since a surge re-opens
        -- combat.turn straight from endTurn and never comes back through this function.
        unit.turnFlags = nil
    end
    if unit then Status.onTurnStart(combat, unit) end
    -- The idle veil, granted past the expiry sweep above (see where `veil` is decided): a ninja who
    -- drew no blood last turn opens this one out of sight. After onTurnStart, or the sweep that ends
    -- LAST turn's invisibility would end this turn's in the same breath.
    if veil then Status.apply(combat, unit, "status_invisible") end
    -- CONTAGION (the Plague Knight's): at the top of the bearer's turn, every poisoned body on the
    -- field infects the bearer's enemies standing next to it. A passive rather than a cast (rule R4) --
    -- standing beside you sickens, and you never press a button for it.
    --
    -- Reads POISONED BODIES rather than poisoned enemies, which is what makes the Plaguebearer's
    -- Draught a strategy instead of a self-harm: a plague knight who has poisoned ITSELF is a walking
    -- source, and the sickness spreads out of its own tile. Only the bearer's foes ever catch it.
    if unit and Trait.flag(unit, "spreadsPoison") then Combat.spreadContagion(combat, unit) end
    -- THE FIELD STILL (the Warbrewer's): a draught is brewed into the grid at the top of the turn. The
    -- flag carries the item id, so the charm decides what it makes and the engine only decides when.
    local still = unit and Trait.flag(unit, "brewsEachTurn")
    if still then Combat.grantItem(combat, unit, still.def.brewsEachTurn) end
    -- FUSES (S3) burn down in their OWNER's turns, not on a global clock -- so two sappers' charges each
    -- count at their own pace, and a charge whose owner is dead simply waits. Nobody is left to set it
    -- off, which is the right answer and costs nothing to arrange.
    if unit then Combat.tickCharges(combat, unit) end
    return unit
end

-- Send `unit` back to the tile it stood on when its PREVIOUS turn opened (see Combat.startTurn's
-- bookkeeping). Returns false when there is no remembered tile yet -- a unit in its first turn has no
-- "before" to be put back to -- or when the ground it remembers is no longer somewhere a body can
-- stand: occupied, blocked, or off a board that has since had a wall raised on it.
--
-- Routed through Combat.teleportUnit rather than by writing x/y, so the arrival springs whatever waits
-- on that tile exactly as any other blink does. Being dragged backwards through time does not make you
-- immune to the trap you were standing next to.
function Combat.recall(combat, unit)
    if not (unit and unit.alive) then return false end
    local x, y = unit.priorX, unit.priorY
    if not (x and y) then return false end
    if x == unit.x and y == unit.y then return false end
    if Combat.unitAt(combat, x, y) or Combat.objectBlocksAt(combat, x, y) then return false end
    local row = combat.arena and combat.arena.tiles and combat.arena.tiles[y]
    local cell = row and row[x]
    if not (cell and cell.walkable) then return false end
    local moved = Combat.teleportUnit(combat, unit, x, y)
    if moved then
        Combat.logEvent(combat, "action",
            string.format("%s is pulled back to where it stood.", unitName(unit)), unit)
    end
    return moved
end

-- Promise the party `amount` more coin for winning this battle, banked on the combat itself and paid
-- out with the spoils (models/spoils.lua reads combat.bounty). What a bounty mark settles into when
-- its target falls, and what the Ledger pays for a body it consumes.
--
-- On the COMBAT rather than on the player, because a battle that is lost pays nothing: the promise is
-- only ever collected by the code that already decides a victory was earned.
function Combat.bounty(combat, amount)
    if not (combat and amount and amount > 0) then return 0 end
    combat.bounty = (combat.bounty or 0) + amount
    return combat.bounty
end

-- Take a corpse off the field for good: it stops being a body anything can raise, revive or read. The
-- destructive half of a transaction that turns the dead into something else, kept separate from
-- Combat.bounty so a spell can consume without paying and pay without consuming.
--
-- The unit stays in combat.units (everything else in this model assumes a list that only grows), it
-- simply stops being a corpse -- which is the same state a reanimated body passes through, so nothing
-- downstream needs a new case for it.
function Combat.consumeCorpse(combat, corpse)
    if not (corpse and corpse.corpse) then return false end
    corpse.corpse = false
    Combat.logEvent(combat, "action",
        string.format("%s's body is spent.", unitName(corpse)), corpse)
    return true
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
-- charging it, so the turn costs the wind-up and nothing else -- see Combat.tempoDebt. Any later
-- endTurn settles the debt on top of its own costs, so the ground is paid for exactly once whether
-- the channel resolves or is interrupted.
--
-- An EXTRA ACTION (Combat.grantExtraAction) short-circuits the whole ending: everything this turn
-- would have cost is banked as debt and the turn re-opens on the spot, so the unit acts again without
-- the field getting a beat in between. See the note on that function for why the tempo is banked
-- rather than waived.
local function endTurn(combat, unit, actionCost, defer)
    -- OUT OF BAND: somebody else's turn is open, so `unit` is not ending a turn -- it is being made to
    -- act off its own slot, from inside the acting unit's cast (fx.hastenChannel finishing an ally's
    -- wind-up early). Bill the initiative and nothing else, because none of the rest is true: the
    -- unit's statuses have not reached their end of turn (a Burn would sear a turn early and every
    -- duration would drop a tick), no turn has been taken to count, and `combat.turn` belongs to the
    -- caster standing in the middle of its own action -- clearing it would end THAT turn.
    --
    -- The initiative is ADDED to what the unit already stands at rather than replacing it, so a body
    -- pulled off its slot lands exactly where it would have. A channeler sitting on W ticks of wind-up
    -- was going to resolve at W and then pay speed + debt on top; hastened, it pays them from W here
    -- and its next real action falls on the same tick either way. What the gift buys is that the blow
    -- lands NOW instead of at W -- untelegraphed, uninterruptible -- and never free tempo.
    --
    -- Cannot fire on any path that exists today (every caller below is the active unit, and a headless
    -- test with no open turn leaves `combat.turn` nil and takes the ordinary road).
    if combat.turn and combat.turn.unit ~= unit then
        unit.initiative = unit.initiative + actionCost + (unit.tempoDebt or 0)
        unit.tempoDebt = nil
        return
    end

    local moveCost = turnMoveCost(combat, unit)

    -- A surge in hand: bank this action's whole price and hand the turn straight back. Deliberately
    -- BEFORE Status.onTurnEnd and the turnCount bump -- this is one turn with two actions in it, not
    -- two turns, so nothing that measures a turn may fire twice for it (a Burn would sear twice, a
    -- Defend would lapse early, an objective counting turns would double-count).
    if (unit.extraActions or 0) > 0 and unit.alive then
        unit.extraActions = unit.extraActions - 1
        unit.tempoDebt = (unit.tempoDebt or 0) + moveCost + actionCost
        -- `moved = true`: a surge buys an ACTION, never a second walk. The unit acts from where the
        -- first action left it, which is what keeps it a burst rather than a free double turn.
        combat.turn = { unit = unit, moved = true, moveCost = 0, startX = unit.x, startY = unit.y }
        Combat.logEvent(combat, "action",
            string.format("%s presses the attack without pause!", unitName(unit)), unit)
        return
    end

    if defer then
        unit.tempoDebt = (unit.tempoDebt or 0) + moveCost
        moveCost = 0
    else
        moveCost = moveCost + (unit.tempoDebt or 0)
        unit.tempoDebt = nil
    end
    Status.onTurnEnd(combat, unit)
    unit.initiative = unit.initiative + moveCost + actionCost
    combat.turnCount = combat.turnCount + 1
    combat.turn = nil
    unit.extraActions = nil -- a surge unspent when the turn really ends does not keep
    Combat.rebase(combat)
end

-- The tempo a unit has banked but not yet paid: ground it covered on the turn it began a channel
-- (deferred past the resolution), plus the full price of any action it took through an extra action.
-- 0 for everyone else. The single reader for the timeline's follow-up ghost, so the projected slot
-- matches what the settling endTurn will charge.
function Combat.tempoDebt(unit)
    return unit.tempoDebt or 0
end

-- Grant `unit` `n` extra actions this turn (default 1): when its current action would end the turn,
-- the turn re-opens instead and it acts again immediately.
--
-- What an extra action buys is ORDER, not time. Every tick the surged actions would have cost is
-- banked as debt (see endTurn) and paid in full the moment the unit finally stops, so a fighter who
-- swings twice lands correspondingly further down the timeline -- it has spent tomorrow's turn today.
-- That is the honest shape of "extra action" in a game with no action points: initiative is the only
-- currency here, and an action genuinely free of it would let a unit act, stay at initiative 0, and
-- act forever. What the player actually gains is real and worth paying for -- two actions with no
-- enemy beat between them, which is how a burst finishes something before it can answer.
--
-- Generic on purpose: it is a fact about a unit, not a property of the ability that granted it, so a
-- fighter's Surge, a relic's trait and a boss phase all reach for the same three lines. Cleared when
-- a turn really ends, so an unspent surge never carries into the next one.
function Combat.grantExtraAction(unit, n)
    if not (unit and unit.alive) then return 0 end
    unit.extraActions = (unit.extraActions or 0) + (n or 1)
    return unit.extraActions
end

-- ONCE THIS TURN. True the first time it is asked for `key` in the current turn, false every time
-- after -- and it STAMPS as it answers, so a caller asks exactly once and branches on the answer.
--
-- What it is for: every "act again" reflex fires on a kill, and a kill made with the granted action
-- can fire it again. Ungated, a body standing in a broken line refreshes forever. The resource cost on
-- an ability bounds how often you can AFFORD to press it, which is why the free-action limit
-- (Combat.FREE_ACTIONS_PER_TURN) exists beside it -- but a reflex is not pressed at all, so nothing
-- bounds it except this.
--
-- Cleared in Combat.startTurn, which is what makes an extra action still count as the SAME turn: a
-- surge re-opens `combat.turn` directly from endTurn without passing through startTurn (see the note
-- there on why it must not fire per-turn machinery twice), so the stamp survives into the granted
-- action. One refresh per real turn, which is the promise the items make.
function Combat.firstThisTurn(unit, key)
    if not (unit and key) then return false end
    unit.turnFlags = unit.turnFlags or {}
    if unit.turnFlags[key] then return false end
    unit.turnFlags[key] = true
    return true
end

-- A body that leaves the field mid-turn takes the turn record with it. `combat.turn` is the record of
-- an OPEN turn -- a turn somebody is still standing in the middle of -- and a unit felled on its own
-- approach (a Bleed tick on the tile it walked onto, a trap, an overwatch shot) never reaches any of
-- the paths that close one: it does not act, so it never reaches endTurn, and nothing passes for it.
--
-- Left set, the record points at a corpse, and the UI reads a still-set `combat.turn` as "carry on the
-- open turn" (states/battle.lua's beginTurn resume) -- so the turn is handed straight back to the body
-- that just dropped, which plans nothing, ends nothing, and is handed it again on the next frame. That
-- is the soft-lock: the enemy think-pause ticking forever over a unit that can no longer do anything.
-- The state layer already assumes this ("a unit cut down on the approach just hands the turn on"); this
-- is the model half of it, at the three points a body leaves the board with a turn possibly open.
--
-- Only ever clears a record belonging to THIS unit: a death on somebody else's turn -- the far more
-- common case, a counter or an area blast -- must leave the actor's own turn open.
local function leaveTurn(combat, unit)
    if combat.turn and combat.turn.unit == unit then combat.turn = nil end
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
    local moveCost = turnMoveCost(combat, unit) + (unit.tempoDebt or 0)
    unit.tempoDebt = nil
    Status.onTurnEnd(combat, unit)
    local nxt = nextUnit(combat, unit)
    unit.initiative = nxt and math.max(moveCost, nxt.initiative + 1) or (moveCost + Combat.WAIT_COST)
    combat.turnCount = combat.turnCount + 1
    combat.turn = nil
    Combat.logEvent(combat, "wait", string.format("%s waits.", unitName(unit)), unit)
    Combat.rebase(combat)
    return true
end

-- How this unit's "Wait" behaves, resolved from the first inventory item that declares a
-- `waitBehavior` table { kind = "focus"|"defend"|"overwatch"|"perform", ... }. Defaults to a plain
-- delay. A unit is expected to carry at most one such item; if it somehow carries several,
-- first-in-inventory wins. Drives both the battle UI's action-button label and which of
-- wait/focus/defend/overwatch/perform runs.
function Combat.waitBehavior(unit)
    for _, item in ipairs(Character.eachItem(unit.char)) do
        if item.waitBehavior then return item.waitBehavior end
    end
    return { kind = "delay" }
end

-- Focus: end the turn without attacking, restoring mana instead. Costs more of the timeline than
-- a plain wait (behavior.speed, or Combat.FOCUS_SPEED). The mana-recovery half of the wait swap
-- granted by a focus item (data/items/utility/utility_focus_stone.lua).
function Combat.focus(combat, unit)
    if not unit.alive then return false, "dead" end
    local behavior = Combat.waitBehavior(unit)
    local restored = Combat.restoreResource(unit.char, "mana", behavior.mana or 0)
    Combat.logEvent(combat, "focus",
        string.format("%s focuses (+%d mana).", unitName(unit), restored), unit)
    -- A crozier feeds the line, not just the hand holding it: `waitBehavior.covers` restores that
    -- (smaller) amount of mana to every ADJACENT ALLY too. Exactly the shape the Oathkeeper Shield uses
    -- to spread its brace (see Combat.defend), read here as mana instead of defense -- so the same one
    -- word means "and everyone beside you" on both halves of the wait swap. What it buys is the same
    -- kind of decision: where a priest plants to meditate decides whose spells come back with it.
    if behavior.covers then
        for _, ally in ipairs(Combat.unitsNear(combat, unit.x, unit.y, 1)) do
            if ally ~= unit and ally.side == unit.side then
                local got = Combat.restoreResource(ally.char, "mana", behavior.covers)
                if got > 0 then
                    Combat.logEvent(combat, "focus",
                        string.format("%s draws on the calm (+%d mana).", unitName(ally), got), ally)
                end
            end
        end
    end

    -- The four fields below are the same idea as `covers`: a named staff tunes what its Focus DOES
    -- rather than how much mana it gives back, declared on the item instead of hand-rolled per weapon.
    -- Focus has no `effect` to hook (it is a wait swap, not a cast), so a staff whose extra lands on the
    -- meditation has nowhere else to put it. Each is optional and they compose.

    -- `status`: what the focuser gains for meditating (weapon_warding_staff's magical barrier).
    if behavior.status then
        Status.apply(combat, unit, behavior.status, { applier = unit })
    end

    -- `hazard`: ground laid under the focuser, in a square of `radius` (0 = the one tile they stand on).
    -- Owned by them, as a censer's smoke is -- but NOT lifted when they move, because that lifting is
    -- precisely what separates incense from a banner (docs/weapons.md). A staff plants; it does not carry.
    if behavior.hazard then
        local h = behavior.hazard
        local r = h.radius or 0
        for dy = -r, r do
            for dx = -r, r do
                Hazard.place(combat, unit.x + dx, unit.y + dy, h.id,
                    { side = unit.side, amount = h.amount, duration = h.duration })
            end
        end
    end

    -- `afflicts`: what every ADJACENT ENEMY takes for standing beside the meditation. `covers` pointed
    -- outward -- the one wait swap in the catalog that is hostile (weapon_gag_crook's silence).
    if behavior.afflicts then
        for _, foe in ipairs(Combat.unitsNear(combat, unit.x, unit.y, 1)) do
            if foe ~= unit and foe.alive and foe.side ~= unit.side then
                Status.apply(combat, foe, behavior.afflicts, { applier = unit })
            end
        end
    end

    -- `toll`: a resource the meditation SPENDS, for a staff that trades one pool for another
    -- (weapon_overchannelled_staff buys its deeper mana with the focuser's own blood). Taken as a drain
    -- rather than as damage: it is a toll, not a blow -- nothing mitigates it and it cannot kill.
    if behavior.toll then
        local paid = Combat.drainResource(unit.char, behavior.toll.stat, behavior.toll.amount or 0)
        if paid > 0 then
            Combat.logEvent(combat, "focus",
                string.format("%s pays for it (-%d %s).", unitName(unit), paid, behavior.toll.stat), unit)
        end
    end

    endTurn(combat, unit, behavior.speed or Combat.FOCUS_SPEED)
    return true
end

-- Defend: end the turn without attacking, gaining the Defending status (a temporary +defense that
-- lasts until this unit's next turn). Costs behavior.speed of the timeline (or Combat.DEFEND_SPEED).
-- The wait swap granted by a shield item (data/items/armor/armor_buckler.lua).
function Combat.defend(combat, unit)
    if not unit.alive then return false, "dead" end
    local behavior = Combat.waitBehavior(unit)
    -- The shield tunes the brace size through waitBehavior.defense (already resolved to this shield's
    -- upgrade level); it rides in as the Defending status's magnitude. nil falls back to the status
    -- def's own magnitude, so a defend item that names no amount still braces.
    Status.apply(combat, unit, "status_defending", { magnitude = behavior.defense })
    Combat.logEvent(combat, "defend", string.format("%s takes a defensive stance.", unitName(unit)), unit)
    -- A tower shield covers the line, not just the man holding it: `waitBehavior.covers` braces every
    -- ADJACENT ALLY too, for that (smaller) amount. Only the largest shields declare it -- see
    -- data/items/armor/armor_oathkeeper_shield.lua -- and it is what makes bracing a formation decision
    -- rather than a private one: where you stand when you plant decides who else gets the wall.
    if behavior.covers then
        for _, ally in ipairs(Combat.unitsNear(combat, unit.x, unit.y, 1)) do
            if ally ~= unit and ally.side == unit.side then
                Status.apply(combat, ally, "status_defending", { magnitude = behavior.covers })
                Combat.logEvent(combat, "defend",
                    string.format("%s is covered by the wall.", unitName(ally)), ally)
            end
        end
    end

    -- The two fields below are the Focus half's `status` / `coversStatus` read on this side of the wait
    -- swap (see Combat.focus), and they exist for the same reason: bracing has no `effect` to hook, so a
    -- named shield whose extra lands on the STANCE has nowhere else to put it. One rule, both halves.

    -- `status`: what the brace grants the holder BESIDES the ordinary Defending -- a ward, a reflection,
    -- a wound held in reserve. What separates the named shields from a bigger `defense` number.
    if behavior.status then
        Status.apply(combat, unit, behavior.status, { applier = unit })
    end

    -- `coversStatus`: the same thing handed to adjacent allies instead of, or as well as, the holder.
    -- `covers` spreads the brace's SIZE; this spreads its KIND -- so a shield can plant a wall on the
    -- line without the holder keeping any of it (armor_given_guard trades one for the other).
    if behavior.coversStatus then
        for _, ally in ipairs(Combat.unitsNear(combat, unit.x, unit.y, 1)) do
            if ally ~= unit and ally.alive and ally.side == unit.side then
                local st = Status.apply(combat, ally, behavior.coversStatus, { applier = unit })
                -- The holder is the other end of any bond the granted status opens. Shared Burden reads
                -- `.bonded` off its live instance to know who carries the half it takes away
                -- (data/status/status_shared_burden.lua), and Status.instantiate keeps only its own
                -- declared fields, so it has to be stamped here. Harmless on a status that never reads
                -- it, and there is only one honest answer for a shield: whoever planted it.
                if st then st.bonded = unit end
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
-- a sentry item (data/items/utility/utility_overwatch_scope.lua).
--
-- The stance also makes the ground beside it DEAR -- `zone`, the tax an enemy pays to enter a tile
-- orthogonally adjacent to the watcher (Combat.watchTax, spent by stepTerrainCost). It rides here
-- beside staminaPerShot because it is the same kind of number: a property of the stance this bearer
-- takes, tuned by the item that grants it. A `waitBehavior` naming no zone taxes nothing, so the two
-- pre-existing sentry items opted in explicitly rather than being changed underneath.
function Combat.overwatch(combat, unit)
    if not unit.alive then return false, "dead" end
    local behavior = Combat.waitBehavior(unit)
    unit.overwatch = { staminaPerShot = behavior.stamina or 0, zone = behavior.zone or 0 }
    Combat.logEvent(combat, "action", string.format("%s takes overwatch.", unitName(unit)), unit)
    endTurn(combat, unit, behavior.speed or Combat.FOCUS_SPEED)
    return true
end

-- Gather: end the turn without acting, coiling for a stronger blow instead -- the bearer gains the
-- Empowered status (a stored +attack their NEXT landed hit spends). The offensive mirror of Defend, and
-- built from the same parts: the charm tunes the stored force through waitBehavior.power (it rides in as
-- the status's magnitude), and nil falls back to the status def's own. Costs behavior.speed of the
-- timeline (or Combat.DEFEND_SPEED -- a cheap stance, clearly less than the mana-recovery Focus, like
-- Defend). The wait swap granted by a monk charm (data/items/utility/utility_centering_charm.lua).
--
-- The `covers` field spreads the coil down the line, exactly as Defend's does its wall: an adjacent ally
-- gains a (smaller) Empowered, so where a monk plants to centre decides whose next blow it feeds. One
-- word, one meaning across every wait swap -- "and everyone beside you".
function Combat.gather(combat, unit)
    if not unit.alive then return false, "dead" end
    local behavior = Combat.waitBehavior(unit)
    Status.apply(combat, unit, "status_empowered", { magnitude = behavior.power, applier = unit })
    Combat.logEvent(combat, "action", string.format("%s centers for a stronger blow.", unitName(unit)), unit)
    if behavior.covers then
        for _, ally in ipairs(Combat.unitsNear(combat, unit.x, unit.y, 1)) do
            if ally ~= unit and ally.alive and ally.side == unit.side then
                Status.apply(combat, ally, "status_empowered", { magnitude = behavior.covers, applier = unit })
                Combat.logEvent(combat, "action",
                    string.format("%s draws on the calm and coils to strike.", unitName(ally)), ally)
            end
        end
    end
    endTurn(combat, unit, behavior.speed or Combat.DEFEND_SPEED)
    return true
end

-- The air a Perform would sound NEXT for this unit, as (song, index), or nil when the behavior names
-- none. Pure, so the UI and the log can ask what is coming without playing it -- which is the whole
-- legibility problem a cycling stance has: a button that does a different thing every press is a button
-- nobody can plan around unless it says which thing.
--
-- The cursor lives on the UNIT rather than the item because it is a performance, not a property of the
-- brass: hand the horn to somebody else mid-campaign and they start at the first air, which is also what
-- keeps a horn in the stash from carrying a half-finished cycle into the next battle.
function Combat.nextSong(unit, behavior)
    local songs = behavior and behavior.songs
    if not songs or #songs == 0 then return nil, 0 end
    local idx = ((unit.songIndex or 0) % #songs) + 1
    return songs[idx], idx
end

-- Perform: end the turn to sound the next air on a carried instrument, laying its status on the bearer
-- and every ALLY within earshot. The wait swap granted by a horn (data/items/utility/utility_hunting_horn.lua).
--
-- The fourth swap, and the only one that is a CYCLE: focus, defend and overwatch each do one thing every
-- time, and this does a different thing on each press, in a fixed order the player can read off the
-- tooltip. That is what it sells -- not a bigger payoff than Focus, but a party-wide one you have to
-- spend three turns walking through to reach the air you actually wanted.
--
-- Two deliberate limits, both on the same principle the censer's radius and every swap's `speed` follow
-- (docs/weapons.md): `earshot` does not scale with the forge, and neither does the order. An upgrade
-- buys a longer, stronger air, never a wider one and never the right to skip to it.
function Combat.perform(combat, unit)
    if not unit.alive then return false, "dead" end
    local behavior = Combat.waitBehavior(unit)
    local song, idx = Combat.nextSong(unit, behavior)
    -- A "perform" swap that names no airs is an authoring slip, not a game state: fall back on a plain
    -- wait so the turn still ends rather than the button silently doing nothing.
    if not song then return Combat.wait(combat, unit) end
    unit.songIndex = idx

    -- `magnitude` is only passed for an air that asked to scale (song.scales), so a status tuned by its
    -- own def -- Inspiration's flat stat bonus -- is not handed a number it would misread as one.
    local opts = { duration = behavior.duration, magnitude = song.scales and behavior.amount or nil }
    local reached = 0
    for _, ally in ipairs(Combat.unitsNear(combat, unit.x, unit.y, behavior.earshot or 2)) do
        if ally.alive and ally.side == unit.side then
            Status.apply(combat, ally, song.status, opts)
            reached = reached + 1
        end
    end
    Combat.logEvent(combat, "action",
        string.format("%s sounds %s (%d in earshot).", unitName(unit), song.name or "an air", reached), unit)
    endTurn(combat, unit, behavior.speed or Combat.FOCUS_SPEED)
    return true
end

-- The initiative the unit's "Wait" action would land it at right now, for the timeline ghost.
-- Mirrors whichever of wait/focus/defend/overwatch/perform its waitBehavior selects (and their speed
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
        Combat.logEvent(combat, "wait", string.format("%s holds position.", unitName(unit)), unit)
    end
    endTurn(combat, unit, moved and 0 or Combat.WAIT_COST)
    return true
end

-- ---------------------------------------------------------------------------
-- Movement
-- ---------------------------------------------------------------------------

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- WATCHED GROUND. A unit holding the Overwatch stance does not merely shoot whoever walks into range
-- (Combat.triggerOverwatch) -- the tiles orthogonally beside it are DEAR to enter, by the `zone` its
-- stance declares. That is this game's reading of a zone of control, and it is deliberately a COST
-- rather than the hard stop Fire Emblem and Those Who Rule use:
--
--   * a cost degrades. A fast body can still shove through a watched lane by spending its whole move
--     on it, which is a decision; a hard stop is just a "no".
--   * a cost needs no new concept. `moveCost` is a number the Dijkstra already weights, and rough
--     ground has always meant exactly this -- so every existing exemption applies for free (a flier
--     never reads the ground at all, and Status.costMultiplier already discounts a whole move, which
--     makes Hasted the counter without a line of code).
--   * a cost is the right SIZE for this board. An 8x8 field with four bodies a side and movement 3-4
--     cannot carry a global hard stop: four bodies would control half the board and the fight would
--     lock on turn two. See docs/classes.md.
--
-- It is ALSO the half of Overwatch that was missing. The stance costs a whole turn to enter and bought
-- only a conditional shot, which an enemy answered by walking around the firing line. Now the two
-- halves compound without being wired to each other: dear ground means more steps spent in range,
-- and more steps in range means more shots.
--
-- Returns 0 when nobody opposing `unit` holds the stance, which is nearly every tile of nearly every
-- fight -- one cheap pass over a roster that is never longer than a dozen bodies, so it wants no cache.
function Combat.watchTax(combat, unit, x, y)
    if not (combat and unit and combat.units) then return 0 end
    local tax = 0
    for _, watcher in ipairs(combat.units) do
        local zone = watcher.alive and watcher.overwatch and watcher.overwatch.zone
        if zone and zone > 0 and watcher.side ~= unit.side then
            -- Orthogonal only, matching DIRS and the shape of every other adjacency in this file.
            if math.abs(watcher.x - x) + math.abs(watcher.y - y) == 1 and zone > tax then tax = zone end
        end
    end
    return tax
end

-- EASY GOING. The most the GROUND may charge this body to stand on (x, y), or nil when nothing eases
-- it -- which is the overwhelming common case, and why this returns nil rather than a large number.
--
-- Two sources, both of which cap rather than discount, so neither can make a tile cheaper than open
-- field:
--
--   * the body's own gear (`terrainEase` on a grid item -- the Trackless Boots). Read off the grid
--     rather than off a status, the way Combat.isFlying and Combat.isPhasing are, because it is a
--     permanent property of what you are wearing.
--   * an ALLY standing beside the tile who carries `escortsMovement` (the Surveyor's Chain). This is
--     the support half and the genuinely new verb: a body that makes the ground cheap for the column
--     walking past it, rather than for itself.
--
-- Deliberately does NOT touch the watch tax. Good boots are an answer to bad ground, not to a spear
-- pointed at you: stepTerrainCost caps the terrain with this and then adds the tax on top.
-- The two easing fields a body's GRID declares, read once per character and cached on the unit.
--
-- The cache is not an optimisation to be traded away later, it is the difference between this feature
-- working and the game hanging. stepTerrainCost runs per tile inside a Dijkstra, that Dijkstra runs per
-- candidate move inside the enemy AI's search, and Character.eachItem ALLOCATES a fresh table on every
-- call -- so scanning the grid per tile per adjacent ally turned a twenty-second test suite into one
-- that does not finish. Everything here is a plain field read now.
--
-- Keyed on `unit.char` rather than stamped once, so a shapeshift invalidates it for free: transform.lua
-- swaps the character wholesale (a bear wears no boots), and a cache pinned to the unit alone would
-- have kept the wearer's footing inside the animal.
local function gridEase(unit, field)
    if not (unit and unit.char) then return nil end
    local cache = unit._easeCache
    if not (cache and cache.char == unit.char) then
        cache = { char = unit.char }
        for _, item in ipairs(Character.eachItem(unit.char)) do
            local t, e = item.terrainEase, item.escortsMovement
            if t and (not cache.terrainEase or t < cache.terrainEase) then cache.terrainEase = t end
            if e and (not cache.escort or e < cache.escort) then cache.escort = e end
        end
        unit._easeCache = cache
    end
    return cache[field]
end

function Combat.terrainEase(combat, unit, x, y)
    local ease = gridEase(unit, "terrainEase")
    if not (combat and combat.units and unit) then return ease end
    for _, ally in ipairs(combat.units) do
        -- Cheapest tests first: the distance check is arithmetic on fields, the grid read is a table
        -- lookup, and neither happens for a body on the wrong side or off the field.
        if ally.alive and ally ~= unit and ally.side == unit.side
            and math.abs(ally.x - x) + math.abs(ally.y - y) <= 1 then
            local e = gridEase(ally, "escort")
            if e and (not ease or e < ease) then ease = e end
        end
    end
    return ease
end

-- The cost of putting this body's footprint on (x, y): the roughest cell under it, capped by whatever
-- eases the going, plus whatever is watching the tile. A flier pays a flat 1 and reads none of it --
-- it is off the ground entirely, so neither the terrain nor the boots that answer terrain apply, and
-- neither does a spear planted in it.
--
-- THE ONE PLACE A TILE IS PRICED. moveGraph (the Dijkstra), Combat.planMoveVia (a hand-steered route)
-- and Combat.walkStop (a walk cut short) all call this. They used to derive it three times over --
-- the two route-finders fuse cost into a legality loop, and each had its own copy of the arithmetic --
-- which was survivable while the only term was terrain and became a real hazard the moment a tile's
-- price could depend on the board: three readers that disagree mean the move overlay offers a tile the
-- route preview will not walk to. Add a term here and all three learn it at once.
local function stepTerrainCost(combat, unit, x, y, flying)
    if flying then return 1 end
    local tiles = combat.arena and combat.arena.tiles
    local worst = 0
    for _, c in ipairs(Combat.cellsAt(unit.w or 1, unit.h or 1, x, y)) do
        local row = tiles and tiles[c.y]
        local cell = row and row[c.x]
        local mc = (cell and cell.moveCost) or 1
        if mc > worst then worst = mc end
    end
    local ease = Combat.terrainEase(combat, unit, x, y)
    if ease and worst > ease then worst = ease end
    return worst + Combat.watchTax(combat, unit, x, y)
end

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

-- Does `unit` walk THROUGH bodies? True when any grid item carries a `moveBehavior` of mode "phase"
-- (the Sidelong Greaves). Read once per move graph, and read off the grid rather than off a status,
-- because it is a permanent property of what you are wearing.
--
-- Deliberately the same `moveBehavior` slot the Blink stone uses, and therefore mutually exclusive with
-- it by construction: a unit cannot both teleport and phase, because both answer "what is this unit's
-- movement", and an item that changes a verb is the one shape this codebase already has for that
-- (see data/items/ability/ability_blink.lua). Two of them in one grid is a loadout the player has
-- built badly, not a case anyone has to resolve -- Combat.blinkItem takes the first teleport it finds
-- and this takes the first phase, and neither can see the other.
function Combat.isPhasing(unit)
    if not (unit and unit.char) then return false end
    for _, item in ipairs(Character.eachItem(unit.char)) do
        local mb = item.moveBehavior
        if mb and mb.mode == "phase" then return true end
    end
    return false
end

local function moveGraph(combat, unit)
    local arena = combat.arena
    local budget = flatStat(unit, "movement")
    local flying = Combat.isFlying(unit)
    -- A phaser treats an enemy body the way everyone already treats a friendly one: transit, never
    -- footing. It still cannot STOP on the tile (Combat.reachable drops every occupied node whoever
    -- is standing there), so what phasing buys is passage through a line, not the ability to share a
    -- square -- which is exactly the thing a shield wall in a corridor is for, and exactly the answer
    -- to it this game did not have.
    local phasing = Combat.isPhasing(unit)
    -- The body's footprint. The Dijkstra walks the ANCHOR (top-left) cell by cell; every candidate
    -- anchor is judged by whether the whole w×h block would fit there, so a 2×2 body cannot thread a
    -- one-tile gap. 1×1 collapses to the single-tile logic this always was.
    local w, h = unit.w or 1, unit.h or 1

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
                -- Judge every cell the body would cover at this anchor. An enemy in ANY of them bars
                -- the move outright; a friendly (or the unit's own current cells, ignored) is transit
                -- only, so the anchor is walked through but not stopped on. Objects and, for a
                -- non-flier, impassable terrain always bar the way. Terrain cost is the roughest cell
                -- the body crosses (flying pays a flat 1 per step), so a wide body is slowed by the
                -- worst ground under it -- matching how a single tile was costed before.
                local ok, enemy, otherUnit = true, false, false
                for _, c in ipairs(Combat.cellsAt(w, h, nx, ny)) do
                    if c.x < 1 or c.x > arena.cols or c.y < 1 or c.y > arena.rows then ok = false; break end
                    local cell = arena.tiles[c.y][c.x]
                    if not (flying or cell.walkable) then ok = false; break end
                    if Combat.objectBlocksAt(combat, c.x, c.y) then ok = false; break end
                    local occ = Combat.unitAt(combat, c.x, c.y)
                    if occ and occ ~= unit then
                        if occ.side ~= unit.side and not phasing then enemy = true; ok = false; break end
                        otherUnit = true
                    end
                end
                if ok and not enemy then
                    -- Priced by the shared reader rather than in the loop above: the legality question
                    -- (may this body stand here) and the cost question (what does standing here cost)
                    -- are different, and only the second one grows terms. See stepTerrainCost.
                    local ncost = cur.cost + stepTerrainCost(combat, unit, nx, ny, flying)
                    if ncost <= budget then
                        local nk = key(nx, ny)
                        local existing = best[nk]
                        if not existing or ncost < existing.cost then
                            local node = { x = nx, y = ny, cost = ncost, steps = cur.steps + 1,
                                           fromKey = key(cur.x, cur.y), occupied = otherUnit }
                            best[nk] = node
                            frontier[#frontier + 1] = node
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

-- The reachable set as a LIST in fixed board order (top-left to bottom-right), for the callers that
-- SCAN it hunting a best tile.
--
-- Those scans keep the first candidate on a tie ("closest, then fewest steps" leaves two mirror
-- tiles genuinely even, which on a symmetric board is ordinary rather than rare), so whatever order
-- they are handed IS the tie-break. pairs() over "x,y" keys gives an order that holds still within
-- one build and is promised by nothing across two -- so the same unit, in the same position, could
-- walk somewhere else on another machine. Iterate this wherever the order can decide anything;
-- index the map directly when all you want is a lookup.
--
-- Pass `reachable` to reuse a set already computed rather than walking the graph twice.
function Combat.reachableList(combat, unit, reachable)
    local out = {}
    for _, node in pairs(reachable or Combat.reachable(combat, unit)) do
        out[#out + 1] = node
    end
    table.sort(out, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    return out
end

-- How long the ROAD to a goal is from every tile on the board: a Dijkstra run outward FROM the goal,
-- with no movement budget, so it answers "how far is the walk from here" for ground far beyond this
-- turn's reach. Combat.reachable answers the other question -- "where can I stop this turn" -- and an
-- approaching unit needs both. Ranking stand tiles by the crow's-flight gap alone is what makes a
-- unit walk up to a wall and stare at it forever: every tile that rounds the corner is FARTHER as the
-- crow flies, so standing still always wins and the detour is never taken.
--
-- Bodies are ignored, deliberately. A unit standing somewhere is a thing that will have moved by the
-- time the walker gets there, and treating an ally as a permanent obstruction is its own stall in a
-- corridor. Terrain, standing objects (walls, props) and the mover's own footprint are all honoured,
-- since none of those wander off.
--
-- `goal` is a unit (a wide one seeds every cell it covers) or a plain { x, y }. Entering a tile costs
-- that tile's `moveCost` (a flier pays a flat 1), the same currency Combat.reachable spends, so a
-- field cost and a move cost are comparable numbers. Returns `{ [key] = cost }` keyed "x,y" like
-- Combat.reachable; a MISSING key means no road at all from that tile, which the caller answers for
-- itself (models/ai.lua ranks the roadless behind everything, by straight line).
--
-- `ignore` is one standing object to run the field as though it were already gone. That is the whole
-- of "would breaking this open my way": field it twice, once honestly and once without the blocker,
-- and the difference IS what tearing the thing down is worth in tiles walked (models/ai.lua's
-- clearing pass). One object at a time on purpose -- a hole one tile wide is a road, so asking about
-- each blocker singly is the question that matches how a body actually gets through.
function Combat.travelField(combat, unit, goal, ignore)
    local arena = combat and combat.arena
    if not (arena and goal and goal.x and goal.y) then return {} end
    local flying = Combat.isFlying(unit)
    local w, h = unit.w or 1, unit.h or 1

    -- May the body stand with its anchor here? Terrain and standing objects only -- see above.
    local function fits(x, y)
        for _, c in ipairs(Combat.cellsAt(w, h, x, y)) do
            if c.x < 1 or c.x > arena.cols or c.y < 1 or c.y > arena.rows then return false end
            if not (flying or arena.tiles[c.y][c.x].walkable) then return false end
            local obj = Combat.objectAt(combat, c.x, c.y)
            if obj and obj ~= ignore and obj.blocksMove then return false end
        end
        return true
    end

    -- What it costs to walk INTO this anchor: the roughest ground under the body, matching moveGraph.
    local function stepCost(x, y)
        local worst = 0
        for _, c in ipairs(Combat.cellsAt(w, h, x, y)) do
            local cell = arena.tiles[c.y] and arena.tiles[c.y][c.x]
            local mc = flying and 1 or ((cell and cell.moveCost) or 1)
            if mc > worst then worst = mc end
        end
        return worst
    end

    -- Seeded at cost 0 on the goal's own cells whether or not the body would FIT there -- the goal is
    -- usually a foe, and a tile you cannot stand on is still a tile you can walk up to.
    local field, frontier = {}, {}
    for _, c in ipairs(Combat.cellsAt(goal.w or 1, goal.h or 1, goal.x, goal.y)) do
        if c.x >= 1 and c.x <= arena.cols and c.y >= 1 and c.y <= arena.rows and field[key(c.x, c.y)] == nil then
            field[key(c.x, c.y)] = 0
            frontier[#frontier + 1] = { x = c.x, y = c.y, cost = 0 }
        end
    end

    while #frontier > 0 do
        local bi = 1
        for i = 2, #frontier do
            if frontier[i].cost < frontier[bi].cost then bi = i end
        end
        local cur = table.remove(frontier, bi)
        if field[key(cur.x, cur.y)] == cur.cost then -- skip a node a cheaper path has since superseded
            -- Walking outward from the goal, the forward step is neighbour -> cur, so the toll is
            -- CUR's ground. That is what makes the field read as a true forward walk cost.
            local toll = stepCost(cur.x, cur.y)
            for _, d in ipairs(DIRS) do
                local nx, ny = cur.x + d[1], cur.y + d[2]
                local nk, ncost = key(nx, ny), cur.cost + toll
                if (field[nk] == nil or ncost < field[nk]) and fits(nx, ny) then
                    field[nk] = ncost
                    frontier[#frontier + 1] = { x = nx, y = ny, cost = ncost }
                end
            end
        end
    end
    return field
end

-- Every cell a unit could strike THIS turn with a `range`-reach weapon: for the origin tile
-- and each tile it can move to, the Manhattan diamond of radius `range`, clamped to the arena.
-- Returns `{ [key] = { x, y, fromX, fromY, moveCost } }`, where from/moveCost is the CHEAPEST
-- move tile to stand on to hit that cell (the origin, at moveCost 0, when already in reach).
-- One structure serves both the red default-attack (threat) highlight -- its keys, minus the
-- move set, are the "beyond movement" band -- and click-to-attack (move to `from`, then strike).
-- `range` is the weapon's BASE range; each stand tile's `range` field bonus (high ground, a
-- vantage object) extends the reach from that tile FOR A SIGHTED ability only (Combat.fieldRangeBonus,
-- which `requiresSight` gates), matching what Combat.useItem allows once the unit stands there. `reachable` defaults to Combat.reachable(combat, unit); the battle state
-- passes its live set so a unit that has already moved only threatens from where it now stands.
-- `requiresSight` (the default weapon's `ab.requiresSight`) drops any target cell a stand tile has
-- no clear line to, so a bow's red reach stops at terrain cover.
function Combat.attackReach(combat, unit, range, reachable, requiresSight, minRange)
    range = range or 1
    minRange = minRange or 0
    reachable = reachable or Combat.reachable(combat, unit)

    -- Stand tiles: the origin (cost 0) plus every reachable move tile, in board order -- the cheapest
    -- stand wins a cell below, and equal-cost stands are settled by that order rather than by however
    -- the set happened to be keyed (see Combat.reachableList; `fromX/fromY` decides which tile the
    -- blow is thrown from, so an unstable answer here moves the fight).
    local stands = { { x = unit.x, y = unit.y, cost = 0 } }
    for _, node in ipairs(Combat.reachableList(combat, unit, reachable)) do
        stands[#stands + 1] = { x = node.x, y = node.y, cost = node.cost }
    end

    local w, h = unit.w or 1, unit.h or 1
    local out = {}
    for _, s in ipairs(stands) do
        -- The same reach the cast gate computes (Combat.abilityRange, which Combat.useItem checks):
        -- the stand tile's sighted field bonus on top, a range-cutting debuff (Blind) taken back off,
        -- floored at 1. The malus has to bite HERE too or the band -- and every preview, cursor and
        -- click plan keyed off it -- lights tiles useItem then refuses, and the click dies saying
        -- nothing.
        local r = math.max(1, range + Combat.fieldRangeBonus(combat, requiresSight, s.x, s.y)
            - Status.rangeMalus(unit))
        -- A wide body threatens from EVERY cell it would cover when standing at this anchor: the reach
        -- is the union of the Manhattan diamonds cast from each cell (one cell, the anchor, for a 1×1
        -- body -- unchanged). `fromX/fromY` stays the stand ANCHOR (where the click plan sends the unit
        -- to move); sight is drawn from the actual striking cell.
        for _, bc in ipairs(Combat.cellsAt(w, h, s.x, s.y)) do
            for dx = -r, r do
                for dy = -r, r do
                    local d = math.abs(dx) + math.abs(dy)
                    if d <= r and d >= minRange then
                        local x, y = bc.x + dx, bc.y + dy
                        -- Impassable tiles (solid obstacles, which also fully block sight) can never
                        -- hold a target, so they're never part of the reach -- no red highlight, and
                        -- click-to-attack can't fire into a wall.
                        if x >= 1 and x <= combat.arena.cols and y >= 1 and y <= combat.arena.rows
                            and combat.arena.tiles[y][x].walkable
                            and (not requiresSight or Combat.hasLineOfSight(combat, bc.x, bc.y, x, y)) then
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
    end
    return out
end

-- Every tile some living unit hostile to `side` could reach-and-strike this turn with its default
-- weapon, unioned across those units. Returns two keyed sets:
--   cells   -- "x,y" -> { x, y }              the threatened tiles themselves
--   sources -- "x,y" -> { { x, y }, ... }     where each threat is standing, so a tile can trace back
--
-- Two callers read this and they want opposite things from it, which is exactly why it lives here
-- rather than in either of them: the battle state paints the party's danger zone purple (side =
-- "party"), and the AI asks how exposed a tile it is thinking of standing on would be (side = its
-- own). A `control == "none"` decoy never advances and so threatens nothing.
--
-- `skip` optionally excludes one unit -- the AI passes itself, since a unit is not a danger to its
-- own footing and would otherwise price every tile it can reach as threatened.
function Combat.threatMap(combat, side, skip)
    local cells, sources = {}, {}
    for _, u in ipairs(combat.units) do
        if u.alive and u.side ~= side and u.control ~= "none" and u ~= skip then
            local weapon = Combat.defaultWeapon(u.char)
            local ab = weapon and weapon.activeAbility
            local range = ((ab and ab.range) or 1) + Combat.adjacencyRangeBonus(u.char, weapon)
            local reach = Combat.attackReach(combat, u, range, Combat.reachable(combat, u),
                ab and ab.requiresSight, Combat.abilityMinRange(ab))
            for k, cell in pairs(reach) do
                if not cells[k] then cells[k] = { x = cell.x, y = cell.y } end
                local src = sources[k]
                if not src then src = {} sources[k] = src end
                src[#src + 1] = { x = u.x, y = u.y }
            end
        end
    end
    return cells, sources
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
-- `fromX, fromY` is the tile it came FROM, and only a real ground crossing has one: the two call sites
-- that walk or shove a unit off one tile and onto another (Combat.stepMove, shoveStep) pass it, and
-- every other caller leaves it nil because there is no honest answer -- a blink came from nowhere it
-- can be said to have crossed. Read by Combat.layTrail alone, for an item that lays its ground on the
-- tile it just vacated rather than the one it is standing on.
-- Traps, hazards, and auras deliberately ignore `reason` -- the ground does not care how you came to
-- stand on it. Only the two effects of CROSSING it read `reason`, and both take "walk" or "forced"
-- alike: Status.onEnterTile, so that Bleed costs a unit blood for every tile it crosses under its own
-- weight (walked OR dragged) but nothing for a blink, and Combat.layTrail, so a trail is pressed by
-- feet on the ground and never by a blink or a swap. `reason` is optional and
-- defaults to nil (no ground crossing), so a call site that forgets it errs toward firing nothing.
--
-- The unit must already stand on (x, y) when this is called: a trap may kill it, and the death path
-- reads its position. Callers move it first, then announce the arrival.
function Combat.enterTile(combat, unit, x, y, reason, fromX, fromY)
    local trap = Trap.at(combat, x, y)
    -- Feather Boots walk over any trap unharmed. The guard sits at this one chokepoint, so the wearer
    -- is spared whether it strode onto the trap, was shoved onto it, or was conjured on top of one --
    -- but hazards (a spreading fire, quicksand) still bite: the boots dodge blades, not the ground.
    if trap and not Combat.ignoresTraps(unit) then Trap.trigger(combat, trap, unit) end
    -- Ground the unit's own kit paints under it (Pilgrim's Sandals). Laid BEFORE the hazard/aura pass
    -- below, so a trail granting a zone-bound status is already under the unit's feet when Hazard.reap
    -- decides what to keep -- otherwise the wearer's own blessing would be stripped on the very tile
    -- that just granted it. Placing fires the fresh hazard's onEnter for the occupant, and the
    -- Hazard.onEnter pass below reaches it a second time: a refresh, which neither stacks nor logs.
    if unit.alive and (reason == "walk" or reason == "forced") then Combat.layTrail(combat, unit, fromX, fromY) end
    -- Ground this body HOLDS OPEN travels with it (Hazard.carry): heave a banner and its rally square
    -- goes along, rather than staying lit over the ground the standard used to stand on. Needs the tile
    -- it came from to know the delta, so it rides the same `walk`/`forced` gate the trail does -- a
    -- banner never walks anywhere, so in practice this is the displaced case and only the displaced
    -- case. Before layIncense, so a censer's cloud is fixed by that re-lay instead of shifted twice.
    if unit.alive and fromX and fromY and (reason == "walk" or reason == "forced") then
        Hazard.carry(combat, unit, x - fromX, y - fromY)
    end
    -- The censer's cloud keeps up with the bearer, and unlike the trail above it does so however the
    -- bearer arrived: `reason` is not read, because smoke is carried rather than pressed by feet, so a
    -- blink brings it along. Laid before the reap pass below for the same reason the trail is -- the
    -- bearer stands in its own cloud, and reaping first would strip the blessing it just laid.
    if unit.alive then Combat.layIncense(combat, unit) end
    if unit.alive then
        Hazard.onEnter(combat, unit, x, y)
        Hazard.reap(combat, unit)
    end
    -- Last, and re-checking `alive`: a trap or hazard may already have killed the unit on this very
    -- tile, and a corpse does not bleed.
    if unit.alive and (reason == "walk" or reason == "forced") then
        Status.onEnterTile(combat, unit)
    end
    -- A body wider than one tile also stands on the cells beyond its anchor. The once-per-move effects
    -- above (trail, carried ground, bleed) fired for the body as a whole; here we spring only the
    -- PER-TILE ground -- a trap or a hazard -- under the rest of the footprint, so a 2×2 ogre setting
    -- a foot on a trap trips it wherever under its bulk that trap sits. A 1×1 body skips this entirely.
    if unit.alive and ((unit.w or 1) > 1 or (unit.h or 1) > 1) then
        for _, c in ipairs(Combat.unitCells(unit)) do
            if unit.alive and not (c.x == x and c.y == y) then
                local extraTrap = Trap.at(combat, c.x, c.y)
                if extraTrap and not Combat.ignoresTraps(unit) then Trap.trigger(combat, extraTrap, unit) end
                if unit.alive then Hazard.onEnter(combat, unit, c.x, c.y) end
            end
        end
        if unit.alive then Hazard.reap(combat, unit) end
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
    local w, h = unit.w or 1, unit.h or 1
    local seen = { [key(unit.x, unit.y)] = true }
    local cost = 0
    for i = 2, #cells do
        local c, p = cells[i], cells[i - 1]
        if math.abs(c.x - p.x) + math.abs(c.y - p.y) ~= 1 then return nil, "not contiguous" end
        local k = key(c.x, c.y)
        if seen[k] then return nil, "revisit" end -- catch a double-back (incl. onto the origin) first
        -- Judge the whole footprint at this anchor, exactly as moveGraph does: every covered cell must
        -- be on the board and walkable (a flier excepted), clear of objects, and clear of any OTHER
        -- unit -- an enemy bars the way, a friendly is transit only (never a stop), and the body's own
        -- current cells (occ == unit; this is a pure check, the unit hasn't moved) never block it.
        for _, fc in ipairs(Combat.cellsAt(w, h, c.x, c.y)) do
            if fc.x < 1 or fc.x > arena.cols or fc.y < 1 or fc.y > arena.rows then return nil, "off grid" end
            local tile = arena.tiles[fc.y][fc.x]
            if not (flying or tile.walkable) then return nil, "blocked" end
            if Combat.objectBlocksAt(combat, fc.x, fc.y) then return nil, "wall" end
            local occ = Combat.unitAt(combat, fc.x, fc.y)
            if occ and occ ~= unit then
                -- The mover may pass THROUGH a friendly but must not stop on one (the destination is
                -- the last cell); an enemy bars the way outright, transit or not.
                if i == #cells or occ.side ~= unit.side then return nil, "occupied" end
            end
        end
        seen[k] = true
        -- Priced by the same reader the derived path uses, so a hand-steered detour costs exactly what
        -- walking it costs -- including the ground watched by an enemy's Overwatch. This used to
        -- re-derive the terrain arithmetic locally; see stepTerrainCost on why it no longer may.
        cost = cost + stepTerrainCost(combat, unit, c.x, c.y, flying)
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
        string.format("%s moves to (%d, %d).", unitName(unit), dest.x, dest.y), unit)
    -- `flying` and `mult` are read off the unit ONCE, here, and carried for the length of the walk:
    -- both are only wanted if the route is cut short (haltWalk re-prices it), and the walk must be
    -- priced by the unit as it set off. Mired is the very thing that stops a walk and it doubles
    -- costMultiplier, so re-reading it at the halt would charge the interrupted walk double for
    -- being interrupted.
    return { unit = unit, path = plan.path, index = 1, walked = 0,
             flying = Combat.isFlying(unit), mult = Status.costMultiplier(unit) }
end

-- (stepTerrainCost now lives beside moveGraph, at the head of the Movement section: it is the one
-- place a tile is priced, and all three route-finders call it. It was defined here, third and last,
-- back when the other two carried their own copies of the arithmetic.)

-- The body standing where `unit` would come to rest with its anchor on (x, y) -- any OTHER unit under
-- the footprint -- or nil when the tile is free to stand on. A route may pass THROUGH a friendly and
-- must never stop on one (moveGraph, Combat.reachable, Combat.planMoveVia), which those three enforce
-- for the tile a walk was AIMED at and cannot enforce for the tile a walk cut short lands on. This is
-- that same question asked of a tile the route only meant to cross.
local function bodyInTheWay(combat, unit, x, y)
    for _, c in ipairs(Combat.cellsAt(unit.w or 1, unit.h or 1, x, y)) do
        local occ = Combat.unitAt(combat, c.x, c.y)
        if occ and occ ~= unit then return occ end
    end
    return nil
end

-- Cut a walk off where it stands: the tiles still ahead of it are never entered, and the move is
-- re-priced down to the ground actually crossed (at the multiplier the unit set off under -- see
-- beginMove). The move itself stays SPENT: `turn.moved` is not given back, so a unit bogged down two
-- tiles into a five-tile route does not get to try a different five tiles. It may still act from where
-- it stopped, exactly as any unit that finished its walk may.
local function haltWalk(combat, walk)
    walk.halted = true
    -- NOBODY COMES TO REST ON A BODY. A route walks THROUGH a friendly and stops only on clear ground,
    -- which the route-finders enforce for the tile a walk was AIMED at -- and a halt is by definition a
    -- resting place nobody planned. So the halt backs the unit out along the ground it just crossed
    -- until it is on a tile it fits on; the origin always fits (it stood there a moment ago), so this
    -- ends. Deliberately no second Combat.enterTile: those tiles sprang whatever they held on the way
    -- IN, and stepping back off a friend is not a fresh arrival.
    --
    -- Today nothing reaches this loop: the only thing that halts a walk is stopping GROUND, and
    -- Combat.stepMove refuses to enter a mire it could not stand in one step earlier. It is the floor
    -- under that check rather than a second copy of it -- what must not happen is a body resting on a
    -- body, and that is worth stating once at the one place a walk can end somewhere it did not choose.
    while walk.index > 1 and bodyInTheWay(combat, walk.unit, walk.unit.x, walk.unit.y) do
        walk.index = walk.index - 1
        local back = walk.path[walk.index]
        walk.unit.x, walk.unit.y = back.x, back.y
    end
    -- Priced by the ground CROSSED, which includes a tile it was pushed back off: the stagger back is
    -- not a second walk, and the unit really did wade in there.
    combat.turn.moveCost = math.floor((walk.walked or 0) * (walk.mult or 1) + 0.5)
    Combat.logEvent(combat, "move",
        string.format("%s is stopped at (%d, %d).", unitName(walk.unit), walk.unit.x, walk.unit.y),
        walk.unit)
end

-- Would the ground on (x, y) -- anywhere under this body's footprint -- land a movement-stopping
-- status on `unit`? Dry-run through Hazard.preview, so nothing on the board is touched and nobody is
-- mired to find the answer out: this is asked once per route tile, every frame the cursor moves.
-- An immunity (the Slipchain Charm) answers no, exactly as it will when the unit really steps there.
local function groundStopsMovement(combat, unit, x, y)
    for _, c in ipairs(Combat.cellsAt(unit.w or 1, unit.h or 1, x, y)) do
        for _, h in ipairs(Hazard.allAt(combat, c.x, c.y)) do
            local preview = Hazard.preview(h.id, h.amount)
            for _, st in ipairs((preview and preview.statuses) or {}) do
                if st.def and st.def.stopsMovement and not Status.isImmune(unit, st.id) then return true end
            end
        end
    end
    return false
end

-- How a walk down `path` (origin-first) would really end: the INDEX of the tile the unit comes to rest
-- on -- short of the destination when the ground stops it -- and the terrain cost of the tiles it
-- actually crosses to get there. Pure: it reads the board and changes nothing, which is what lets the
-- route preview draw an honest line into a quicksand patch (states/battle.lua) instead of promising a
-- walk the sand will cut in half.
--
-- The carry rule mirrors Combat.stepMove's: only ground that lands the status on a unit not already
-- bearing one halts it, so a route that wades out of the sand and back in stops on the tile it
-- re-enters. Traps and overwatch are deliberately NOT modelled here -- a route preview does not know
-- what an unrevealed trap will do, and never has.
function Combat.walkStop(combat, unit, path)
    local flying = Combat.isFlying(unit)
    local carrying = Status.stopsMovement(unit)
    local cost = 0
    for i = 2, #path do
        local t = path[i]
        local grants = groundStopsMovement(combat, unit, t.x, t.y)
        -- Stopping ground with a friendly already standing in it is never entered at all: the walk ends
        -- on the tile BEFORE it, and never pays for the tile it refused. Mirrors Combat.stepMove's
        -- pre-step check, so the drawn route stops on the tile the feet will.
        if grants and not carrying and bodyInTheWay(combat, unit, t.x, t.y) then return i - 1, cost end
        cost = cost + stepTerrainCost(combat, unit, t.x, t.y, flying)
        if grants and not carrying then return i, cost end
        carrying = grants
    end
    return #path, cost
end

-- Carry the walk's unit onto the next tile of its path, setting off everything that tile holds:
-- an opposing trap, and the on-entry effect of any hazard standing on it. Returns true while the
-- walk has further to go, so a caller can drive it either flat-out (moveUnit) or a tile per
-- animation beat (states/battle.lua). A unit killed en route -- a spike trap, a fire it walked
-- into -- stops on the tile it fell on rather than sliding on to the destination, and so does a unit
-- MIRED en route (see the halt below): both are a route that ends early, and both end it here.
function Combat.stepMove(combat, walk)
    if walk.halted or not walk.unit.alive or walk.index >= #walk.path then return false end
    -- Read BEFORE the step: only a status GAINED on the tile ahead halts the walk. A unit that set off
    -- already mired -- standing in the sand when its turn came round -- has to be able to wade out, and
    -- would otherwise be stopped by its own condition after a single tile, every turn, forever.
    local wasStopped = Status.stopsMovement(walk.unit)
    -- STOPPED SHORT. Ground that would both mire this unit AND leave it standing on a body is ground it
    -- does not step onto: a route walks through a friendly and may never come to rest on one, and the
    -- sand would make it do exactly that. The walk ends on the last clear tile behind it, unmired.
    -- Asked BEFORE the step rather than untangled after it, because the alternative -- wade in, get
    -- caught, stagger back off the ally -- hands the unit a status from a tile it is not standing on
    -- and then (Mired being zone-bound) drops it again a moment later, which is a great deal of noise
    -- for the same resting place. Combat.walkStop answers this identically, so the route preview draws
    -- its line stopping on this same tile.
    local ahead = walk.path[walk.index + 1]
    if not wasStopped and groundStopsMovement(combat, walk.unit, ahead.x, ahead.y)
        and bodyInTheWay(combat, walk.unit, ahead.x, ahead.y) then
        haltWalk(combat, walk)
        return false
    end
    walk.index = walk.index + 1
    local tile = walk.path[walk.index]
    local fromX, fromY = walk.unit.x, walk.unit.y -- the tile being vacated, for a trail laid behind
    walk.unit.x, walk.unit.y = tile.x, tile.y
    walk.walked = (walk.walked or 0) + stepTerrainCost(combat, walk.unit, tile.x, tile.y, walk.flying)
    Combat.enterTile(combat, walk.unit, tile.x, tile.y, "walk", fromX, fromY)
    -- A unit walking into an opposing Overwatch stance's firing line is shot for it. Only a walk
    -- triggers this (not a knockback or a summon appearing), so it lives here rather than in enterTile.
    Combat.triggerOverwatch(combat, walk.unit)
    -- BOGGED DOWN. Everything this tile could do to the unit has now happened -- the ground it stepped
    -- on, and the shots that ground crossing invited -- so this is the first honest moment to ask
    -- whether the unit is still going anywhere. Asked of the STATUS rather than of the hazard, so it is
    -- one rule and not two: stepping into quicksand stops you because quicksand mires you, and an
    -- overwatching Mired Kris that mires you mid-route stops you for exactly the same reason.
    if walk.unit.alive and not wasStopped and Status.stopsMovement(walk.unit) then
        haltWalk(combat, walk)
    end
    return true
end

-- Walk a plan out to its end, right now. `capture` asks for the route back as it was actually taken:
-- a list of { x, y, fromX, fromY, fx } , one entry per tile entered, each carrying the cues that tile
-- raised as the unit arrived on it.
--
-- That list is what lets the model finish a move before anything is drawn. The traps, hazards and
-- overwatch shots a walk sets off all resolve here in one go; batching their cues per tile means a
-- view can still play the walk back a tile at a time and have each trap go off on the tile that
-- holds it, without the model's own progress being metered by a frame clock.
--
-- The route ends where the unit ended, which is short of the destination when something on the way
-- killed it. One loop rather than two, so the flat-out walk and the watched one cannot drift apart.
local function walkOut(combat, plan, capture)
    local walk = Combat.beginMove(combat, plan)
    local unit = plan.unit
    local steps = capture and {} or nil
    while true do
        local fromX, fromY = unit.x, unit.y
        if not Combat.stepMove(combat, walk) then break end
        if capture then
            steps[#steps + 1] = { x = unit.x, y = unit.y, fromX = fromX, fromY = fromY,
                                  fx = Combat.drainFx(combat) }
        end
    end
    -- The move initiative this walk ran up, read off the turn record it was written to. A walk that
    -- KILLED its walker leaves no record to read (leaveTurn took the turn with the body) and owes 0:
    -- there is no turn left for the ground to be billed to, and nobody to bill it.
    return steps, (combat.turn and combat.turn.moveCost) or 0
end

-- Walk `plan` out and hand back the route for a view to replay. See walkOut. Note this DRAINS the
-- cue queue as it goes -- the cues live in the returned steps instead, and the caller is expected to
-- feed them to its animation controller. Callers that just want the move to happen want moveUnit.
function Combat.runMove(combat, plan)
    return walkOut(combat, plan, true)
end

-- Move a unit to (x, y) if reachable this turn, all in one go. The headless equivalent of the
-- battle state's watchable walk (planMove -> beginMove -> stepMove per tile): same legality gate,
-- same traps sprung, same initiative owed. Leaves the cue queue alone, so a headless caller that
-- never drains is unaffected. Returns ok plus the move initiative it charged.
function Combat.moveUnit(combat, unit, x, y)
    local plan, reason = Combat.planMove(combat, unit, x, y)
    if not plan then return false, reason end
    local _, cost = walkOut(combat, plan, false)
    return true, cost
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

-- Can `unit` be shoved onto (x, y)? Returns ok, blocker, kind -- where `kind` is "unit", "wall" or
-- "prop" and a nil blocker on a failed step means the way is barred by the map itself (an edge, or
-- impassable terrain), which is unbreakable and so takes nothing back.
local function canShoveInto(combat, x, y)
    local row = combat.arena and combat.arena.tiles and combat.arena.tiles[y]
    local cell = row and row[x]
    if not (cell and cell.walkable) then return false, nil end
    -- A standing object bars the shove -- and, unlike the terrain, it can be slammed apart. A barrel
    -- shoved into is a barrel HIT, so driving a body into one sets it off (models/prop.lua).
    if Combat.objectBlocksAt(combat, x, y) then
        local obj, kind = Combat.objectAt(combat, x, y)
        return false, obj, kind
    end
    local blocker = Combat.unitAt(combat, x, y)
    if blocker then return false, blocker, "unit" end
    return true, nil
end

-- The whole-body form of canShoveInto: can `unit` slide so its ANCHOR moves by (dx, dy)? Every cell
-- the body would then cover is tested, and the cells it already stands on are legal to slide into (a
-- body moving one tile overlaps its old self). Returns ok, blocker, kind exactly as canShoveInto did
-- for a single tile -- kind "unit"/"wall"/"prop", nil blocker meaning the map itself barred it -- so
-- the shove loops read the same answer whatever the body's size. First offending cell wins the report.
local function footprintCanShift(combat, unit, dx, dy)
    for _, c in ipairs(Combat.cellsAt(unit.w or 1, unit.h or 1, unit.x + dx, unit.y + dy)) do
        local row = combat.arena and combat.arena.tiles and combat.arena.tiles[c.y]
        local cell = row and row[c.x]
        if not (cell and cell.walkable) then return false, nil end
        if Combat.objectBlocksAt(combat, c.x, c.y) then
            local obj, kind = Combat.objectAt(combat, c.x, c.y)
            return false, obj, kind
        end
        local occ = Combat.unitAt(combat, c.x, c.y)
        if occ and occ ~= unit then return false, occ, "unit" end
    end
    return true, nil
end

-- Slide `unit` one tile by (dx, dy), triggering whatever it lands on. Returns false on a blocked
-- tile without moving it. A wide body moves as one -- every cell it would enter must be clear
-- (footprintCanShift) or the whole slide is refused.
--
-- An ANCHORED body (Root) refuses every step here, which is the one place that has to be true: this is
-- the single primitive a unit's forced travel goes through -- knockback, Heave, pull, a charge shoving
-- a bystander aside -- so a status that says "you may not be moved" is enforced once rather than at
-- four call sites that could each forget. The louder entry points check it themselves as well, so they
-- can say so in the log and skip the work; this is the floor under them.
local function shoveStep(combat, unit, dx, dy)
    if Status.blocksForcedMove(unit) then return false end
    if not footprintCanShift(combat, unit, dx, dy) then return false end
    local fromX, fromY = unit.x, unit.y -- as Combat.stepMove: the vacated tile a trail lays behind on
    local nx, ny = unit.x + dx, unit.y + dy
    unit.x, unit.y = nx, ny
    Combat.enterTile(combat, unit, nx, ny, "forced", fromX, fromY)
    -- Being knocked off your feet shatters a channel you were winding up. Idempotent, so a
    -- multi-tile slide (knockback/pull/charge all route here) only fizzles the channel once.
    if unit.channel then Combat.interruptChannel(combat, unit, "knocked off balance") end
    return true
end

-- Where a shove would COME TO REST: the tile Combat.knockback below would leave `target` on, without
-- moving anything. Pure, so the hover preview can weigh what a blow leaves standing where -- an answer
-- is gated on reach, and a mace that shoves its target two tiles back is answered from the far tile
-- (see Combat.previewCounters). Walks the same lane by the same rule as the live shove; it does not
-- model a trap or hazard on the way killing the target, which only ever makes the preview's promised
-- counter more likely, never less.
function Combat.knockbackTile(combat, source, target, distance, opts)
    if not (source and target) then return target and target.x, target and target.y end
    -- An anchored body (Root) comes to rest exactly where it stands, because the live shove below
    -- never moves it. The preview has to agree or a counter would be promised from a tile the target
    -- is never going to be on.
    if Status.blocksForcedMove(target) then return target.x, target.y end
    -- Mirror Combat.knockback's aim: a thrown body (opts.dest set) walks the lane toward its chosen
    -- landing, so the ghost rests where the live throw will; a plain shove keeps away-from-source.
    -- (Explicit if/else so signDominant's two return values both survive.)
    local dx, dy
    if opts and opts.dest then dx, dy = signDominant(opts.dest.x - target.x, opts.dest.y - target.y)
    else dx, dy = signDominant(target.x - source.x, target.y - source.y) end
    local x, y = target.x, target.y
    if dx == 0 and dy == 0 then return x, y end
    local total = opts and opts.dest
        and math.max(math.abs(opts.dest.x - target.x), math.abs(opts.dest.y - target.y))
        or (distance or 1)
    local w, h = target.w or 1, target.h or 1
    for _ = 1, total do
        -- Test the whole body at the next anchor, ignoring the target's own cells (it slides through
        -- them). footprintFree is exactly canShoveInto's rule (walkable, no object, no other unit),
        -- lifted to the footprint -- so the preview lands where the live shove below comes to rest.
        if not Combat.footprintFree(combat, w, h, x + dx, y + dy, target) then break end
        x, y = x + dx, y + dy
    end
    return x, y
end

-- Close out a shove: raise the cue that glides `target` from (oX, oY) to wherever this pass left it,
-- and hand `moved` straight back so every exit from the loop below can return through here. `hold`
-- asks the view to keep the target on its ORIGIN tile for a moment before it travels -- the blow that
-- shoved it has already pushed its damage cue, and a body that leaves instantly drags the number off
-- the tile where the hit landed. So: the number reads, THEN the target is thrown. Nothing to slide
-- when the shove never got going (moved == 0) or when the trip killed it (the death fade plays where
-- it fell, and a corpse does not glide).
local function shoveDone(combat, target, oX, oY, moved)
    if moved > 0 and target.alive then
        Combat.pushFx(combat, { type = "slide", unit = target, fromX = oX, fromY = oY, hold = true })
    end
    return moved
end

-- How hard a stopped shove lands: the impact carries the momentum that had nowhere to go. A shove
-- halted with a single tile left in it deals the plain `amount`; every FURTHER tile it was denied
-- adds half as much again, so a body driven three tiles into a wall it never left hits at double.
-- Rounded down, and never below the base -- an already-spent shove still bruises.
local function impactDamage(amount, unspent)
    if unspent <= 1 then return amount end
    return math.floor(amount * (1 + 0.5 * (unspent - 1)))
end

-- Knock `target` up to `distance` tiles directly away from `source`. The direction is fixed at the
-- start (a straight line, however far it travels). A shove barred by the map edge, impassable
-- terrain, a conjured wall, or another unit stops there and hurts EVERYONE involved -- the target,
-- harder the more travel it was robbed of, and whatever it slammed into if that can be hurt at all
-- (a unit or a wall; bare terrain shrugs it off). Returns (tilesMoved, collided).
function Combat.knockback(combat, source, target, distance, opts)
    opts = opts or {}
    if not (target and target.alive) then return 0, false end

    -- ANCHORED (Root): the shove finds nothing to move. Not a collision -- a collision is momentum
    -- meeting a wall, and there was never any momentum here -- so no impact damage lands on anybody,
    -- and Combat.shoveRiders is skipped too: nothing was shoved, so nothing rides a shove. The blow
    -- that carried this is entirely unaffected; it has already been dealt by the time we get here.
    -- Said in the log, because "the mace hit and the body did not move" needs a reason on screen.
    if Status.blocksForcedMove(target) then
        Combat.logEvent(combat, "status",
            string.format("%s is rooted and holds its ground.", unitName(target)), target)
        return 0, false
    end

    local amount = opts.amount or Combat.COLLISION_DAMAGE
    -- A THROWN body (Heave) picks its own lane: aimed toward opts.dest rather than straight away
    -- from the source, and travelling only as far as that tile (Chebyshev), so the collision rule
    -- below still bites when the aim runs it into a wall short of where it was pointed. Everything
    -- else -- a plain shove -- keeps the fixed away-from-source direction and the `distance` arg.
    -- (An explicit if/else, not `cond and f() or g()`: that idiom would truncate signDominant's two
    -- return values to one and leave dy nil.)
    local dx, dy
    if opts.dest then dx, dy = signDominant(opts.dest.x - target.x, opts.dest.y - target.y)
    else dx, dy = signDominant(target.x - source.x, target.y - source.y) end
    if dx == 0 and dy == 0 then return 0, false end

    -- Where the shove starts, so the view can glide the target out of it rather than snapping it
    -- across the lane (the model resolves the whole slide in this one atomic pass).
    local oX, oY = target.x, target.y
    local total = opts.dest
        and math.max(math.abs(opts.dest.x - target.x), math.abs(opts.dest.y - target.y))
        or (distance or 1)
    local moved = 0
    for _ = 1, total do
        local ok, blocker, kind = footprintCanShift(combat, target, dx, dy)
        if not ok then
            local hit = impactDamage(amount, total - moved)
            Combat.logEvent(combat, "damage",
                string.format("%s slams into %s.", unitName(target),
                    (kind == "unit" and unitName(blocker))
                        or (blocker and (blocker.name or "an obstacle"))
                        or "an obstacle"),
                { target, kind == "unit" and blocker or nil })
            -- The collision reads as its own beat, landing a moment after the blow that shoved the
            -- target into the obstacle. A pinned shove (moved == 0) never slides the body, so without
            -- this the impact's damage number would pile onto the strike's on the very same tile and
            -- the two would blur into one unreadable figure. Beat 1, like a counter (see pushFx).
            Combat.beginBeat(combat)
            Combat.dealFlatDamage(combat, target, hit, { "physical", "impact" }, "the impact")
            -- Whatever stopped it takes the same blow back, each in its own currency.
            if kind == "unit" and blocker.alive then
                Combat.dealFlatDamage(combat, blocker, hit, { "physical", "impact" }, "the impact")
            elseif blocker and blocker.alive then
                -- A wall or a prop, each hurt in its own layer's currency. A powder keg has exactly
                -- enough HP to notice being slammed into, so shoving a foe onto one detonates it and
                -- the shover never had to write that anywhere.
                Combat.damageObject(combat, blocker, kind, hit)
            end
            Combat.endBeat(combat)
            Combat.shoveRiders(combat, source, target, true)
            return shoveDone(combat, target, oX, oY, moved), true
        end
        shoveStep(combat, target, dx, dy)
        moved = moved + 1
        Combat.logEvent(combat, "move",
            string.format("%s is knocked back to (%d, %d).", unitName(target), target.x, target.y), target)
        -- A trap or hazard on the tile it was driven onto may have finished it; stop the slide.
        if not target.alive then return shoveDone(combat, target, oX, oY, moved), false end
    end
    Combat.shoveRiders(combat, source, target, false)
    return shoveDone(combat, target, oX, oY, moved), false
end

-- ---------------------------------------------------------------------------
-- FUSES (S3): things planted now that go off later.
--
-- A charge is a plain record on `combat.charges` -- x, y, side, owner index, a countdown and a
-- magnitude -- and NOT a closure. That is the whole design constraint: this state has to survive
-- models/state_hash.lua, which projects the board to sorted-key Lua source so two machines watching one
-- fight can prove they agree. A scheduled function is unhashable and unserialisable, so a fuse carries
-- data and the engine owns the one behaviour.
--
-- One behaviour, deliberately. A general "run this later" queue would be a nicer toy and an
-- indeterminism farm; what the Saboteur actually needs is "a thing that explodes", either when its
-- count runs out or when its owner says so, and that is expressible in six numbers.
-- ---------------------------------------------------------------------------

-- Plant a charge on a tile. `fuse` is in turns of the owner; nil owner means it only ever answers to
-- the clock.
function Combat.plantCharge(combat, owner, x, y, opts)
    opts = opts or {}
    combat.charges = combat.charges or {}
    local charge = {
        x = x, y = y,
        side = owner and owner.side or "party",
        owner = owner and owner.index or nil,
        fuse = opts.fuse or 2,
        amount = opts.amount or 14,
        radius = opts.radius or 1,
    }
    combat.charges[#combat.charges + 1] = charge
    if owner and owner.side == "party" then
        Combat.logEvent(combat, "trap",
            string.format("%s sets a charge at (%d, %d).", unitName(owner), x, y), owner)
    end
    return charge
end

-- Set a charge off: everything within its radius takes the blast, friend or foe. A charge belongs to
-- nobody once it is in the ground -- the same rule a powder keg follows (Prop.place takes no side).
function Combat.detonate(combat, charge)
    if not (charge and not charge.spent) then return 0 end
    charge.spent = true
    local hit = 0
    for _, u in ipairs(Combat.unitsNear(combat, charge.x, charge.y, charge.radius or 1)) do
        if u.alive then
            Combat.dealFlatDamage(combat, u, charge.amount, { "physical", "impact" }, "the charge")
            hit = hit + 1
        end
    end
    Combat.logEvent(combat, "damage",
        string.format("A charge goes off at (%d, %d).", charge.x, charge.y))
    return hit
end

-- Every live charge `owner` planted, set off at once (the Saboteur's Detonator). Returns how many.
function Combat.detonateAll(combat, owner)
    local n = 0
    for _, c in ipairs(combat.charges or {}) do
        if not c.spent and c.owner == owner.index then
            Combat.detonate(combat, c)
            n = n + 1
        end
    end
    Combat.sweepCharges(combat)
    return n
end

-- Tick every charge owned by `unit` down one, firing any that reach zero. Called from startTurn, so a
-- fuse is measured in ITS OWNER's turns rather than in a global clock: two sappers' charges each count
-- at their own pace, and a charge whose owner is dead simply waits (its counter never advances), which
-- reads correctly -- nobody is left to set it off.
function Combat.tickCharges(combat, unit)
    if not (combat.charges and unit) then return end
    for _, c in ipairs(combat.charges) do
        if not c.spent and c.owner == unit.index then
            c.fuse = c.fuse - 1
            if c.fuse <= 0 then Combat.detonate(combat, c) end
        end
    end
    Combat.sweepCharges(combat)
end

-- Drop spent charges. Kept out of the loops above so a detonation cannot mutate the list it is walking.
function Combat.sweepCharges(combat)
    if not combat.charges then return end
    local keep = {}
    for _, c in ipairs(combat.charges) do
        if not c.spent then keep[#keep + 1] = c end
    end
    combat.charges = keep
end

-- FIELD CRAFTING (S4): make an item and put it in `unit`'s grid, marked `ephemeral` so it lasts the
-- fight and no longer. The model half of fx.grantItem.
--
-- Built on the path Combat.steal already proved: Character.addItem works perfectly well mid-battle, and
-- a full grid simply refuses. There is no new inventory layer here and deliberately so -- a brewed
-- poultice is an ITEM, and everything that already knows what an item is (the grid, the tooltip, the
-- damage preview, a pickpocket, the stack merge) picks it up for free.
--
-- `opts.quantity` stacks it, which matters because a merge into an existing stack of the same id is what
-- Character.addItem does anyway: a Herbalist who distils the same reagent twice gets a stack of two
-- rather than two cells spent.
function Combat.grantItem(combat, unit, itemId, opts)
    if not (unit and unit.char and itemId) then return nil end
    opts = opts or {}
    local item = Item.instantiate(itemId, opts.quantity or 1, opts.level or 0)
    item.ephemeral = true
    if not Character.addItem(unit.char, item) then
        Combat.logEvent(combat, "system",
            string.format("%s has nowhere to put %s.", unitName(unit), item.name or "it"), unit)
        return nil
    end
    Combat.logEvent(combat, "action",
        string.format("%s comes away with %s.", unitName(unit), item.name or "something"), unit)
    return item
end

-- Are `a` and `b` neighbours in `char`'s 3x3 grid (diagonals included)? A thin wrapper over the two
-- Character helpers the aura system already uses, so a rule about adjacency does not have to re-derive
-- slot indices at every call site.
function Combat.gridAdjacent(char, a, b)
    if not (char and a and b) then return false end
    local idx = Character.slotIndex(char, a)
    if not idx then return false end
    for _, other in ipairs(Character.adjacentItems(char, idx)) do
        if other == b then return true end
    end
    return false
end

-- How far `unit` has travelled since its turn opened, in tiles (Chebyshev -- a diagonal step is one).
-- Read off `turnStartX/Y`, the bookmark Combat.startTurn already lays down for the Backward Glance, so
-- nothing new has to be remembered. 0 for a unit whose turn is not open, and for one that has not moved.
--
-- What the Skirmisher's shelf is measured in: Running Shot scales with it and the Outrider's Harness
-- gates on it. Deliberately "how far from where you started" rather than "how many steps you took" --
-- a rider who circles back to the same tile has covered no ground, whatever the pathfinder says, and
-- the item that pays for movement should pay for having gone somewhere.
function Combat.tilesMovedThisTurn(unit)
    if not (unit and unit.turnStartX and unit.turnStartY) then return 0 end
    return math.max(math.abs(unit.x - unit.turnStartX), math.abs(unit.y - unit.turnStartY))
end

-- CONTAGION: every poisoned body on the field passes it to `carrier`'s foes standing beside it.
--
-- Gathered before any of it is applied, so a body infected by this pass cannot itself spread on the
-- same pass -- otherwise one poisoned unit in a packed line would sicken the whole line in a single
-- turn, and the mechanic would read as an area spell that happened to be free.
--
-- Poison already ticks and already stacks; what the Plague Knight adds is that it TRAVELS. That is why
-- the rot-fume payoff (damage scaling with how many are poisoned) had to ship alongside it: before
-- these two, spreading poison produced a status almost nothing in the catalog read.
function Combat.spreadContagion(combat, carrier)
    local caught = {}
    for _, src in ipairs(combat.units) do
        if src.alive and Status.has(src, "status_poison") then
            for _, near in ipairs(combat.units) do
                if near.alive and near ~= src and near.side ~= carrier.side
                    and math.max(math.abs(near.x - src.x), math.abs(near.y - src.y)) == 1
                    and not Status.has(near, "status_poison") then
                    caught[#caught + 1] = near
                end
            end
        end
    end
    for _, victim in ipairs(caught) do
        Status.apply(combat, victim, "status_poison", { applier = carrier })
    end
    if #caught > 0 then
        Combat.logEvent(combat, "status",
            string.format("The sickness spreads to %d more.", #caught), carrier)
    end
    return #caught
end

-- What the SUMMONER's standing charms add to a creature that has just arrived. The summon-layer twin of
-- Combat.shoveRiders, and it exists for the same reason: the caller already knows the thing the charm
-- needs to know (who called it, and that it is standing), so the charm answers a flag rather than
-- re-deriving an event.
--
-- Written against `summoned` in general rather than against spirits or totems, which is the precedent
-- the Beastlord's Bond set (docs/disciplines-plan.md): a Shaman's Ancestor Mask heals a Beastmaster's
-- wolf too, and nothing in its behaviour knows which shelf sold it. That is "anyone carries anything"
-- earning its keep.
function Combat.summonRiders(combat, summoner, summoned)
    if not (summoner and summoned and summoned.alive) then return end

    -- TOTEM-CARVER'S KIT: what you plant stands longer. Raises the ceiling AND fills it, so the
    -- creature actually arrives with the health rather than arriving wounded into a bigger body.
    local bolster = Trait.flag(summoner, "bolstersSummons")
    if bolster and summoned.char and summoned.char.stats and summoned.char.stats.health then
        local hp = summoned.char.stats.health
        local gain = (bolster.def and bolster.def.magnitude) or 10
        hp.max = hp.max + gain
        hp.current = hp.current + gain
    end
    -- GHOST-WIND: what the wind carries arrives already moving.
    if Trait.flag(summoner, "hastensSummons") then
        Status.apply(combat, summoned, "status_hasted", { applier = summoner })
    end
end

-- What the SHOVER's standing charms add to a shove that has just resolved. Read as declarative flags
-- off the source's traits (Trait.flag) rather than as hooks, because everything a hook would have to
-- work out -- who was thrown, whether it hit something -- the shove already knows.
--
-- This is the seam the Vanguard is built on, and the reason it is a seam at all: 19 items in the
-- catalog cause knockback and only a handful apply Sundered, so a charm that converts one into the
-- other is worth more than any single weapon could be. It reaches every shove in the game -- a mace's
-- innate displacement, Push, Shieldbreak, a hurled body -- without any of them knowing it exists.
--
-- Fired for the shover, never the shoved: `source` is who threw it. A shove that never got going
-- (dx == dy == 0) returns before this, so a rider cannot fire on a shove that did not happen.
function Combat.shoveRiders(combat, source, target, collided)
    if not (source and target and target.alive) then return end

    -- BREAKER'S WEDGE: every shove opens the armour it drove through.
    if Trait.flag(source, "sundersOnShove") then
        Status.apply(combat, target, "status_sundered", { applier = source })
    end
    -- BREAKER'S HARNESS: a shove that ended against something Stuns what it slammed. Only on a
    -- collision -- a body with room to travel is merely displaced, and the harness is about the wall.
    if collided and Trait.flag(source, "stunsOnCollision") then
        Status.apply(combat, target, "status_stun", { applier = source })
    end
end

-- Can a thrown OBJECT come to rest on (x, y)? Returns ok, blocker, kind exactly as canShoveInto does,
-- and by the same rules with one addition: a body standing there stops the throw too, and an object
-- may never share a tile with another object. This is deliberately the same predicate a shoved unit
-- answers to, so "what stops a barrel" and "what stops a man" are one rule -- and a nil blocker still
-- means the map itself (an edge, a wall of rock), which takes nothing back.
local function canHurlInto(combat, x, y)
    local row = combat.arena and combat.arena.tiles and combat.arena.tiles[y]
    local cell = row and row[x]
    if not (cell and cell.walkable) then return false, nil end
    local obj, kind = Combat.objectAt(combat, x, y)
    if obj then return false, obj, kind end
    local unit = Combat.unitAt(combat, x, y)
    if unit then return false, unit, "unit" end
    return true, nil
end

-- Throw a standing OBJECT (a prop, a visible trap) `distance` tiles straight away from `source` -- the
-- object-layer twin of Combat.knockback, and what Heave resolves to when the tile it grabs holds
-- furniture instead of a body (data/items/ability/ability_heave.lua).
--
-- It is the same journey a thrown body makes, told in the object layers' currency: a straight lane
-- fixed at the outset, stopped by the map edge, impassable terrain, another object or a unit, and a
-- stopped throw hurts BOTH ends -- the thing thrown and the thing it hit -- harder the more travel it
-- was robbed of (impactDamage, shared with the shove).
--
-- That last rule is the whole reason a barrel is worth carrying: a powder keg has exactly one HP
-- (data/props/prop_explosive_barrel.lua), so any collision at all destroys it, and its onDestroy is the
-- blast. "Throw the barrel at them" is not written anywhere -- it falls out of an object being damaged
-- by what it lands on. A throw that travels its full distance into open ground lands the keg intact,
-- which is how you reposition one safely.
--
-- Returns (tilesMoved, collided). No slide cue is raised: the fx queue's `slide` carries a unit, and an
-- object is not one -- a thrown prop snaps to its tile.
function Combat.hurlObject(combat, source, obj, kind, distance, opts)
    opts = opts or {}
    if not (source and obj and obj.alive) then return 0, false end
    local amount = opts.amount or Combat.COLLISION_DAMAGE
    -- Aimed toward opts.dest when Heave chose a landing (its lane and its reach both read off that
    -- tile); otherwise the fixed straight-away-from-source throw. The object-layer twin of the same
    -- override in Combat.knockback (explicit if/else so signDominant's two returns both survive).
    local dx, dy
    if opts.dest then dx, dy = signDominant(opts.dest.x - obj.x, opts.dest.y - obj.y)
    else dx, dy = signDominant(obj.x - source.x, obj.y - source.y) end
    if dx == 0 and dy == 0 then return 0, false end

    local name = obj.name or "an object"
    local total = opts.dest
        and math.max(math.abs(opts.dest.x - obj.x), math.abs(opts.dest.y - obj.y))
        or (distance or 1)
    local moved = 0
    for _ = 1, total do
        local ok, blocker, bkind = canHurlInto(combat, obj.x + dx, obj.y + dy)
        if not ok then
            local hit = impactDamage(amount, total - moved)
            Combat.logEvent(combat, "damage",
                string.format("%s slams into %s.", name,
                    (bkind == "unit" and unitName(blocker))
                        or (blocker and (blocker.name or "an obstacle"))
                        or "an obstacle"),
                { bkind == "unit" and blocker or nil })
            -- Its own beat, for the same reason a shove's collision takes one: the throw's number and
            -- the impact's must not pile onto one tile and blur together (see Combat.knockback).
            Combat.beginBeat(combat)
            if bkind == "unit" and blocker.alive then
                Combat.dealFlatDamage(combat, blocker, hit, { "physical", "impact" }, name)
            elseif blocker and blocker.alive then
                Combat.damageObject(combat, blocker, bkind, hit, source)
            end
            -- The thrown thing takes the blow LAST, so a keg that bursts does so with everything it
            -- slammed into already resolved -- and its blast, which reads the board, sees the tile it
            -- actually came to rest against.
            Combat.damageObject(combat, obj, kind, hit, source)
            Combat.endBeat(combat)
            return moved, true
        end
        if kind == "prop" then Prop.moveTo(obj, obj.x + dx, obj.y + dy)
        else obj.x, obj.y = obj.x + dx, obj.y + dy end
        moved = moved + 1
    end
    if moved > 0 then
        Combat.logEvent(combat, "move",
            string.format("%s is hurled to (%d, %d).", name, obj.x, obj.y))
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
    -- ANCHORED (Root): the hook catches, and the body does not come. Reported as a drag of zero tiles
    -- rather than as a refusal, deliberately -- a refusal (the "no line of sight" branch above) hands
    -- the turn back, and a rooted target is not an illegal aim, it is a bad one. Kept after the sight
    -- check so an aim that was never legal in the first place still costs nothing. shoveStep would
    -- stop the haul on its own; this is here for the log line.
    if Status.blocksForcedMove(target) then
        Combat.logEvent(combat, "status",
            string.format("%s is rooted and cannot be dragged.", unitName(target)), { target, source })
        return true, 0
    end
    -- Where the drag starts, so the view can glide the target across the lane rather than snapping it
    -- to your feet (the model resolves the whole haul in this one atomic pass, springing every trap and
    -- hazard it crosses as it goes -- see shoveStep -> enterTile).
    local oX, oY = target.x, target.y
    local moved = 0
    while Combat.unitGap(source, target) > 1 do
        local dx, dy = signDominant(source.x - target.x, source.y - target.y)
        if not shoveStep(combat, target, dx, dy) then break end
        moved = moved + 1
        Combat.logEvent(combat, "move",
            string.format("%s is pulled to (%d, %d).", unitName(target), target.x, target.y), { target, source })
        if not target.alive then break end
    end
    -- Glide the body from where it stood to where the haul left it. No `hold`, unlike a shove: a pull
    -- lands no blow on the origin tile, so there is no damage number to let read there first -- the drag
    -- just starts. Nothing to slide if it never budged (moved == 0) or a trap felled it on the way (the
    -- death fade plays where it dropped, and a corpse does not glide) -- exactly shoveDone's rule.
    if moved > 0 and target.alive then
        Combat.pushFx(combat, { type = "slide", unit = target, fromX = oX, fromY = oY })
    end
    return true, moved
end

-- Drag a standing OBJECT (a prop, a visible trap) toward `source` until it stands adjacent -- the
-- object-layer twin of Combat.pull, exactly as Combat.hurlObject is Combat.knockback's. Needs a clear
-- line of sight (you cannot hook what you cannot see), re-aims the direction EVERY step so a diagonal
-- target ends up beside the puller rather than marched past it on one axis, and stops short at the
-- first tile it cannot enter (an edge, terrain, another object or a body -- canHurlInto's rule).
--
-- A drag is not a slam: NOTHING takes impact here. That is the whole point of it over a throw -- a
-- barrel hauled up to your line arrives intact (Combat.hurlObject would burst it on the first thing it
-- hit), so pull is how you reposition a bomb without setting it off. Returns (true, tilesMoved) or
-- (false, reason).
function Combat.pullObject(combat, source, obj, kind)
    if not (obj and obj.alive) then return false, "dead" end
    if not Combat.hasLineOfSight(combat, source.x, source.y, obj.x, obj.y) then
        return false, "no line of sight"
    end
    local moved = 0
    while Combat.cellGap(obj.x, obj.y, source) > 1 do
        local dx, dy = signDominant(source.x - obj.x, source.y - obj.y)
        if not canHurlInto(combat, obj.x + dx, obj.y + dy) then break end
        if kind == "prop" then Prop.moveTo(obj, obj.x + dx, obj.y + dy)
        else obj.x, obj.y = obj.x + dx, obj.y + dy end
        moved = moved + 1
        Combat.logEvent(combat, "move",
            string.format("%s is dragged to (%d, %d).", obj.name or "an object", obj.x, obj.y))
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
        string.format("%s leaps to (%d, %d).", unitName(unit), x, y), unit)
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
    if Combat.unitGap(user, target) ~= 1 then return 0 end -- must be pinned in front
    -- Charge is a lockstep built on single-tile bodies: the charger steps into the exact cell its
    -- target vacates each stride. That geometry doesn't hold for a wide body, so a multi-tile charger
    -- OR target can't perform the drive -- the pin fizzles rather than resolving into a broken slide.
    -- (A wide BYSTANDER in the lane is still handled below: it is shoved aside as a whole body.)
    if (user.w or 1) > 1 or (user.h or 1) > 1 or (target.w or 1) > 1 or (target.h or 1) > 1 then
        return 0
    end
    -- An ANCHORED body (Root) cannot be driven, and a charge is nothing but driving one: the lockstep
    -- below moves the target first and follows it, so with the target planted there is no run to make.
    -- The pin fizzles exactly as it does against a wide body -- checked here rather than left to the
    -- loop because the target's stride sets its own x,y and never asks shoveStep. A charging body that
    -- is ITSELF rooted is stopped by the same status one gate earlier (it cannot take its move at all).
    local planted = (Status.blocksForcedMove(target) and target) or (Status.blocksForcedMove(user) and user)
    if planted then
        Combat.logEvent(combat, "status",
            string.format("%s is rooted, and the charge goes nowhere.", unitName(planted)), { planted, user })
        return 0
    end
    local dx, dy = signDominant(target.x - user.x, target.y - user.y)
    if dx == 0 and dy == 0 then return 0 end

    -- Where the pair start, so the view can slide both from here to their final tiles rather than
    -- snapping them across the lane (the model resolves the whole rush in this one atomic pass).
    local uOx, uOy = user.x, user.y
    local tOx, tOy = target.x, target.y
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
                string.format("%s is trampled by the charge.", unitName(blocker)), { blocker, user })
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
            string.format("%s charges, driving %s to (%d, %d).", unitName(user), unitName(target), fx_, fy_),
            { user, target })
        if not target.alive then break end
    end
    -- Slide cues: the target (and the charger behind it) glide from their start tiles to where this
    -- pass left them, so the drive reads as a rush across the lane instead of a teleport. Nothing to
    -- slide if the lane was barred at the outset (moved == 0).
    if moved > 0 then
        if target.alive then Combat.pushFx(combat, { type = "slide", unit = target, fromX = tOx, fromY = tOy }) end
        if user.alive then Combat.pushFx(combat, { type = "slide", unit = user, fromX = uOx, fromY = uOy }) end
    end
    return moved
end

-- Can a charge clear a body standing in its lane? The live rush shoves a bystander one tile to either
-- side and tramples it; this only ASKS, so the preview twin below can walk the same lane without
-- moving anybody. Furniture and walls answer false -- a barrel is not shoved aside by a shoulder, it
-- stops the run -- which is why the test is `blocker.alive` rather than "is there something there".
local function laneClears(combat, blocker, dx, dy)
    if not (blocker and blocker.alive) then return false end
    if Status.blocksForcedMove(blocker) then return false end -- an anchored bystander is a wall
    local px, py = -dy, dx
    return footprintCanShift(combat, blocker, px, py) or footprintCanShift(combat, blocker, -px, -py)
end

-- A charge into OPEN GROUND: the same rush with nobody pinned in front of it. `user` runs up to
-- `distance` tiles along (dx, dy) under its own weight, halted by the map edge, impassable terrain, a
-- wall or a body it cannot clear, and shoving aside (and trampling) any bystander caught in the lane
-- exactly as the pinned drive does. Returns the number of tiles advanced.
--
-- Written as its own loop rather than folded into Combat.charge because the two runs are shaped
-- differently: the pinned drive walks the TARGET and follows it, and there is no target here to walk.
-- Uses footprintCanShift rather than canShoveInto, so a wide charger runs the lane as one body (the
-- lockstep form has to refuse a wide charger; this one does not).
local function chargeLane(combat, user, dx, dy, distance)
    local oX, oY = user.x, user.y
    local moved = 0
    for _ = 1, (distance or 1) do
        if not user.alive then break end -- a hazard or trap in the lane may end the run mid-stride
        local ok, blocker = footprintCanShift(combat, user, dx, dy)
        if not ok then
            if not laneClears(combat, blocker, dx, dy) then break end
            local px, py = -dy, dx
            local _ = shoveStep(combat, blocker, px, py) or shoveStep(combat, blocker, -px, -py)
            Combat.logEvent(combat, "damage",
                string.format("%s is trampled by the charge.", unitName(blocker)), { blocker, user })
            Combat.dealFlatDamage(combat, blocker, Combat.COLLISION_DAMAGE, { "physical", "impact" }, "the charge")
            ok = footprintCanShift(combat, user, dx, dy) -- the lane may now be clear (pushed aside, or slain)
            if not ok then break end
        end
        local fromX, fromY = user.x, user.y
        user.x, user.y = user.x + dx, user.y + dy
        -- "forced", as the charger's half of the lockstep drive is: the rush carries it rather than
        -- being a metered walk, but it is on the ground the whole way and pays the ground's bleed.
        Combat.enterTile(combat, user, user.x, user.y, "forced", fromX, fromY)
        moved = moved + 1
        Combat.logEvent(combat, "move",
            string.format("%s charges to (%d, %d).", unitName(user), user.x, user.y), user)
    end
    -- One slide cue for the whole run, so it reads as a rush rather than a teleport (the pinned form
    -- pushes two, one per body). Nothing to slide if the lane was barred at the outset.
    if moved > 0 and user.alive then
        Combat.pushFx(combat, { type = "slide", unit = user, fromX = oX, fromY = oY })
    end
    return moved
end

-- Charge at a TILE rather than at a body -- the form the Charge ability aims with. Whatever stands on
-- the aimed (adjacent) tile is what gets pinned and driven; when NOTHING stands there, the charger runs
-- that empty lane itself. The second half is what makes Charge a way to MOVE as well as a way to
-- displace: aim a foe to bury it in a corner, aim open ground to cross three tiles of it on an action
-- rather than on your move. Returns the number of tiles advanced.
function Combat.chargeInto(combat, user, tx, ty, distance)
    if not (user and user.alive and tx and ty) then return 0 end
    local dx, dy = signDominant(tx - user.x, ty - user.y)
    if dx == 0 and dy == 0 then return 0 end
    local pinned = Combat.unitAt(combat, tx, ty)
    if pinned and pinned ~= user then return Combat.charge(combat, user, pinned, distance) end
    -- An anchored charger (Root) has no rush in it. Combat.charge makes this check in both directions;
    -- here only the charger can be planted, because there is nobody in front of it to drive.
    if Status.blocksForcedMove(user) then
        Combat.logEvent(combat, "status",
            string.format("%s is rooted, and the charge goes nowhere.", unitName(user)), user)
        return 0
    end
    return chargeLane(combat, user, dx, dy, distance)
end

-- Where a charge aimed at (tx, ty) would leave the CHARGER, without moving anything -- Combat.chargeInto's
-- pure twin, the way Combat.knockbackTile is Combat.knockback's. A charge is bought for where it puts
-- you, so the hover has to be able to ring that tile (Combat.previewAbility's userRestsX/userRestsY) and
-- the counter preview has to weigh the cast from it rather than from the square it is thrown off.
--
-- Walks the same lane by the same rule as the live rush, counting a bystander the rush could shove clear
-- as ground it takes. It does not model the trample KILLING a bystander it could not shove (which would
-- vacate the tile), nor a hazard on the way felling the charger -- the first only ever lengthens the real
-- run, the second only shortens it, and both are rarer than the tooltip is looked at.
function Combat.chargeTile(combat, user, tx, ty, distance)
    if not (user and user.alive and tx and ty) then return user and user.x, user and user.y end
    local dx, dy = signDominant(tx - user.x, ty - user.y)
    if (dx == 0 and dy == 0) or Status.blocksForcedMove(user) then return user.x, user.y end
    -- The pinned form moves the pair in LOCKSTEP, so the charger's run is really the target's run: walk
    -- the lane from the pinned body's tile, and the charger comes to rest one stride behind wherever
    -- that stops. Every gate Combat.charge refuses the pin on leaves the charger where it stands.
    local pinned = Combat.unitAt(combat, tx, ty)
    if pinned == user then pinned = nil end
    if pinned then
        if (user.w or 1) > 1 or (user.h or 1) > 1 or (pinned.w or 1) > 1 or (pinned.h or 1) > 1
            or Status.blocksForcedMove(pinned) or Combat.unitGap(user, pinned) ~= 1 then
            return user.x, user.y
        end
    end
    local body = pinned or user
    local w, h = body.w or 1, body.h or 1
    local x, y = body.x, body.y
    local moved = 0
    for _ = 1, (distance or 1) do
        if not Combat.footprintFree(combat, w, h, x + dx, y + dy, body)
            and not laneClears(combat, Combat.unitAt(combat, x + dx, y + dy), dx, dy) then
            break
        end
        x, y = x + dx, y + dy
        moved = moved + 1
    end
    return user.x + moved * dx, user.y + moved * dy
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

-- ONE WEAPON FAMILY CONTAINS ANOTHER, and only an adjacency predicate asks the question this way.
--
-- A weapon carries exactly one archetype tag -- a second is an authoring slip tests/weapon_spec.lua
-- fails the build over (Item.archetype) -- so a longbow is tagged `longbow` and never also `bow`.
-- Eleven abilities are authored against `tag = "bow"`: Rain of Arrows, Called Shot, Pinning Shot,
-- Hobbling Shot, Warding Line, Break Off, and the stake/snare half of the Trapper's kit. Every one of
-- them went dead beside a longbow, so a hunter climbing their own shelf's ladder disarmed their own
-- abilities at the top of it -- the Hailfall Longbow bought the setup half of the class out of its
-- payoff.
--
-- Stated as containment rather than fixed by tagging the bows twice, because the second tag would be
-- the slip. `bow` is the umbrella the abilities were written against and `longbow` the deeper cut of
-- it; nothing else in the catalog needs a row here. The other five archetype predicates (dagger,
-- staff, spear, censer, shield) have no sub-family at all, and the broad predicates the rest of the
-- kit uses -- melee, ranged, arcane, and the elements -- are ordinary tags authored straight onto the
-- item beside its family, which is how a bow already answers `ranged`.
Combat.FAMILY_CONTAINS = { bow = { longbow = true } }

-- Does `item` carry `tag`, or a tag of a family that `tag` contains?
local function hasFamilyTag(item, tag)
    if hasTag(item.tags, tag) then return true end
    for sub in pairs(Combat.FAMILY_CONTAINS[tag] or {}) do
        if hasTag(item.tags, sub) then return true end
    end
    return false
end

-- Does `item` match an adjacency predicate `{ type=?, tag=? }`? Each field is optional (an absent
-- field is a wildcard); a predicate with neither field matches any item.
function Combat.matchesAdjacency(item, pred)
    if not (item and pred) then return false end
    if pred.type and item.type ~= pred.type then return false end
    if pred.tag and not hasFamilyTag(item, pred.tag) then return false end
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

-- A COATING: an aura-bearing item that is spent by being used rather than worn forever. A charm
-- (`type == "utility"`) radiates into its neighbours for the whole battle and asks nothing; a coating
-- (`type == "consumable"`) carries a stack, and every cast it sharpens takes one off it. Same `aura`
-- block, same fold, one difference -- it runs out.
--
-- That difference is the whole reason the two exist side by side. A worn charm is a permanent grid
-- decision: nine cells, and one is the Prism forever. A coating is a decision you make for THIS fight
-- and re-buy for the next, which is what lets it be stronger per use than a charm could safely be.
-- The Crucible sells rot by the vial for the same reason a smith sells arrows and not a quiver that
-- never empties.
--
-- Depletion is checked here, so an empty vial simply stops applying -- it is not an error and it does
-- not need to leave the grid. Compare Combat.isDepleted, which answers the same question for an item
-- being CAST; this one answers it for an item being read by its neighbour.
function Combat.auraSpent(item)
    return item ~= nil and item.type == "consumable" and (item.quantity or 1) <= 0
end

-- Aggregate the adjacency auras affecting a cast of `item` from `char`'s grid: the extra tags to
-- fold into the attack, the statuses to inflict on a damaged target, and the numeric modifiers a
-- neighboring charm grants the cast. Returns (tags, statuses, mods), where mods is
--
--   amount     -- added to the ability's magnitude   (Alchemic Mastery, Resonance Prism)
--   range      -- added to the ability's reach       (Long-Fuse Reagent, Farsight Lens)
--   speed      -- added to the initiative the action bills; NEGATIVE is faster (Quickened Sigil)
--   lifesteal  -- share of damage healed back        (Vampiric Strike)
--   preserve   -- the neighbour consumable's own stack is not spent (Everflask)
--   careful    -- the cast's area spares the caster's own side (Careful Sigil)
--   twin       -- a single-target cast strikes one more body beside its target (Twinned Sigil)
--
-- Every numeric field is additive across applicable neighbours and every flag is a logical OR, so two
-- charms beside one spell simply both apply. PURE: it reads the grid and touches nothing, because the
-- damage preview calls it on every hover -- spending a coating here would drain the satchel by looking
-- at it. Combat.spendAuras is the half that bills, and it runs once, on a resolved cast.
local function adjacencyAura(char, item)
    local tags, statuses = {}, {}
    local mods = { amount = 0, range = 0, speed = 0, preserve = false, lifesteal = 0,
                   careful = false, twin = false }
    local idx = char and Character.slotIndex(char, item)
    if idx then
        for _, nb in ipairs(Character.adjacentItems(char, idx)) do
            if nb.aura and Combat.auraApplies(nb.aura, item) and not Combat.auraSpent(nb) then
                for _, t in ipairs(nb.aura.grantTags or {}) do tags[#tags + 1] = t end
                if nb.aura.status then statuses[#statuses + 1] = nb.aura.status end
                mods.amount = mods.amount + (nb.aura.amountBonus or 0)
                mods.range = mods.range + (nb.aura.rangeBonus or 0)
                mods.speed = mods.speed + (nb.aura.speedBonus or 0)
                mods.lifesteal = mods.lifesteal + (nb.aura.lifesteal or 0) -- Vampiric Strike: heal a share of damage
                if nb.aura.preserve then mods.preserve = true end
                if nb.aura.careful then mods.careful = true end
                if nb.aura.twin then mods.twin = true end
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

-- adjacencyAura reads the GRID, which is all it can see -- it is handed a character and an item, never
-- a unit, precisely so it stays usable from the shop and the loadout where no battle exists. A thirst
-- granted by a STATUS is a property of the body rather than of the kit, so it is folded in here, at
-- each call site that actually has a unit to ask about.
--
-- One line, called from all three cast paths (the hover preview, Combat.strikeWith, and resolveCast),
-- for the reason every other shared fold in this file is shared: a thirst the preview did not know
-- about would quote the player a number the swing then beats.
local function withStatusLifesteal(unit, mods)
    mods.lifesteal = mods.lifesteal + Status.lifesteal(unit)
    return mods
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

-- The initiative a neighboring charm's aura shaves off (or adds to) a cast of `item`, or 0. Negative
-- is FASTER, which is the direction a Quickened Sigil pushes. Public for the same reason the range
-- bonus above is: the timeline ghost, the hover preview and the live endTurn all have to quote one
-- number, or the slot the player was shown is not the slot they land on.
function Combat.adjacencySpeedBonus(char, item)
    if not (char and item) then return 0 end
    local _, _, mods = adjacencyAura(char, item)
    return mods.speed
end

-- Spend one charge off every COATING that just sharpened a cast of `item` (see Combat.auraSpent). The
-- billing half of adjacencyAura, split out precisely so that function can stay pure: the preview reads
-- the grid on every mouse-move, and a satchel that emptied itself under the cursor would be a bug that
-- reads as one.
--
-- Called from Combat.resolveCast alone -- the moment a deliberate action finishes. A reflex is
-- deliberately NOT billed: a parry, a riposte, a thorn is an answer thrown out of turn, and the fiction
-- of a coating is a thing you APPLY between swings, not something the reflex has time to re-do. That
-- also keeps the vial's cost readable, since the player spends it only on casts they chose to make.
--
-- Returns the coatings actually spent, so the caller can say so in the log -- a stack that vanished
-- silently is a stack the player will swear was stolen.
function Combat.spendAuras(char, item)
    local spent = {}
    local idx = char and Character.slotIndex(char, item)
    if not idx then return spent end
    for _, nb in ipairs(Character.adjacentItems(char, idx)) do
        if nb.aura and Combat.auraApplies(nb.aura, item) and not Combat.auraSpent(nb) then
            nb.quantity = math.max(0, (nb.quantity or 1) - 1)
            spent[#spent + 1] = nb
        end
    end
    return spent
end

-- The units a cast of `ab` at (tx, ty) actually catches. Combat.aoeUnits answers "who is standing in
-- the footprint"; this answers "who does this cast hit", which is the same question unless a CAREFUL
-- aura sits beside it -- in which case the caster's own side is stepped over and the blast lands on
-- the enemy alone.
--
-- Careful is folded in here rather than at each effect because every area ability in the game reaches
-- its victims through this one call (fx.aoeUnits, on both the live path and the dry-run preview), so
-- one funnel makes the sigil work for a Fireball, a Blizzard and every future blast without any of
-- them learning the word. The caster is spared too: it is on its own side.
--
-- What it deliberately does NOT touch is the FOOTPRINT (Combat.aoeCells). A careful Fireball still
-- lays fire on every tile it covers, including the ones your line is standing on -- the sigil steers
-- the blast, not the ground it leaves behind. Ground is nobody's friend.
function Combat.castUnits(combat, ab, tx, ty, unit, mods)
    local all = Combat.aoeUnits(combat, ab, tx, ty, unit)
    if not (mods and mods.careful and unit) then return all end
    local out = {}
    for _, u in ipairs(all) do
        if u.side ~= unit.side then out[#out + 1] = u end
    end
    return out
end

-- The extra body a TWINNED cast strikes: the nearest enemy standing beside `target` that the cast did
-- not already catch, or nil. The twin is found on the board rather than aimed, because the sigil
-- copies a working rather than re-casting it -- you do not get to choose where the second one lands.
--
-- Single-target only, and that restraint is the point: a twinned Fireball would be two Fireballs, but
-- a twinned Jolt is a bolt that forks. Combat.isSingleTarget is the same gate the counter rules read,
-- so "is this a blow aimed at one body" has one answer in the codebase.
function Combat.twinTarget(combat, unit, ab, target)
    if not (unit and target and Combat.isSingleTarget(ab)) then return nil end
    for _, d in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
        local u = Combat.unitAt(combat, target.x + d[1], target.y + d[2])
        if u and u.alive and u ~= target and u.side ~= unit.side then return u end
    end
    return nil
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

-- Why `item` cannot reach what it needs from where `char` keeps it, or nil when it can. The Loadout
-- screen's second warning and the twin of Combat.unpayableCosts: that one asks whether this body can
-- pay for a thing, this one whether the GRID is arranged so the thing works at all.
--
-- TWO FAILURES WEAR ONE RETURN, because they want two different sentences:
--
--   placed = true    the item is in the grid and nothing beside it answers. A placement mistake, and
--                    the fix is to pick it up -- the cells that would satisfy it light green the
--                    moment you do (Combat.adjacencyCandidateCells).
--   placed = false   the item is NOT in this grid -- a stash piece being weighed up -- and no cell of
--                    it would satisfy the requirement either. Not a mistake yet: the body simply
--                    carries no bow for a Rain of Arrows to draw on, which is the thing worth knowing
--                    BEFORE handing it over rather than after.
--
-- A stash item some cell WOULD satisfy is no gap at all and reports nil. It is placeable, the grid
-- already paints where, and calling that an error would flag every good item in the stash.
function Combat.adjacencyGap(char, item)
    local ab = item and item.activeAbility
    local req = ab and ab.requiresAdjacent
    if not (char and req) then return nil end
    local label = Combat.adjacencyLabel(req)
    if Character.slotIndex(char, item) then
        if Combat.adjacencyMet(char, item) then return nil end
        return { label = label, placed = true,
            text = "Needs an " .. label .. " -- nothing beside it is one" }
    end
    if next(Combat.adjacencyCandidateCells(char, item)) ~= nil then return nil end
    return { label = label, placed = false,
        text = "Needs an " .. label .. " -- " .. (char.name or "this body") .. " carries none" }
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
-- The share of a blow that gets through however heavy the armour -- the floor under every hit.
--
-- A hit has always floored above zero, and the reason is unchanged (docs/vulnerability.md): a scratch
-- is still a hit, so it still triggers counters, feeds Rimebitten, wakes a sleeper and advances a boss
-- phase. What changed is that the floor now SCALES WITH THE BLOW instead of being a flat 1. A
-- greatsword that loses the arithmetic against heavy plate should still land harder than a dagger
-- that loses it by the same margin, and a flat floor said they were identical.
--
-- The old behaviour is this rule at a share of 0, so nothing about the ">0 always" contract moves.
-- Status.immuneToDamage still short-circuits to a true 0 first, which is what keeps Immune and
-- Resistant different things.
--
-- Deliberately a NET, not a mechanism the game leans on. If real fights are routinely landing here the
-- arithmetic is wrong somewhere upstream, and tests/balance_spec.lua asserts nothing reference-grade
-- needs it -- no body in the campaign floors against a melee company. It exists for the long tail: an
-- odd build, a heavily warded boss, a weapon swung at the one thing in the game that hard-counters it.
Combat.MIN_DAMAGE_SHARE = 0.15

-- The least `base` may be reduced to. One owner, so mitigatedDamage, the trap preview and the
-- breakdown receipt cannot disagree about where the floor is.
local function damageFloor(base)
    return math.max(1, math.floor((base or 0) * Combat.MIN_DAMAGE_SHARE))
end

-- Apply `base` pre-mitigation damage to `target`: subtract the matching defense stat (magical
-- tags route to magicDefense) and any tag `resist`, floor at a share of the blow
-- (Combat.MIN_DAMAGE_SHARE), and drop the target to dead at 0 HP. Returns the amount dealt. The
-- shared core for stat-scaled item damage (Combat.dealDamage) AND flat sources with no attacker
-- (traps, status effects).
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
    -- A per-type immunity (Immune: Fire and kin) voids a hit carrying that tag outright -- before armor,
    -- resist, vulnerability, and even the raw path below. Sits beside the barrier read above and, like
    -- it, never mutates, so a hovered target reads the negation without spending anything.
    if Status.immuneToDamage(target, tags) then return 0 end
    -- Raw (armor-piercing) damage skips defense and tag resists entirely -- a Penetrating Strike
    -- that lands its full Power on the flesh. Barriers and vulnerabilities still apply (a ward is
    -- not armor). Floors at 1 like any hit.
    if opts and opts.raw then
        local vuln = Status.vulnerability(target, tags)
        return math.max(damageFloor(base), math.floor(base + vuln + 0.5))
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
    return math.max(damageFloor(base), math.floor(base - defense - resist + vuln + 0.5))
end

-- A structured, render-agnostic breakdown of the very arithmetic Combat.mitigatedDamage just
-- performed, attached to the "takes N damage" log line so the combat-log panel can spell it out on
-- hover: an ordered list of { label, value, strong } rows reading the pre-mitigation power down
-- through each subtraction to the final number, plus an optional `note`. `baseParts` (handed in from
-- Combat.dealDamage) names where the raw power came from -- the attacker's attack stat, the weapon,
-- an unarmed bonus; a flat source (a trap, a burn tick) passes none and shows a single "Base" row.
-- The attack stat and the target's defense are each itemized down to what moves them -- base, then
-- equipment, then every buff/debuff by name, each its own signed row -- so a modified stat reads as
-- the sum of its parts rather than one opaque number.
-- Mirrors mitigatedDamage exactly (same magical/raw switch, same defense stat, same per-tag resist
-- and vulnerability), so what the tooltip lists always sums to the number in the line above it.
function Combat.damageBreakdown(target, base, tags, opts, baseParts, dmg)
    tags = tags or {}
    local rows = {}
    -- `signed` rows render with an explicit +/- (the mitigation half of the receipt); base-power rows
    -- read as plain positive addends, and the `strong` total stands alone.
    local function add(label, value, strong, signed)
        rows[#rows + 1] = { label = label, value = value, strong = strong, signed = signed }
    end
    if baseParts and #baseParts > 0 then
        for _, p in ipairs(baseParts) do
            -- A base-power addend (the attacker's attack stat, the weapon) reads plain; a modifier of
            -- it (equipment, a buff/debuff) carries `signed` so it shows an explicit +/-.
            if p.value and p.value ~= 0 then add(p.label, p.value, false, p.signed) end
        end
    else
        add("Base", base)
    end
    -- A per-type immunity voids the blow entirely: show where the power came from, then say it landed
    -- for nothing, and stop -- so the receipt reads 0 for the same reason mitigatedDamage returned 0,
    -- rather than tallying an armor sum the immunity made irrelevant.
    if Status.immuneToDamage(target, tags) then
        add("Immune to this type", nil)
        add("Damage", 0, true)
        return rows
    end
    local magical = hasTag(tags, "magical")
    local vuln = Status.vulnerability(target, tags)
    local mitigated -- the pre-floor result, to spot a hit that floored up to the minimum of 1
    if opts and opts.raw then
        -- Armor-piercing: defense and tag resists are skipped entirely (a ward is not armor).
        add("Armor-piercing (ignores defense)", nil)
        -- One number, two names: a positive is a weakness (Wet under lightning), a negative is a
        -- resistance (Wet under fire). Same signed row either way -- the label just stops lying.
        if vuln ~= 0 then add(vuln > 0 and "Vulnerability" or "Resistance", vuln, false, true) end
        mitigated = base + vuln
    else
        local defStat = magical and "magicDefense" or "defense"
        -- Split the target's defense the same way as the attack stat above: its base, then equipment,
        -- then each buff/debuff by name, every one a separate signed subtraction. A +defense buff cuts
        -- the damage (a larger minus); a -defense debuff feeds it (the minus flips to a plus). The parts
        -- sum to flatStat(target, defStat) -- the exact value mitigatedDamage subtracted.
        local defBase = (target.char and target.char.stats[defStat]) or 0
        local defItemTotal = (target.bonus and target.bonus[defStat]) or 0
        if defBase ~= 0 then add(magical and "Magic defense" or "Defense", -defBase, false, true) end
        -- One row per piece of gear that moves defense, named after the item; any unattributed
        -- remainder (a summon's folded bonus, a test fixture) closes under a generic "Equipment".
        local defAttributed = 0
        for _, p in ipairs(equipmentStatParts(target, defStat)) do
            add(p.label, -p.value, false, true)
            defAttributed = defAttributed + p.value
        end
        if defItemTotal - defAttributed ~= 0 then add("Equipment", -(defItemTotal - defAttributed), false, true) end
        for _, p in ipairs(Status.statBonusParts(target, defStat)) do
            add(p.label, -p.value, false, true)
        end
        local defense = defBase + defItemTotal + Status.statBonus(target, defStat)
        local resist = 0
        for _, t in ipairs(tags) do
            local r = (target.resist and target.resist[t]) or 0
            if r ~= 0 then
                add(t:sub(1, 1):upper() .. t:sub(2) .. " resist", -r, false, true)
                resist = resist + r
            end
        end
        -- One number, two names: a positive is a weakness (Wet under lightning), a negative is a
        -- resistance (Wet under fire). Same signed row either way -- the label just stops lying.
        if vuln ~= 0 then add(vuln > 0 and "Vulnerability" or "Resistance", vuln, false, true) end
        mitigated = base - defense - resist + vuln
    end
    add("Damage", dmg, true)
    -- Say so when mitigation would have driven the blow below the floor -- otherwise the rows sum to
    -- less than the number they add up to, and the tooltip looks like it can't do arithmetic.
    local floor = damageFloor(base)
    if math.floor(mitigated + 0.5) < floor then
        rows.note = string.format("Floored to the minimum of %d (%d%% of the blow).",
            floor, math.floor(Combat.MIN_DAMAGE_SHARE * 100 + 0.5))
    end
    return rows
end

-- A decoy that is gone stops being a lie. Its deployment wrote a fake "moves to (x, y)" line into
-- the log (data/items/utility/utility_decoy.lua) and kept a handle on it; rewrite that entry IN PLACE, so
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
    Combat.logEvent(combat, "death", string.format("%s's decoy is destroyed.", unitName(caster)), caster)
    correctDecoyRecord(decoy)
    if caster.alive and Status.has(caster, "status_invisible") then
        Status.remove(combat, caster, "status_invisible")
        Combat.logEvent(combat, "status", string.format("%s is revealed!", unitName(caster)), caster)
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
    Combat.logEvent(combat, "death", text or string.format("%s vanishes.", unitName(unit)), unit)
    -- A decoy dismissed alongside the caster it was covering for: nobody is left to reveal, but the
    -- fake move it wrote is still sitting in the log. Set it straight.
    correctDecoyRecord(unit)
    for _, u in ipairs(combat.units) do
        if u.alive and u.summoner == unit then Combat.dismiss(combat, u) end
    end
    -- As in killUnit: a dismissed banner's ground goes with it, however it left the field.
    Hazard.dropOwnedBy(combat, unit)
    Combat.releaseHeldBy(combat, unit)
    leaveTurn(combat, unit) -- and its turn, if it was standing in one (see leaveTurn)
end

-- ---------------------------------------------------------------------------
-- The bench: rotating the company through the field
-- ---------------------------------------------------------------------------
--
-- The player marches a company of eight and stands four of them (Combat.MAX_FIELD) on the board in the
-- deployment phase. The other four wait on `combat.bench` and can be brought on mid-fight. See
-- docs/deployment.md for the rules; what follows is why the model is shaped the way it is.
--
-- A BENCHED MEMBER IS NOT IN `combat.units`. It is an entry -- { char, relicTraits, meal, statuses } -- and
-- nothing more. Every query in this file walks combat.units and asks `u.alive`; a benched body wearing a
-- flag would have to be excluded from roughly two hundred of them (targeting, AoE dedupe, the AI, hazard
-- ticks) and any one missed reads as a ghost you can hit from across the board. Worse, Combat.inTimeline
-- warns what happens to a unit that rides the timeline and never acts: it pegs the rebase minimum at 0
-- and freezes every duration in the battle. Off the list, both problems are structural non-problems.
--
-- Two ways onto the field, priced differently because they are different decisions:
--
--   ROTATE   -- a living unit standing in the deploy zone spends its TURN to trade places with someone
--               on the bench. It costs tempo because you chose it.
--   REINFORCE -- a slot has opened (somebody fell), so you may fill it for FREE. You already paid, with
--               a body. This is also what makes the bench a genuine second life: the fight is not lost
--               while there is anyone left to send in.
--
-- THE PLAYER NEVER READS THE WORD "ROTATE". The move is called FALL BACK on every surface and the ground
-- it is made from is RALLY GROUND (Combat.rallyGround / rallyTileInfo, ui/battle_map.lua drawRallyGround);
-- the model keeps the older spelling because `rotate` is what the whole bench section, its tests and
-- docs/deployment.md are written in, and renaming the mechanic is not the same job as naming it.
--
-- Statuses ride out and back with the body, so falling back is not a cleanse -- it parks a poison rather
-- than curing it. They do not tick while off the board, for the plain reason that nothing off the board
-- ticks at all.

-- How many of the company may stand on the board at once. Mirrors Player.MAX_FIELD, declared here rather
-- than required so this module stays player-free (the same rule DraftRun.PARTY_MAX follows).
Combat.MAX_FIELD = 4

-- What a rotation costs on top of the ground the rotating unit covered this turn. Priced at a plain
-- attack's tempo (DEFAULT_SPEED): stepping out of the line is a real action, not a free reshuffle, and
-- the unit coming on inherits the bill -- it stands where the one leaving would next have acted.
Combat.ROTATE_COST = Combat.DEFAULT_SPEED

-- Is (x, y) inside the ground the player may stand bodies on? False for a battle built with no zone at
-- all (a duel, a bare test), which is what makes those fights refuse to rotate rather than treating the
-- whole board as your own lines.
function Combat.inDeployZone(combat, x, y)
    for _, t in ipairs((combat and combat.deployZone) or {}) do
        if t.x == x and t.y == y then return true end
    end
    return false
end

-- The ground marked as RALLY GROUND right now: the deploy zone, but only while somebody is still on the
-- bench to send in. Once the last reserve has taken the field those tiles are ordinary ground again and
-- the board stops marking them -- a mark that means nothing is a mark the player learns to ignore.
-- One rule, two surfaces: the board overlay and the hover tooltip both read this.
function Combat.rallyGround(combat)
    if Combat.benchCount(combat, "party") == 0 then return {} end
    return (combat and combat.deployZone) or {}
end

-- What the hover tooltip says about the rally tile (x, y), or nil when it is not your ground (or the
-- bench is spent). The read side of Combat.inDeployZone, shaped like Combat.objectiveTileInfo so
-- states/battle.lua feeds the two the same way and this can be tested headless:
--
--   { reserves,     -- how many of the company are waiting off the board
--     occupant,     -- your own unit standing on the tile right now, if any
--     canFallBack,  -- whether that occupant could trade places this instant (Combat.canRotate)
--     slotOpen }    -- free ground, with a slot standing open: a reserve can be sent in HERE, free
function Combat.rallyTileInfo(combat, x, y)
    if #Combat.rallyGround(combat) == 0 then return nil end
    if not Combat.inDeployZone(combat, x, y) then return nil end
    local info = { reserves = Combat.benchCount(combat, "party") }
    local unit = Combat.unitAt(combat, x, y)
    if unit and unit.side == "party" and Combat.isPlayerControlled(unit) then
        info.occupant = unit
        info.canFallBack = (Combat.canRotate(combat, unit)) and true or false
    end
    -- Empty ground while a slot is open: this exact tile is one a reserve may walk in on, which is what
    -- makes it clickable on the board (states/battle.lua's battle.reinforceHere). Answered here, beside
    -- the fall-back read, so the mark, the tooltip and the click can never disagree about which tiles
    -- are live -- the same one-rule-two-surfaces the rest of this bag is built on.
    if not unit and Combat.footprintFree(combat, 1, 1, x, y) and Combat.canReinforce(combat, "party") then
        info.slotOpen = true
    end
    return info
end

-- How many bodies `side` has ON THE FIELD, against the MAX_FIELD cap. Summons don't count -- the cap is
-- about the company you deploy, and a conjured wolf is not a member of it. Neither does a fallen body:
-- its slot is open the moment it drops, which is what a reinforcement fills.
function Combat.fieldCount(combat, side)
    local n = 0
    for _, u in ipairs(combat.units) do
        if u.alive and u.side == (side or "party") and not u.summoned then n = n + 1 end
    end
    return n
end

-- How many are waiting off the board for `side`. Only the party has a bench; the enemy's version of
-- "more are coming" is a reinforcement wave, which is authored, telegraphed and not a reserve at all.
-- Returning 0 for them is what keeps every enemy-side reading of the loss rule exactly as it was.
function Combat.benchCount(combat, side)
    if (side or "party") ~= "party" then return 0 end
    return #((combat and combat.bench) or {})
end

-- Put a company member on the bench before the fight opens (battle setup, from whoever the player did
-- not deploy). `entry` may be a bare character or { char, relicTraits, meal }.
function Combat.benchUnit(combat, entry)
    if not entry then return nil end
    combat.bench = combat.bench or {}
    local e = entry.char and entry or { char = entry }
    combat.bench[#combat.bench + 1] =
        { char = e.char, relicTraits = e.relicTraits, meal = e.meal, statuses = nil }
    return combat.bench[#combat.bench]
end

-- May `unit` fall back right now? Returns true, or false plus the reason to show. The player-facing
-- name of this move is FALL BACK and the ground it is made from is RALLY GROUND; the model keeps the
-- older `rotate` spelling for the mechanic itself (see the section header). The button appears only
-- where this returns true, so the reasons below reach the player through `notify` rather than a
-- greyed plate -- and every one of them still names a fix.
function Combat.canRotate(combat, unit)
    if not (unit and unit.alive) then return false, "no one is acting" end
    if unit.side ~= "party" or not Combat.isPlayerControlled(unit) then
        return false, "only your own company falls back"
    end
    if unit.summoned then return false, "a summon has no one to trade with" end
    if Combat.benchCount(combat, unit.side) == 0 then return false, "no one is on the bench" end
    if not (combat.deployZone and #combat.deployZone > 0) then
        return false, "there is no rally ground to fall back to"
    end
    if not Combat.inDeployZone(combat, unit.x, unit.y) then
        return false, "stand on your rally ground to fall back"
    end
    if unit.channel then return false, "not in the middle of a cast" end
    return true
end

-- Take `unit` off the field WITHOUT killing it, keeping everything it is on the bench. The mirror of
-- Combat.dismiss for a body that walked off rather than winked out: same unwinding (its channel breaks,
-- its summons go with it, its ground and its held bodies are released), but it is not a death -- no
-- Trait.onDeath, no allyDown tally, no corpse. Nothing on this board should treat a rotation as a
-- casualty, least of all the objectives.
--
-- The unit table stays in `combat.units` flagged `withdrawn`, because that list only ever grows
-- (unit.index is a stable identity the AoE dedupe and the turn strip both key off). Coming back builds a
-- NEW unit around the same char: HP, mana and cooldowns live on the character and persist, while the
-- turn-scoped bookkeeping (tallies, anchor, tempo debt) resets -- correct, since what returns is an
-- arrival. The statuses are the exception, and are carried across deliberately (see the section header).
function Combat.withdraw(combat, unit, text)
    if not (unit and unit.alive) then return nil end
    unit.alive = false
    unit.withdrawn = true
    if unit.channel then Combat.interruptChannel(combat, unit, "withdrawn") end
    -- Animation cue: fade the body (and its timeline card) out where it stood. The same fade a death
    -- plays -- a card that simply blinks out of the strip reads as a glitch either way -- but its own
    -- cue, because this is not a death: no death sound, and nothing left lying on the tile.
    Combat.pushFx(combat, { type = "exit", unit = unit })
    Combat.logEvent(combat, "wait", text or string.format("%s falls back to the line.", unitName(unit)), unit)
    correctDecoyRecord(unit)
    for _, u in ipairs(combat.units) do
        if u.alive and u.summoner == unit then Combat.dismiss(combat, u) end
    end
    Hazard.dropOwnedBy(combat, unit)
    Combat.releaseHeldBy(combat, unit)
    -- A body on the bench is holding no turn either (see leaveTurn). Combat.rotate -- the one caller
    -- today -- ends the turn itself a few lines later, and reads the move cost off the record BEFORE
    -- this; stated here anyway so the rule holds for whoever withdraws a unit next.
    leaveTurn(combat, unit)

    combat.bench = combat.bench or {}
    local entry = { char = unit.char, relicTraits = unit.relicTraits, meal = unit.meal, statuses = unit.statuses }
    combat.bench[#combat.bench + 1] = entry
    return entry
end

-- Bring bench entry `index` onto the board at (x, y). Shared by both routes on. `initiative` is where the
-- newcomer lands on the timeline: a rotation passes the bill its predecessor ran up, a reinforcement
-- passes nothing and takes Combat.addUnit's natural-clamped-at-0 slot (it cannot cut ahead of whoever is
-- mid-turn). Returns the new unit, or nil if the entry or the ground is no good.
local function sendIn(combat, index, x, y, initiative)
    local entry = combat.bench and combat.bench[index]
    if not entry then return nil end
    local fp = entry.char.footprint or { w = 1, h = 1 }
    if not Combat.footprintFree(combat, fp.w, fp.h, x, y) then return nil end
    table.remove(combat.bench, index)
    local unit = Combat.addUnit(combat, entry.char, "party", x, y,
        { relicTraits = entry.relicTraits, meal = entry.meal })
    -- Whatever they were carrying when they stepped out is still on them when they step back in.
    if entry.statuses then unit.statuses = entry.statuses end
    if initiative then unit.initiative = initiative end
    Combat.logEvent(combat, "action", string.format("%s takes the field.", unitName(unit)), unit)
    return unit
end

-- ROTATE: the acting unit trades places with bench entry `index`, and the turn ends. The one coming on
-- stands on the tile the one leaving was holding, at the initiative that unit's turn would have cost --
-- so a rotation buys you a different body, not a free beat. Returns the new unit, or false plus a reason.
function Combat.rotate(combat, unit, index)
    local ok, why = Combat.canRotate(combat, unit)
    if not ok then return false, why end
    local entry = combat.bench and combat.bench[index]
    if not entry then return false, "nobody there" end
    local fp = entry.char.footprint or { w = 1, h = 1 }
    if fp.w > (unit.w or 1) or fp.h > (unit.h or 1) then
        -- A bigger body cannot squeeze into the space the smaller one was holding. Checked before
        -- anything is spent, so a refused rotation costs nothing.
        if not Combat.footprintFree(combat, fp.w, fp.h, unit.x, unit.y, unit) then
            return false, "no room there for " .. (entry.char.name or "them")
        end
    end

    -- Priced exactly as a wait is: the ground covered this turn, plus any debt an interrupted channel
    -- banked (a rotation can no more dodge it than a wait can), plus the rotation's own cost.
    local cost = turnMoveCost(combat, unit) + (unit.tempoDebt or 0) + Combat.ROTATE_COST
    unit.tempoDebt = nil
    Status.onTurnEnd(combat, unit)

    local x, y = unit.x, unit.y
    Combat.withdraw(combat, unit)
    local arrival = sendIn(combat, index, x, y, cost)
    if not arrival then
        -- The tile turned out to be unusable after the withdrawal (a footprint clash). The body is on the
        -- bench and the field is one short; a reinforcement fills the slot, which is exactly the state a
        -- casualty leaves behind. Deliberately not rolled back -- half-undoing a turn is worse than a
        -- legible one-slot hole.
        Combat.logEvent(combat, "system", "There was no room to trade places.")
    end

    combat.turnCount = combat.turnCount + 1
    combat.turn = nil
    Combat.rebase(combat)
    return arrival or false
end

-- Is there a slot to fill and somebody to fill it? The cap is on LIVING bodies, so a casualty opens a
-- slot the moment it drops.
--
-- The one override: with nothing of yours left standing, you may always send one in. Without it, a field
-- of four fallen bodies would be a defeat with a full bench in hand -- and that body walking on to stand
-- over its own dead is the whole reason a company is eight.
function Combat.canReinforce(combat, side)
    side = side or "party"
    if Combat.benchCount(combat, side) == 0 then return false, "no one is on the bench" end
    if Combat.aliveCount(combat, side) == 0 then return true end
    if Combat.fieldCount(combat, side) >= Combat.MAX_FIELD then
        return false, "your line is already full"
    end
    if #Combat.reinforceTiles(combat) == 0 then return false, "there is no room to come in" end
    return true
end

-- Free, standable tiles in the deploy zone -- where a reinforcement may land. Ordered as the zone is, so
-- the pick is stable.
function Combat.reinforceTiles(combat, w, h)
    w, h = w or 1, h or 1
    local out = {}
    for _, t in ipairs((combat and combat.deployZone) or {}) do
        if Combat.footprintFree(combat, w, h, t.x, t.y) then out[#out + 1] = { x = t.x, y = t.y } end
    end
    return out
end

-- REINFORCE: send bench entry `index` in on (x, y) at no cost in tempo. Not a turn -- nobody acted -- so
-- the turn count does not move and nothing is rebased, exactly as a summon arriving mid-turn does not.
-- Returns the new unit, or false plus a reason.
function Combat.reinforce(combat, index, x, y)
    local ok, why = Combat.canReinforce(combat)
    if not ok then return false, why end
    if not Combat.inDeployZone(combat, x, y) then return false, "come in through your own lines" end
    local unit = sendIn(combat, index, x, y, nil)
    if not unit then return false, "there is no room there" end
    return unit
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
        -- Two states a body can land in, and it is one OR the other, never both at once:
        --   * A revivable unit is INCAPACITATED first, not yet a corpse. It carries a countdown
        --     (status_downed) as the window in which the same character can still be brought back where
        --     it lies (Combat.reanimate). It is NOT a corpse yet, so nothing that reads the dead --
        --     Raise Dead, Corpse Burst, the Ledger's Due -- can touch it while the window is open. Let
        --     the count run out and the body TURNS TO A CORPSE (status_downed onExpire flips the flags):
        --     past reviving for this battle, but now a real body the necromancer's shelf can feed on.
        --   * A NON-revivable body (a demon) skips the window entirely and is a corpse at once: there was
        --     never anything to count, because nothing was ever going to raise it, so it is harvestable
        --     from the moment it drops.
        -- Only a real fallen unit reaches here (summons/decoys leave no body). The incapacitation is
        -- silent by design (status_downed hideLog): the "defeated!" line below is the news.
        --
        -- `noRevive` is stamped by a felling blow that DENIES the window (opts.denyRevival -- the
        -- Necromancer's severing kit: weapon_the_unreturning, ability_sever_the_thread). It forces the
        -- corpse path even on a revivable unit, so the body skips status_downed entirely and is
        -- harvestable at once -- no Revive, no scroll, no Salts this battle. It reads exactly like a
        -- demon's death: there was never a window to reach. Stamped just before this in dealFlatDamage's
        -- fatal branch, and (for the necromancer) the payoff is that the corpse is raisable NOW.
        if target.char.revivable and not target.noRevive then
            target.incapacitated = true
            Status.apply(combat, target, "status_downed")
        else
            target.corpse = true
        end
    end

    -- A decoy wears its caster's name, so "Archer is defeated!" would read as the real thing dying.
    if target.decoyOf then
        unmaskDecoy(combat, target)
    else
        Combat.logEvent(combat, "death", string.format("%s is defeated!", unitName(target)), target)
        -- Animation cue: fade the fallen unit's sprite (and its timeline card) to black and animate
        -- it out. A corpse token, when one is left, takes over once the fade completes.
        Combat.pushFx(combat, { type = "death", unit = target })
    end

    -- Before the unwinding below, so a dying trait still has its summons and reservations to spend.
    Trait.onDeath(combat, target, {})
    -- ...and the same beat for the statuses it is wearing. A bounty pays out here (the Struck Ledger):
    -- the promise was made about the BODY, so it has to settle wherever the mark ended up, which is
    -- precisely what a trait on the hunter's own grid could never see.
    Status.onDeath(combat, target, target.lastAttacker)

    for _, u in ipairs(combat.units) do
        if u.alive and u.summoner == target then Combat.dismiss(combat, u) end
    end

    -- A Taunt is a compulsion toward one specific body; when that body falls there is nothing left to
    -- go for, so drag it off everyone it was pointing at. The AI already ignores a taunt whose taunter
    -- is dead (models/ai.lua), but the status -- and its badge -- would otherwise linger for its whole
    -- duration; stripping it here keeps the board honest. Each foe holds at most one, refreshed rather
    -- than stacked, but filter on `.taunter` anyway so a future multi-taunter case stays correct.
    Status.removePointingAt(combat, "status_taunt", "taunter", target)

    -- Every surviving ally of the fallen banks an `allyDown` -- what a signature that answers a
    -- comrade's death gates on (Combat.tally). A summon/decoy leaving the field is not a comrade lost,
    -- so only a real fallen combatant (one that leaves a corpse) sends the news.
    if not target.summoned and not target.decoyOf then
        for _, u in ipairs(combat.units) do
            if u.alive and u ~= target and u.side == target.side then Combat.tally(u, "allyDown", 1) end
            -- ...and the mirror of it: everyone on the OTHER side banks a `foeDown`. Distinct from
            -- `kill`, which is credited to the one who struck the blow -- this is "the enemy is one
            -- body lighter", which is what a pool belonging to a cause rather than to a killer fills
            -- on (the Crusader's Zeal, via data/items/utility/utility_vow_of_the_march.lua).
            if u.alive and u.side ~= target.side then Combat.tally(u, "foeDown", 1) end
        end
        -- ...and EVERYONE still standing, on both sides, heard the body drop. The tally above is news
        -- for one side; this is the field itself changing, and a reflex that feeds on death does not
        -- care whose it was (Trait.onAnyDeath -- data/traits/trait_blood_fever.lua). Gated by the same
        -- condition for the same reason: a conjuration winking out is not a body hitting the ground.
        Trait.onAnyDeath(combat, target)
    end

    -- A CONJURATION coming apart is news for exactly one person: whoever paid for it. The broadcast
    -- above deliberately excludes summons -- a wolf winking out is not a body hitting the ground, and a
    -- summoner farming its own conjurations must not feed every death-reflex on the field. But the
    -- SUMMONER's own charms have a legitimate interest, and until this there was nowhere for them to
    -- hear it (the construct itself carries no grid, so a rule written on the wreck has nothing to hang
    -- from). Narrow by construction: one hook, one recipient, and only for a real summoner still
    -- standing. What the Artificer's Salvage Rig is built on.
    if target.summoned and not target.decoyOf and target.summoner and target.summoner.alive then
        Trait.onSummonLost(combat, target.summoner, { lost = target })
    end

    -- Ground the dead unit was holding open goes with it: cut down a banner and its square stops being
    -- hallowed on this beat. The statuses it was granting are not stripped here -- Hazard.reap ends
    -- those the moment it finds no zone underfoot, so a zone that vanishes and a unit that walks away
    -- unwind through exactly the same path.
    Hazard.dropOwnedBy(combat, target)
    Combat.releaseHeldBy(combat, target)
    target.char.reservations = nil
    -- ...and if the body that just dropped was the one whose turn it is, the turn drops with it.
    leaveTurn(combat, target)
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
            and Combat.unitGap(g, target) == 1 then
            local kind = g.guard.kind
            -- A DECLARED guard names the one unit it is for (data/traits/trait_oathward_declared.lua):
            -- it guards that ally absolutely and everyone else not at all. An undeclared guard has no
            -- `ward` and covers whoever is standing beside it, which is the innate Oathward. The
            -- narrower promise is the stronger one -- the declared form waives its cooldown -- and that
            -- trade is the knight's whole arc (docs/story.md, "Her three oaths").
            if g.guard.ward and g.guard.ward ~= target then
                -- sworn to someone else: this blow is not theirs to take
            elseif kind == "oathward" and not Combat.onCooldown(g, "oathward") then
                Combat.setCooldown(g, "oathward", g.guard.cooldown or 6)
                Combat.logEvent(combat, "action",
                    string.format("%s takes the blow for %s!", unitName(g), unitName(target)), { g, target })
                return g
            elseif kind == "martyr" and not g.guard.used then
                if Combat.mitigatedDamage(target, base, tags) >= (target.char.stats.health.current or 0) then
                    g.guard.used = true
                    Combat.logEvent(combat, "action",
                        string.format("%s throws itself in front of %s!", unitName(g), unitName(target)),
                        { g, target })
                    return g
                end
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Held answers
--
-- A reaction answers a FINISHED action, never a half-applied one -- the same rule Trait.onCast already
-- runs by. It matters because an ability is a sequence: the mace lands its blow and THEN shoves the
-- target two tiles back, and the counter belongs to the board that stands when the whole swing is over,
-- not the one that stood mid-effect. Dispatched inline, a counter is thrown from a tile its bearer no
-- longer occupies -- a brawler answering in melee someone who is now three squares away.
--
-- So while a cast is resolving, an on-hit answer is HELD rather than thrown (Combat.beginAnswers around
-- the effect, Combat.endAnswers after it), and the flush re-asks every gate against the board as it
-- finally stands. Nothing else moves: the exchange still resolves in one uninterrupted pass, and a blow
-- struck outside a cast (a trap, a hazard tick, a counter's own free swing) holds nothing and dispatches
-- where it always did.
--
-- Two consequences worth naming, both wanted:
--   * a target the same effect goes on to KILL answers nothing -- the flush skips the fallen, exactly as
--     the inline dispatch never reached a corpse;
--   * a counter thrown during the flush finds the hold already popped, so ITS answer dispatches inline
--     (the swing is not a cast) -- the recursion guards in models/trait.lua are unchanged.
local function dispatchAnswer(combat, held)
    Trait.onDamaged(combat, held.unit, held)
    -- The statuses riding the survivor get the same news, for the ones a blow is supposed to BREAK
    -- (Sleep). After the traits, so a reflex that answers the blow is not robbed of its trigger by the
    -- very hit that wakes its bearer -- the order the inline dispatch ran in, carried across the hold.
    if held.wakes then Status.onDamaged(combat, held.unit, held.amount, held.tags) end
    -- ...and the striker's ALLIES beside the struck body get their opening (Trait.onAllyStrike -- what a
    -- follow-up hangs on). Fired here, at the same settled moment onDamaged is, so a follow-up is judged
    -- by the board as it finally stands rather than mid-effect.
    --
    -- Gated on the triggering blow NOT itself being an answer (`held.at.answering`, snapshotted at the
    -- moment of the hit): only a genuine attack provokes follow-ups, never the swirl of counters and
    -- ripostes an exchange throws off. That single check is the whole recursion guard -- a follow-up
    -- swing is thrown while its bearer is mid-reaction (Trait.isReacting), so ITS raised answer carries
    -- answering = true and provokes no further follow-ups. So a real strike opens exactly one round of
    -- them and the chain stops, without a latch of its own.
    if held.attacker and not (held.at and held.at.answering) then
        Trait.onAllyStrike(combat, held.attacker, held.unit)
    end
end

-- Open a hold: every answer provoked from here until the matching endAnswers waits for the action to
-- finish. Nested, because an effect can drive a sub-strike that opens one of its own.
function Combat.beginAnswers(combat)
    if not combat then return end
    local holds = combat._answerHolds
    if not holds then holds = {}; combat._answerHolds = holds end
    holds[#holds + 1] = {}
end

-- Close the innermost hold and throw what it caught, in the order the blows landed. The hold is popped
-- BEFORE the flush so an answer's own blow is dispatched normally rather than caught by the hold it is
-- draining, which would never drain.
function Combat.endAnswers(combat)
    local holds = combat and combat._answerHolds
    local held = holds and table.remove(holds)
    if not held then return end
    for _, a in ipairs(held) do
        if a.unit.alive then dispatchAnswer(combat, a) end
    end
end

local function raiseAnswer(combat, unit, info)
    info.unit = unit
    -- Surviving a blow banks it toward any signature the survivor gates on being struck (Combat.tally).
    -- This is the one choke every survive branch funnels through (preventsDeath, Second Wind, and the
    -- ordinary case), and the killing blow never reaches it -- so a wound survived counts and a fatal
    -- one does not. `damageTaken` counts any survived source (a burn, a trap); `hitTaken` only a real
    -- blow with a known attacker, which is what "weather N blows" means.
    if (info.amount or 0) > 0 then
        Combat.tally(unit, "damageTaken", info.amount)
        if info.attacker then Combat.tally(unit, "hitTaken", 1) end
    end
    -- What was true at the MOMENT OF THE HIT, carried along because a held answer is thrown after it
    -- has stopped being true (see Trait.mayCounter, which reads this back):
    --   * `answering` -- was the blow itself an answer? The flag it comes off only stands for the
    --     flight of the swing that set it, so by flush time a riposte has long since put it back down.
    --     Without the snapshot a held reflex reads every riposte as a fresh attack and answers it, and
    --     two duelists volley forever -- the exact bug `answersReactions` exists to prevent.
    --   * the two tiles the blow was struck ACROSS -- what a reflecting reflex is judged by, since
    --     spikes bite the fist at the instant it lands and not wherever a later shove leaves anyone.
    info.at = {
        answering = Trait.isReacting(info.attacker),
        ux = unit.x, uy = unit.y,
        ax = info.attacker and info.attacker.x, ay = info.attacker and info.attacker.y,
    }
    local holds = combat and combat._answerHolds
    local top = holds and holds[#holds]
    if top then top[#top + 1] = info else dispatchAnswer(combat, info) end
end

-- Take `amount` straight out of `unit`'s health as a TOLL rather than a blow, and fell it if that
-- empties the bar. Shared by the two ways a wound reaches a body that was never struck: the knight's
-- Shared Burden (a transfer) and the Arcanum's Conjunction (an echo).
--
-- A toll is deliberately not a hit. It is not mitigated -- the wound it came from already passed
-- somebody's armor, and charging it to a second set of plate would make being linked to a target
-- better than being the target. It has no attacker, so nothing can parry it, riposte it, reflect it or
-- counter it; and it provokes no reflex, because there is nobody in the room to answer. What arrives
-- is a consequence, not an exchange.
--
-- Split out because both callers need every line of it identical -- the health floor, the animation
-- cue, the log line, the kill -- and a second copy that drifted would be a body that died in one
-- system and stood up in the other.
local function tollHealth(combat, unit, amount, text, subjects)
    local hp = unit.char.stats.health
    hp.current = math.max(0, hp.current - amount)
    Combat.pushFx(combat, { type = "damage", unit = unit, amount = amount, lethal = hp.current <= 0 })
    Combat.logEvent(combat, "action", text, subjects)
    if hp.current <= 0 then killUnit(combat, unit) end
    return amount
end

-- Move a share of a wound off `target` and onto whoever bound themselves to it (the Shared Burden
-- status, sworn by the knight's ability of the same name). Returns how much was taken away, which the
-- caller subtracts -- so the two halves always add back up to the blow that was struck.
--
-- A TRANSFER: the total damage in the world is unchanged, only who carries it. Compare
-- Combat.echoWound below, which is the same machinery pointed the opposite way -- it MULTIPLIES a
-- wound across a group rather than dividing one between two bodies. That the knight's item conserves
-- and the mage's amplifies is the whole difference between a promise and a working.
--
-- Three refusals, each closing a way the bond could otherwise become a loop or a lie:
--   * a bond whose swearer has fallen is over -- the status is stripped, so a dead knight's ward stops
--     paying into a grave;
--   * a bond may not pay into itself, and a unit bonded to a unit bonded back would volley one wound
--     between two bodies until both were dead. `_sharing` latches for the flight of the transfer, so
--     the second hop simply lands.
--   * a share below a full point is not taken at all, so a scratch is the ward's own to bear -- the
--     same floor Thorns uses, and for the same reason: a 0-damage transfer is a log line about nothing.
function Combat.shareBurden(combat, target, dmg)
    if combat._sharing or dmg <= 0 then return 0 end
    for _, s in ipairs(target.statuses or {}) do
        local share = s.def.sharesDamage
        local bearer = s.bonded
        if share and bearer then
            if not bearer.alive then
                Status.remove(combat, target, s.id)
                return 0
            end
            local moved = math.floor(dmg * share)
            if moved < 1 then return 0 end
            combat._sharing = true
            tollHealth(combat, bearer, moved,
                string.format("%s bears %d of %s's wound.", unitName(bearer), moved, unitName(target)),
                { bearer, target })
            combat._sharing = false
            return moved
        end
    end
    return 0
end

-- Echo a wound out of `target` into everyone else bound into the same CONJUNCTION (the Conjoined
-- status, laid over an area by the mage's ability of the same name). Returns the total dealt to the
-- others -- which the caller does NOT subtract, because this multiplies rather than divides: the unit
-- actually struck keeps its whole wound, and each of the others takes `echoesDamage` of it on top.
--
-- That is the exact inversion of Combat.shareBurden above, and the pair is worth reading together. A
-- bond CONSERVES: 40 damage becomes 20 and 20, and the knight has bought an ally's life with its own.
-- A conjunction AMPLIFIES: 40 damage becomes 40 and 20 and 20 and 20, and the mage has bought a
-- massacre with a turn. One machine, two signs -- and the sign is the difference between a promise
-- and a working.
--
-- Bound by a LINK, a bare table minted per cast and stamped on every status the cast lands. Without it
-- two conjunctions on opposite ends of the field would feed each other, and a mage would spend its
-- second cast making its first one worse in a way nobody could see. A unit can only carry one (statuses
-- are one-instance-per-id, so a second cast re-binds rather than stacking), which is what keeps the
-- rule sayable in one sentence.
--
-- Each echo lands as a TOLL (see tollHealth): unmitigated, unattributed, unanswerable. Unmitigated is
-- doing real work here rather than being a shortcut -- it is the ability's answer to armor, in the same
-- way the Vitriol Wand's is (docs/weapons.md), and it is why a conjunction laid over four heavy
-- infantry is worth more than a bigger spell aimed at one of them.
--
-- Three refusals, mirroring the bond's:
--   * `_echoing` latches for the flight of the echo, so an echo cannot echo -- without it, four linked
--     bodies would ring off each other until the whole field was dead;
--   * the fallen are skipped, and so is the struck unit itself (it already has its wound);
--   * a share below a full point is not sent, so a scratch stays where it landed.
function Combat.echoWound(combat, target, dmg)
    if combat._echoing or dmg <= 0 then return 0 end
    local source
    for _, s in ipairs(target.statuses or {}) do
        if s.def.echoesDamage and s.link then source = s break end
    end
    if not source then return 0 end
    local share = math.floor(dmg * source.def.echoesDamage)
    if share < 1 then return 0 end

    combat._echoing = true
    local total = 0
    -- Snapshot the roster: an echo may fell somebody, and killUnit is entitled to touch combat.units.
    local roster = {}
    for _, u in ipairs(combat.units) do roster[#roster + 1] = u end
    for _, u in ipairs(roster) do
        if u ~= target and u.alive then
            for _, s in ipairs(u.statuses or {}) do
                if s.def.echoesDamage and s.link == source.link then
                    total = total + tollHealth(combat, u, share,
                        string.format("%s feels %s's wound through the conjunction (%d).",
                            unitName(u), unitName(target), share), { u, target })
                    break
                end
            end
        end
    end
    combat._echoing = false
    return total
end

function Combat.dealFlatDamage(combat, target, base, tags, source, attacker, opts)
    -- Debug: an invulnerable target (toggled from the right-click debug menu, debug builds only)
    -- shrugs off every blow. Guarded here at the one funnel ALL damage runs through -- a strike, a
    -- trap, a Burn tick, an area blast -- so it needs no reach into each caller. Inert for every
    -- ordinary unit: the field is nil unless the debug menu set it.
    if target.debugInvuln then return 0 end
    -- A body already going down mid-shove takes no further processing. When a killing blow folds a
    -- knockback in (the Iron Mace, the Sworn Aegis -- opts.knockback below), the target is marked
    -- mortally wounded and carried to where it will fall BEFORE killUnit finishes it -- and anything it
    -- slams into on the way re-enters here (a wall, a trap it is flung across). It is already doomed
    -- and killUnit is queued, so a second death path would fell it twice; skip it.
    if target.mortallyWounded then return 0 end
    -- An adjacent guardian (Oathward, Martyr's Vow) may take the blow in the target's place. The
    -- redirected hit re-enters here on the guardian, so its own armor, barrier and traits all apply.
    -- The shove does NOT ride along, though: a knockback is aimed at the ORIGINAL target and would fling
    -- the interposing guardian off the attacker->guardian line -- straight away from the ally it just
    -- stepped in front of, which is the opposite of the effect. The martyr holds its ground and takes the
    -- damage; only the blow is redirected, not the geometry meant for someone else. A fresh opts (never
    -- the caller's, which an area sweep may reuse across targets) drops the shove and keeps the rest.
    local guardian = Combat.tryRedirect(combat, target, base, tags)
    if guardian then
        local redirected = opts
        if opts and opts.knockback then
            redirected = {}
            for k, v in pairs(opts) do redirected[k] = v end
            redirected.knockback = nil
        end
        return Combat.dealFlatDamage(combat, guardian, base, tags, source, attacker, redirected)
    end
    -- A barrier of the incoming school (physical/magical, the same switch mitigation reads) negates
    -- the blow outright: consume that one ward, deal nothing, and return BEFORE the trait dispatch --
    -- an absorbed hit is not a "wound survived", so it grants no rage and advances no threshold phase.
    -- A ward may stand for several blows (its `magnitude`, which the granting spell raises as it is
    -- forged), so spend ONE hit rather than the whole status and say what is left standing.
    -- A per-type IMMUNITY (Immune: Fire) voids the blow before anything else touches it -- before the
    -- barrier, before the reflexes, before the trait dispatch. An immune body takes nothing and, unlike
    -- a barrier, spends nothing to do so: no charge, no ward consumed. Returned here as a 0, so an immune
    -- hit grants no rage, advances no threshold phase and provokes no counter, exactly as an absorbed one
    -- does. Placed ahead of the barrier so a blow you are already immune to cannot waste a ward charge.
    local immune = Status.immuneToDamage(target, tags)
    if immune then
        Combat.logEvent(combat, "status",
            string.format("%s is immune to the blow (%s).", unitName(target), immune.name or immune.id), target)
        return 0
    end
    local barrier = Status.barrierAgainst(target, hasTag(tags or {}, "magical"))
    if barrier then
        -- What the ward SWALLOWED, banked on the instance. Almost every barrier ignores this; the
        -- Kept Wound (data/status/status_kept_wound.lua) is the one that reads it back, throwing
        -- everything it ate at the ground around its bearer when it finally lets go. Recorded here,
        -- at the single place a ward eats a blow, so a barrier that wants the number never has to
        -- intercept the damage path itself to get it -- it just declares `onExpire` and reads.
        --
        -- The PRE-mitigation figure, deliberately: the ward stood in front of the armor, so what it
        -- absorbed is the blow as thrown, not the remainder armor would have left.
        barrier.absorbed = (barrier.absorbed or 0) + (base or 0)
        local left = Status.consumeBarrier(combat, target, barrier)
        local note = ""
        if left > 0 then note = string.format(" (%d left)", left) end
        Combat.logEvent(combat, "status",
            string.format("%s's %s absorbs the blow%s.", unitName(target), barrier.name or barrier.id, note),
            target)
        return 0
    end
    -- A DEFERRAL (the Sealed Hour) takes the blow onto its ledger instead of onto the body. Sits with
    -- the barrier above rather than after mitigation, and for the same reason: nothing reached the
    -- flesh, so this is not a wound survived -- it grants no rage, advances no threshold phase, and
    -- provokes no counter. The bearer cannot be killed while it holds, and cannot be saved either.
    --
    -- The mitigated figure, unlike the barrier's: a deferral does not stand in front of the armor, it
    -- stands in front of the CLOCK. What is owed is what would really have landed, and the ledger
    -- settles later at exactly that.
    local deferral = Status.deferralOn(target)
    if deferral then
        local owed = Combat.mitigatedDamage(target, base, tags, opts)
        Status.defer(deferral, owed)
        Combat.logEvent(combat, "status",
            string.format("%s's wound is held for later (%d).", unitName(target), owed), target)
        return 0
    end
    -- A standing Dodge reflex (a trait on cooldown, not a consumed status) voids a physical blow
    -- outright. Like the barrier above it returns BEFORE the trait damage dispatch -- an evaded hit is
    -- not a wound survived, so it grants no rage, advances no threshold phase, and provokes no counter.
    if Trait.tryEvade(combat, target, tags) then
        Combat.pushFx(combat, { type = "miss", unit = target })
        return 0
    end
    -- A carried smoke charge (Smoke Bomb) negates an incoming ATTACK outright and blinks the bearer
    -- clear. Like the Dodge reflex above it returns BEFORE mitigation and the trait damage dispatch,
    -- so a vanished blow grants no rage and provokes no counter; only a real strike (a known attacker)
    -- fires it, so a poison tick or trap can't waste the one charge.
    if Trait.trySmoke(combat, target, attacker) then
        Combat.pushFx(combat, { type = "miss", unit = target })
        return 0
    end
    -- A standing CLONE dies in the bearer's place and they trade tiles (the Ninja's Substitution).
    -- Beside the two above and for the same reason: the blow landed on a conjuration, so there is no
    -- wound to grant rage or provoke an answer. Unlike them it spends no cooldown and no charge -- the
    -- clone was the charge, and it had to be cast.
    if Trait.trySubstitute(combat, target, attacker) then
        Combat.pushFx(combat, { type = "miss", unit = target })
        return 0
    end
    -- SPELL EATER (the Spellbreaker's): a MAGICAL blow lands lighter on the bearer, and the difference
    -- is refunded to them as mana. Anti-magic as absorption rather than denial -- the enemy caster still
    -- gets to cast, and gets to watch it pay for the answer.
    --
    -- Placed after the negating reflexes and before mitigation, so it is a discount on a blow that is
    -- really going to land rather than a fourth way of voiding one. The refund is the eaten half, so an
    -- item that reduces more also feeds more, and there is only one number to tune.
    if (base or 0) > 0 and hasTag(tags, "magical") then
        local eater = Trait.flag(target, "eatsMagic")
        if eater then
            local share = (eater.def and eater.def.magnitude or 40) / 100
            local eaten = math.floor(base * share)
            if eaten > 0 then
                base = base - eaten
                Combat.restoreResource(target.char, "mana", eaten)
                Combat.logEvent(combat, "status",
                    string.format("%s swallows the working (%d mana).", unitName(target), eaten), target)
            end
        end
    end
    -- A duelist's blade (the Riposte Blade) turns an incoming melee blow aside and answers it in the
    -- same motion. Like the two reflexes above it returns BEFORE mitigation and the trait damage
    -- dispatch -- a blow that never landed is not a wound survived, so it grants no rage and provokes
    -- no second counter on top of the riposte's own.
    if Trait.tryRiposte(combat, target, attacker, tags, opts and opts.area) then
        return 0
    end
    -- A preternatural reflex (Keen Senses) answers an incoming attack BEFORE it lands, spending stamina.
    -- Unlike the three reflexes above it does not negate the blow: it only goes first, so it returns
    -- true -- and stops the hit here -- purely in the case where its counter killed the attacker and
    -- the swing died with them. A counter that merely wounds falls through, and the blow lands on top
    -- of it as normal.
    if Trait.tryPreempt(combat, target, attacker, opts and opts.area) then
        return 0
    end
    local dmg = Combat.mitigatedDamage(target, base, tags, opts)
    -- A Mana Shield (data/items/utility/utility_mana_shield.lua) pays the wound out of the wrong pool.
    -- It runs AFTER mitigation and not before, unlike the barrier above: armor still gets its full say,
    -- and what the shield is asked to cover is the number that would actually have reached the body.
    -- Draining the smaller pool to spare the larger one is only a bargain while the mana lasts, and
    -- pricing it against the post-armor figure is what keeps it from being strictly better than armor.
    local soaked = Combat.soakIntoMana(combat, target, dmg)
    if soaked > 0 then
        dmg = dmg - soaked
        -- Fully covered: nothing reached the body. Return here exactly as the barrier branch does --
        -- a blow that drew no blood is not a wound survived, so it grants no rage, advances no
        -- threshold phase and provokes no counter.
        if dmg <= 0 then return 0 end
    end
    -- An open ACCOUNT (On Account) settles part of the wound out of the purse instead of the flesh.
    -- Beside the Mana Shield above and for the same reason: what the account covers is the number that
    -- would actually have reached the body. It pays second, so a bearer carrying both spends the smaller
    -- pool before the bank -- mana regenerates between fights and gold does not.
    local billed = Combat.soakIntoPurse(combat, target, dmg)
    if billed > 0 then
        dmg = dmg - billed
        -- Fully settled: nothing reached the body, so -- exactly as above -- no rage, no threshold
        -- phase, no counter. The blow was paid for, not survived.
        if dmg <= 0 then return 0 end
    end
    -- A standing BOND (Shared Burden) moves a share of the wound onto whoever swore it, wherever they
    -- are standing. Runs here, on the far side of mitigation, for the same reason the Mana Shield above
    -- it does: what a promise covers is the number that would actually have reached the body, not the
    -- number that was thrown at it. The ward's own armor gets its full say first, and only then is the
    -- remainder split.
    dmg = dmg - Combat.shareBurden(combat, target, dmg)
    if dmg <= 0 then return 0 end
    local hp = target.char.stats.health
    hp.current = hp.current - dmg
    -- Who last drew blood, kept on the body so killUnit can name a killer to the hooks that pay one
    -- (Status.onDeath -> the Struck Ledger's bounty). Stamped on every landed blow rather than only on
    -- the lethal one, because the lethal one is not distinguishable here -- and stamped only for a
    -- KNOWN attacker, so a poison tick or a fire leaves whatever struck last standing rather than
    -- overwriting it with nobody.
    if attacker then target.lastAttacker = attacker end
    -- Animation cue: the blow that actually landed (post-mitigation), flagged lethal so the view
    -- can punch a killing hit harder. The matching death cue is pushed by killUnit below.
    -- `tags` rides along untouched so the view can pick the blow's picture -- a slash arc, a fire
    -- bloom, a bolt fork -- off the same tag list ui/motif.lua reads everywhere else. The model states
    -- what the blow WAS and stays out of how it looks; ui/burst_fx.lua turns the tags into a shape.
    -- `vulnerable` flags a blow that struck a WEAKNESS: the net of every vulnerability/resistance the
    -- target carries for this blow's tags is positive, so the wound landed harder than a bare hit
    -- (the Vulnerable openers, Wet under lightning, Frozen under crush/fire, Exposed, a Reckless
    -- Cuirass's gear-bound weakness -- all fold through Status.vulnerability). The extra damage is
    -- already IN `dmg`; this is only the cue for it, so ui/burst_fx.lua can flare a "weak point struck"
    -- over the impact and the player can read at a glance that the tag they chose is the one that bites.
    local vulnerable = Status.vulnerability(target, tags) > 0
    Combat.pushFx(combat, { type = "damage", unit = target, amount = dmg,
        lethal = hp.current <= 0, attacker = attacker, tags = tags, vulnerable = vulnerable })
    local entry
    if source then
        entry = Combat.logEvent(combat, "damage",
            string.format("%s takes %d damage from %s.", unitName(target), dmg, source), { target, attacker })
    else
        entry = Combat.logEvent(combat, "damage",
            string.format("%s takes %d damage.", unitName(target), dmg), { target, attacker })
    end
    -- Attach the arithmetic behind the number so the combat-log panel can show it on hover. Reads the
    -- same base, tags and opts the hit resolved with; a flat source (trap/burn) carried no baseParts,
    -- so its breakdown falls back to a single "Base" row.
    if entry then
        entry.detail = Combat.damageBreakdown(target, base, tags, opts, opts and opts.baseParts, dmg)
    end
    -- A CONJUNCTION rings: everyone else bound into the same working takes a share of what just landed
    -- here (Combat.echoWound). Placed after the wound and its log line so the reading order matches the
    -- fiction -- the blow lands, and then the others feel it -- and after `dmg` is final, since what
    -- echoes is what actually reached the body rather than what was aimed at it. Nothing is subtracted:
    -- this multiplies a wound rather than dividing one (compare the bond above, which does the
    -- opposite and is subtracted for exactly that reason).
    Combat.echoWound(combat, target, dmg)
    -- A blow may CARRY hard control (a hammer's Stun, an ice bolt's Freeze): `opts.inflicts` names a
    -- status that lands WITH the hit rather than after it. The distinction is the whole point --
    -- an effect that applies its stun on the line after `fx.damage` applies it one line too late,
    -- because the counter it was supposed to prevent already fired from inside the damage core. So
    -- the status goes on here, between the wound and Trait.onDamaged, and the reaction gate
    -- (Status.disablesReactions, read by every path in models/trait.lua) finds it in time: a fighter
    -- the hammer just rattled does not answer the hammer.
    --
    -- It lands here and not earlier for a reason of its own: mitigation is already computed above, so
    -- a status that makes its bearer softer (Frozen's crush/fire `vulnerable`) cannot feed the very
    -- bolt that applied it. And the pre-hit reflexes -- Dodge, Riposte, Keen Senses -- all returned
    -- long before this line, which is correct: they NEGATE the blow, and a blow that never landed
    -- never stunned anyone, so it has no business suppressing the answer to it.
    --
    -- Accepts an id, or { id = ..., ... } carrying Status.apply opts (a `magnitude` scaled off Power).
    -- Only a survivor is worth controlling, so each path below inflicts before it dispatches, and the
    -- death path (which never dispatches) skips it -- no stunning a corpse.
    -- The attacker rides along as `applier` (as fx.applyStatus does for a status applied the ordinary
    -- way), so an onStatusApplied hook on the striker still fires -- the Stripped Plate that wears what
    -- its Sunder strips, a bounty that credits its setter. A flat source (trap, burn tick) has no
    -- attacker and so sets none, exactly as it did before. A fresh opts per status, never the caller's.
    local function inflictCarried()
        for _, c in ipairs(carriedStatuses(opts)) do
            local o = c.opts
            if attacker then
                o = {}
                if c.opts then for k, v in pairs(c.opts) do o[k] = v end end
                if o.applier == nil then o.applier = attacker end
            end
            Status.apply(combat, target, c.id, o)
        end
    end
    -- A blow may CARRY a shove (the Iron Mace, the Sworn Aegis): `opts.knockback = { distance, amount }`
    -- drives the target back along the line from its attacker the instant the hit lands. It is folded
    -- INTO the blow, not run as a separate step, so a KILLING hit still throws the body -- the fatal
    -- branch below shoves the mortally-wounded target before killUnit finishes it. It runs AFTER
    -- raiseAnswer in every survive path, so a reflecting reflex is still judged by the tile the blow
    -- landed on (raiseAnswer snapshots that position) and not by wherever the shove leaves the body.
    -- Needs a real attacker to take the direction from -- a trap or a burn tick carries no shove.
    local function applyKnockback()
        local kb = opts and opts.knockback
        if kb and attacker then
            Combat.knockback(combat, attacker, target, kb.distance, { amount = kb.amount })
        end
    end
    -- A berserk window (Fury's `preventsDeath` status) holds the bearer up at 1 HP through a blow
    -- that would fell it -- but never a `fragile` shape (a decoy/doppelganger is unmade by any hit).
    if hp.current <= 0 and not target.fragile and Status.preventsDeath(target) then
        hp.current = 1
        Combat.logEvent(combat, "action",
            string.format("%s refuses to fall!", unitName(target)), target)
        inflictCarried()
        raiseAnswer(combat, target, { amount = dmg, tags = tags, source = source, attacker = attacker,
            area = opts and opts.area })
        applyKnockback()
        return dmg
    end
    -- A `fragile` unit (a doppelganger, a decoy) dies to ANY hit, however light. Damage floors at 1
    -- in mitigatedDamage, so reaching here at all is fatal for one.
    if hp.current <= 0 or target.fragile then
        -- A once-per-battle Second Wind trait may catch a would-be-lethal blow and stand the bearer
        -- back up at half health, exactly like a barrier voids a hit -- but only a "real" unit
        -- (never a fragile shape, which the check above already excluded from the death path).
        if not target.fragile and Trait.trySurvive(combat, target) then
            inflictCarried()
            raiseAnswer(combat, target, { amount = dmg, tags = tags, source = source, attacker = attacker,
            area = opts and opts.area })
            applyKnockback()
            return dmg
        end
        hp.current = 0
        -- The felling blow banks a `kill` toward any signature the attacker gates on kills. Only a
        -- real attack passes an attacker; a trap or a burn tick fells with none and tallies nothing.
        if attacker then Combat.tally(attacker, "kill", 1) end
        -- A blow that DENIES REVIVAL (opts.denyRevival -- the Necromancer's severing kit) stamps the
        -- body so killUnit routes it straight to a corpse, skipping the incapacitation window. Set only
        -- on the fatal path, so a severing weapon that merely wounds does nothing -- it is the KILL that is
        -- final, not the hit. Carried through the guard-redirect above with the rest of opts, so a
        -- guardian that throws itself in front of the blow is denied the window too.
        if opts and opts.denyRevival then target.noRevive = true end
        -- A killing blow that also SHOVES throws the body before it drops: mark the target mortally
        -- wounded -- doomed, but still on its feet and on the board -- so the shove can move it and
        -- hurt whatever it slams into (Combat.knockback carries only the living, and the collision it
        -- deals re-enters dealFlatDamage where the guard at the top skips a body already going down).
        -- THEN killUnit finishes it, so the death fade plays where the shove came to rest. A blow with
        -- no shove kills exactly as before -- the flag is never set.
        if opts and opts.knockback and attacker then
            target.mortallyWounded = true
            applyKnockback()
            target.mortallyWounded = nil
        end
        killUnit(combat, target)
    else
        -- Reaction traits are raised here and nowhere else: AFTER mitigation, so a hook reads the damage
        -- that actually landed, and only on a SURVIVOR, so the blow that kills you grants no rage and
        -- a boss's health-threshold phase can never trigger on a corpse. Nothing in the damage
        -- PREVIEW reaches this function (previewAbility routes through Combat.computeDamage), so a
        -- hovered target never quietly advances a trait. Raised, not necessarily thrown on this line:
        -- inside a resolving cast the answer waits for the effect to finish (see Combat.beginAnswers).
        inflictCarried()
        -- ...and the statuses riding the survivor get the same news (`wakes`), for the ones a blow is
        -- supposed to BREAK (Sleep) -- raised together so the hold cannot separate them.
        raiseAnswer(combat, target, { amount = dmg, tags = tags, source = source, attacker = attacker,
            area = opts and opts.area, wakes = true })
        applyKnockback()
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
        unitName(target), mirror.name or mirror.id, unitName(user)), { target, user })
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
    -- THE RESONANT GRIP (the Battlemage's): a bearer's weapon strikes carry the element of whatever they
    -- last cast. Folded into the tag set here, so it reaches armour `resist`, the elemental interactions
    -- (a lightning strike arcing into water, a fire blow burning through Wet) and the damage scaling all
    -- at once -- which is the whole point of it being a tag rather than a damage bonus.
    --
    -- Only for a NON-magical strike: a spell already has its own element, and letting the grip overwrite
    -- one Fireball with the memory of another would be a bug that reads as flavour.
    if not hasTag(tags, "magical") and user and user.lastCastElement
        and Trait.flag(user, "carriesLastElement") then
        tags[#tags + 1] = user.lastCastElement
    end
    local magical = hasTag(tags, "magical")
    local atkStat = magical and "magicDamage" or "damage"
    local ab = item and item.activeAbility
    -- Additive: the ability's damage plus the attacker's attack stat (opts.amount overrides the
    -- declared damage for a one-off hit). Mitigation then subtracts the target's defense + resists.
    -- A standing charm may add a conditional bite (Cutpurse's Tally per debuff, the Marksman's Lens
    -- against a Marked foe). Pure and summed into `base` here AND in computeDamage below, so the hover
    -- preview never disagrees with the blow. See Trait.outgoingDamageBonus.
    local charmBonus = Trait.outgoingDamageBonus(combat, user, target, item, tags)
    local base = (opts.amount or (ab and ab.damage) or 0) + flatStat(user, atkStat) + unarmedDamageBonus(user, item) + charmBonus
    -- Name where that pre-mitigation power came from, so the combat-log hover can spell it out: the
    -- attacker's attack stat, the weapon/ability's own damage, and any bare-fist bonus. Rides along on
    -- opts (like opts.area below) to the flat path, which folds it into the damage line's breakdown.
    -- Split the attacker's attack stat into its base and each thing that moves it -- equipment, then
    -- every buff/debuff by name -- so the tooltip lists them as separate signed lines instead of one
    -- number. The parts sum to flatStat(user, atkStat), the same value the `base` above folded in.
    local baseParts = {}
    local atkBase = (user.char and user.char.stats[atkStat]) or 0
    if atkBase ~= 0 then
        baseParts[#baseParts + 1] = { label = unitName(user) .. (magical and " (Magic)" or " (Attack)"), value = atkBase }
    end
    local atkItemTotal = (user.bonus and user.bonus[atkStat]) or 0
    local atkAttributed = 0
    for _, p in ipairs(equipmentStatParts(user, atkStat)) do
        baseParts[#baseParts + 1] = { label = p.label, value = p.value, signed = true }
        atkAttributed = atkAttributed + p.value
    end
    if atkItemTotal - atkAttributed ~= 0 then
        baseParts[#baseParts + 1] = { label = "Equipment", value = atkItemTotal - atkAttributed, signed = true }
    end
    for _, p in ipairs(Status.statBonusParts(user, atkStat)) do
        baseParts[#baseParts + 1] = { label = p.label, value = p.value, signed = true }
    end
    local abVal = opts.amount or (ab and ab.damage) or 0
    if abVal ~= 0 then
        baseParts[#baseParts + 1] = { label = (item and item.name) or (ab and ab.name) or "Ability", value = abVal }
    end
    local fistVal = unarmedDamageBonus(user, item)
    if fistVal ~= 0 then baseParts[#baseParts + 1] = { label = "Unarmed bonus", value = fistVal } end
    if charmBonus ~= 0 then baseParts[#baseParts + 1] = { label = "Charm bonus", value = charmBonus } end
    opts.baseParts = baseParts
    -- Flag a blow that came out of an AREA ability (a bomb, a fireball, a cleave), so the reflexes down
    -- in dealFlatDamage know a blast from a blow aimed at one body: nothing answers a blast (see
    -- Trait.mayCounter). Keyed on the same isSingleTarget the wards above are, and for the same reason.
    -- This is the only path that knows the ITEM -- a trap or a Burn tick reaches the flat path with no
    -- ability at all, and passes no attacker either, so it provokes nothing regardless.
    if ab and not Combat.isSingleTarget(ab) then opts.area = true end
    -- A counter or a mirror may unmake the cast entirely before it reaches the target's armor.
    if tryWardSpell(combat, user, target, item, tags, base, opts) then return 0 end
    -- `user` rides along as the attacker so a reaction trait (a counter) knows who struck, and how
    -- far away they stood. A flat source (a trap, a burn) passes no attacker and provokes no counter.
    local dealt = Combat.dealFlatDamage(combat, target, base, tags, nil, user, opts)
    -- Let the attacker's statuses record what they just did (Fury banks damage dealt to heal from
    -- later). Fired here, where the attacker is known, only for a survived-or-not real hit.
    Status.onDealDamage(combat, user, dealt)
    -- ...and bank the blow toward any signature the attacker gates on landing hits (Combat.tally).
    -- Only a blow that drew blood counts, so a whiffed 0-damage swing advances nothing.
    if dealt > 0 then
        Combat.tally(user, "hitDealt", 1)
        Combat.tally(user, "damageDealt", dealt)
        -- A BARE-HANDED blow also banks chi (Combat.chi) -- the monk's charge is built by punching and
        -- by nothing else, so a blow struck with a crafted weapon banks none. Identified the one way
        -- unarmed ever is in this file, by instance rather than by tag: `char.unarmed` is a single
        -- hidden weapon (models/character.lua attaches it), which is what keeps a "fist"-tagged
        -- knuckle-duster from quietly counting as a fist.
        if user.char and item == user.char.unarmed then Combat.tally(user, "unarmedHit", 1) end
        -- A summon's blow also banks onto its summoner, so a signature can charge off the deeds of the
        -- creature it fields -- the Wolfsong Horn fills as Kaya's wolf draws blood (companionDamage).
        if user.summoner then Combat.tally(user.summoner, "companionDamage", dealt) end
        -- BATTLE CASTING (the Battlemage's), the other half: steel feeds the working. A non-magical blow
        -- hands a little mana back, so a battlemage out of spells is not out of the fight -- it is one
        -- swing away from being back in it. Only physical blows, or a mage would be refunding itself for
        -- casting.
        if not magical and Trait.flag(user, "strikesRefundMana") then
            Combat.restoreResource(user.char, "mana", 3)
        end
        -- ...and every ALLY standing next to the body that just took it banks "allyStruck". The
        -- counterpart to hitTaken, seen from one tile over: what a formation charge pool fills on when
        -- the line beside you is being worked over rather than you (the Champion's Crowd's Favour).
        --
        -- Adjacency is read at the moment the blow lands, not at the start of the turn, so a shove that
        -- moved someone out of the rank a beat earlier correctly stops paying them. Counted once per
        -- neighbour per blow -- it is "a blow fell beside me", not a share of the damage -- which keeps
        -- it commensurate with hitTaken and lets one pool draw on both.
        for _, u in ipairs(combat.units) do
            if u.alive and u ~= target and u.side == target.side
                and math.max(math.abs(u.x - target.x), math.abs(u.y - target.y)) == 1 then
                Combat.tally(u, "allyStruck", 1)
            end
        end
        -- The SAME-TARGET streak. En Garde has kept its own copy of this since it shipped
        -- (u.enGardeTarget / u.enGardeStacks, bumped inside one ability's effect); this is the general
        -- form, updated by every damaging blow however it was thrown, so a charge pool can read
        -- "I have not looked away from this one" without an ability having to be the thing that
        -- noticed. "repeatStrike" banks on the second consecutive blow and every one after it.
        --
        -- Self-damage is not a streak (a bomb under your own feet is not persistence), and a switch
        -- forfeits any pool that declared resetOn = "targetSwitch" -- which is the Duelist's whole
        -- bargain: the tempo is only yours while the duel is.
        if user ~= target then
            if user.streakTarget == target then
                user.streakCount = (user.streakCount or 1) + 1
                Combat.tally(user, "repeatStrike", 1)
            else
                if user.streakTarget then Combat.resetChargesOn(user, "targetSwitch") end
                user.streakTarget, user.streakCount = target, 1
            end
        end
    end
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
    -- Mirror dealDamage exactly, charm bonus included, or the hover would under-promise the real hit.
    local charmBonus = Trait.outgoingDamageBonus(combat, user, target, item, tags)
    local base = (opts.amount or (ab and ab.damage) or 0) + flatStat(user, atkStat) + unarmedDamageBonus(user, item) + charmBonus
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

-- Is a heal aimed at `target` turned back on it -- does it WOUND instead of heal? Returns the thing
-- doing the turning (a status instance or a trait), or nil, so a caller can name it in the log.
--
-- Two sources, one question, because there are two shapes of "this body does not take healing" and the
-- funnel must not learn them separately:
--
--   * a STATUS the body was cursed with (Interred, data/status/status_interred.lua) -- a window somebody
--     spent a turn opening, cleansable like any debuff;
--   * a TRAIT the body simply IS (Grave-Cold, worn by every undead thing on data/items/utility/
--     utility_grave_cold.lua) -- a standing fact about a corpse, not a condition it caught. A permanent
--     status would be the wrong instrument for it (see models/trait.lua's header on why), and a corpse
--     that could be CLEANSED back into taking healing would be nonsense besides.
--
-- Asked by Combat.applyHeal below and by the dry run in Combat.abilityOutput, so the number the hover
-- promises is the number the cast delivers: a heal aimed at an interred body previews in red.
function Combat.healingInverted(target)
    return Status.invertsHealing(target) or Trait.flag(target, "invertsHealing")
end

-- Restore health to `target`, capped at its ceiling (its max less any reserved health -- reserved
-- life can't be healed back into). Returns the amount actually healed. Reached through `fx.heal`
-- inside an ability effect.
function Combat.applyHeal(combat, target, amount)
    -- An UNCLOSING WOUND refuses the heal outright. Sat at the top of the one funnel every heal in the
    -- game runs through -- a spell, a potion, a Regeneration tick, a lifesteal drink, a Sanctified
    -- Presence -- so nothing has to learn the rule twice and nothing can route around it.
    local blocked = Status.blocksHealing(target)
    if blocked and (amount or 0) > 0 then
        Combat.logEvent(combat, "status",
            string.format("%s cannot be healed: %s.", unitName(target), blocked.name or blocked.id), target)
        return 0
    end
    -- INTERRED, or simply dead: the heal curdles and lands as a wound of the same size. Checked after
    -- the block above, so a body under both is refused rather than burned -- a heal that was never going
    -- to land cannot be turned around.
    --
    -- The wound is a TOLL (tollHealth): unmitigated, attacker-less, and answered by nothing. That is not
    -- a shortcut. Grace poured into a corpse is a consequence, not an exchange -- there is nobody in the
    -- room to parry, riposte or reflect, and charging the priest's own healing to the target's armor
    -- would make plate a defense against being healed. It can fell, and is meant to.
    local inverted = Combat.healingInverted(target)
    if inverted and (amount or 0) > 0 then
        local held = Status.deferralOn(target)
        if held then
            -- A Sealed Hour holds this too, and holds it as what it BECAME: positive on the ledger,
            -- since what is owed is now damage. Curdling it into healing owed would let the hour launder
            -- an interred body's heals back into a rescue.
            Status.defer(held, amount)
            Combat.logEvent(combat, "status",
                string.format("%s's healing curdles, and is held for later (%d).", unitName(target), amount), target)
            return 0
        end
        tollHealth(combat, target, amount,
            string.format("%s cannot be healed -- the grace burns it for %d (%s).",
                unitName(target), amount, inverted.name or inverted.id), target)
        return 0
    end
    -- A DEFERRAL banks the heal instead of landing it (the Sealed Hour). Negative on the ledger, since
    -- the ledger is denominated in damage -- and this is the whole reason a deferral is a bargain
    -- rather than a pure ward: healing banked under it does not save anyone in the meantime either.
    local deferral = Status.deferralOn(target)
    if deferral and (amount or 0) > 0 then
        Status.defer(deferral, -(amount or 0))
        Combat.logEvent(combat, "heal",
            string.format("%s's healing is held for later (%d).", unitName(target), amount or 0), target)
        return amount or 0
    end
    local hp = target.char.stats.health
    local before = hp.current
    hp.current = math.min(Combat.unreservedMax(target.char, "health"), hp.current + (amount or 0))
    local healed = math.max(0, hp.current - before)
    if healed > 0 then
        Combat.logEvent(combat, "heal", string.format("%s is healed for %d.", unitName(target), healed), target)
        Combat.pushFx(combat, { type = "heal", unit = target, amount = healed })
    end
    -- Every unit on the patient's side banks an `allyHealed`. The counterpart to `healDone`, which is
    -- credited to the CASTER: this is "the line was tended", which is what a pool belonging to a cause
    -- rather than to a healer fills on (the Crusader's Zeal). Fired here, in the one funnel every heal
    -- in the game runs through, so a potion, a regeneration tick and a lifesteal drink all count.
    if healed > 0 and target then
        for _, u in ipairs(combat.units) do
            if u.alive and u.side == target.side then Combat.tally(u, "allyHealed", 1) end
        end
    end
    return healed
end

-- S5: strip up to `n` BLESSINGS from one body (nil = all of them), returning the ids taken.
--
-- The mirror of Combat.cleanse, which takes the afflictions off a friend: this takes the advantages off
-- an enemy. Between them they are the whole of "make that body plain", and the game had only the kind
-- half until now -- which is why the Confessor's Needle shipped with its dispel clause missing and a
-- header admitting it.
--
-- Gathered before any of it is removed, because walking a status list while removing from it is how you
-- take half of what you meant to. Returns the ids rather than a count so a caller can scale off WHAT it
-- took as well as how much.
-- WHICH blessings a dispel would take off `unit`, up to `n` of them, as a list of status ids. Reads
-- nothing and removes nothing.
--
-- Extracted so the DRY RUNS can answer this question honestly. fx.dispelUnit returns the ids it took and
-- effects read that return -- ability_sentence scales off the count, the Wand of the Borrowed Word wears
-- what it takes -- so a preview stub answering `{}` would report those abilities as doing nothing. The
-- filter lives here once rather than being restated in each fx table, because a second copy of "what
-- counts as a blessing" is a second thing to drift.
function Combat.dispellableOn(unit, n)
    if not (unit and unit.alive) then return {} end
    local out = {}
    for _, st in ipairs(unit.statuses or {}) do
        local def = Status.defs[st.id]
        -- A blessing is a status that is not a debuff and not one of the engine's own bookkeeping
        -- markers (`hideLog` covers Channeling, which is a pending spell rather than a boon -- stripping
        -- it here would make this a silent counterspell, which is exactly the power S5 gave up).
        if def and not def.debuff and not def.hideLog then
            out[#out + 1] = st.id
            if n and #out >= n then break end
        end
    end
    return out
end

function Combat.dispelUnit(combat, unit, n)
    if not (unit and unit.alive) then return {} end
    local taken = Combat.dispellableOn(unit, n)
    for _, id in ipairs(taken) do Status.remove(combat, unit, id) end
    if #taken > 0 then
        Combat.logEvent(combat, "status",
            string.format("%s is stripped of %d blessing%s.", unitName(unit), #taken,
                #taken == 1 and "" or "s"), unit)
    end
    return taken
end

-- Strip every debuff from `unit` and log it (Cure). Delegates the removal to Status.cleanse -- the
-- single rule for what counts as a debuff -- and adds the log line the spell wants. Returns the count.
function Combat.cleanse(combat, unit)
    local n = Status.cleanse(combat, unit)
    if n > 0 then
        Combat.logEvent(combat, "status",
            string.format("%s is cleansed of %d debuff%s.", unitName(unit), n, n == 1 and "" or "s"), unit)
    end
    return n
end

-- ---------------------------------------------------------------------------
-- Corpses (reanimation / raising)
--
-- A "real" unit that dies stays in combat.units, lying on its last tile, in one of two states:
--   * INCAPACITATED (`incapacitated`) -- a revivable body still inside its window. It can be brought
--     back as the same character (Combat.reanimate: Revive, the scroll, Reviving Salts), but it is NOT
--     a corpse yet, so the necromancer's shelf cannot read it.
--   * CORPSE (`corpse`) -- a harvestable body: a non-revivable unit (a demon) from the moment it falls,
--     or a revivable one AFTER its window ran out (status_downed onExpire flipped it). Past reviving,
--     but now raisable / consumable / readable:
--       * Combat.raiseZombie -- Raise Dead: the body is consumed and a fresh zombie takes its place.
--       * Combat.consumeCorpse -- Corpse Burst / the Ledger's Due: the body is spent outright.
-- Neither is alive -- unitAt / turnOrder / aliveCount all ignore both, so a living unit may walk over
-- either and the objectives resolve as normal. Reanimating / raising / consuming clears the flag, so a
-- given body can only be used once.
-- ---------------------------------------------------------------------------

-- The corpse on (x, y), or nil -- a HARVESTABLE body, what the necromancer's shelf reads (Raise Dead,
-- Corpse Burst, the Ledger's Due). An incapacitated body is deliberately NOT one (see Combat.downedAt).
-- A tile with a LIVING unit on it has no reachable corpse (you can't work on a body someone is standing
-- on) -- the "as long as no one is on top of the tile" rule these effects share.
function Combat.corpseAt(combat, x, y)
    if Combat.unitAt(combat, x, y) then return nil end
    for _, u in ipairs(combat.units) do
        if u.corpse and not u.alive and u.x == x and u.y == y then return u end
    end
    return nil
end

-- The incapacitated body on (x, y), or nil -- what Revive and its kin work on (Combat.reanimate). The
-- mirror of Combat.corpseAt for the OTHER fallen state: the revive window is open here, the body is not
-- yet a corpse, and the same occupied-tile rule holds (you cannot reach a body under a living unit).
function Combat.downedAt(combat, x, y)
    if Combat.unitAt(combat, x, y) then return nil end
    for _, u in ipairs(combat.units) do
        if u.incapacitated and not u.alive and u.x == x and u.y == y then return u end
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
    -- Only an INCAPACITATED body comes back -- one still inside its revive window. This is the single
    -- gate the Revive spell, the revive scroll, Reviving Salts and a Phoenix Down all honour at once:
    --   * a body whose window has CLOSED is now a corpse (not `incapacitated`) and is refused -- past
    --     reviving for the battle, exactly as its "goes cold" line said;
    --   * a body that never comes back at all (a demon, revivable = false) is a corpse from the start
    --     and was never incapacitated, so it is refused by the same test.
    -- A successful revive wipes the body's statuses below, which is what silently cancels its
    -- status_downed countdown (so onExpire never fires and it never turns to a corpse).
    if not corpse or corpse.alive or not corpse.incapacitated then return false end
    if Combat.unitAt(combat, corpse.x, corpse.y) then return false end
    fraction = fraction or 0.5
    corpse.alive = true
    corpse.incapacitated = false
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

-- Between-battle mercy, spent from the victory seam (states/battle.lua's win): a party member who
-- fell in a fight the company still WON is not lost -- they pick themselves up and walk out to the
-- overworld at a sliver of health (`fraction` of max, default 20%). Only the player's own fallen are
-- eligible: a summon or decoy leaves no body (no `corpse`), and each real fallen roster member is
-- restored on the shared char instance the overworld reads, so the recovery persists past the battle.
-- HP is floored to 20% of the base max (`stats.health.max`), never below 1, since the battle-only
-- ceiling bonuses (unreservedMax's maxBonus) are gone by the time the party is back on the map.
function Combat.reviveFallenParty(combat, fraction)
    fraction = fraction or 0.2
    for _, u in ipairs(combat.units) do
        if u.side == "party" and not u.alive and (u.incapacitated or u.corpse)
            and not u.summoned and not u.decoyOf
            -- Either fallen state is carried out: a member still INCAPACITATED when the fight ended, and
            -- one whose window ran out and TURNED TO A CORPSE alike (the closed in-battle window is a
            -- fight-length penalty, and the company still carries its own out once the fight is won). A
            -- body that never comes back stays down even in victory (a recruited demon would be lost for
            -- good), and one already spent -- consumed or raised -- left no `corpse` to carry.
            and u.char.revivable ~= false then
            local hp = u.char.stats.health
            hp.current = math.max(1, math.floor((hp.max or 0) * fraction))
            u.alive = true
            u.incapacitated = false
            u.corpse = false
            u.statuses = {}
        end
    end
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
-- order = {entries...} } (order is affected-unit order), plus userRestsX/userRestsY when the cast
-- MOVES the caster (a blink, a step-back), or nil for an ability with no effect.
-- The effect is pcall-guarded so a data-file quirk in a dry run can never crash the tooltip.
function Combat.previewAbility(combat, unit, item, tx, ty, dest, windup, spend)
    local ab = item and item.activeAbility
    if not ab then return nil end
    -- A chargeable wind-up (The First Motion) scores its blow off how deep the hold is (`fx.held`, the
    -- ticks past the floor) -- so a preview that leaves it unset under-reports the swing at every depth
    -- but the floor. When the caller names a depth (the wind-up chooser walks it lo..hi to price each
    -- one), fill `held`/`windup` exactly as Combat.useItem's channel branch does; nil keeps the old
    -- behaviour for every non-chargeable cast (held stays 0).
    local windLo = Item.windupRange(ab)
    local previewHeld = windup and math.max(0, math.floor(windup) - windLo) or nil
    local target = Combat.unitAt(combat, tx, ty)
    local entries, order = {}, {}
    -- Would a LIVE cast touch the BOARD, beyond the units this dry run reports? Every inert helper
    -- below flips it: a trap laid, a hazard painted, a wall raised, a body summoned or raised, a
    -- teleport, a theft, a reveal. Nothing about the numbers changes -- it exists so a caller can ask
    -- "would this cast, aimed HERE, do anything at all?" (Combat.castDoesSomething), which is how
    -- states/battle.lua tells a spear's swing at a foe from the same spear aimed at empty ground it
    -- only means to walk onto. Flavour is not an effect: fx.log and fx.burst leave it alone.
    local mutates = false
    local function touchesBoard() mutates = true end
    -- Where the cast would leave the CASTER, when it moves it at all: the tile a blink lands it on
    -- (Shadow Step slips to a square beside its mark before it cuts) or the one a hit-and-run step-back
    -- retreats to. Reported at the TOP level rather than on the caster's entry, deliberately: an entry
    -- would enrol the caster as an affected unit, and a single-target blink would start reading as a
    -- two-body blast (ui/action_preview summarises `order` as an area hit). Last write wins, so an
    -- effect that moves twice reports where it comes to rest.
    local userRestsX, userRestsY
    local function entryFor(tgt)
        local e = entries[tgt]
        if not e then
            e = { unit = tgt, damage = 0, heal = 0, statuses = {} }
            entries[tgt] = e
            order[#order + 1] = e
        end
        return e
    end
    -- Project where a target's turn MOVES when this cast shifts its initiative -- a stun/freeze/sleep
    -- shoving it later. states/battle.lua reads entry.initiativeAfter to float a preview slot of the
    -- target's next turn on the timeline (the same "you would move to here" ghost the actor's own aim
    -- shows). Accumulates, so two shoves in one cast stack; inert to the unit itself (a dry run never
    -- mutates initiative). `initiativeCause` names the driver, for the ghost's label. 0-shove statuses
    -- (a bleed, a barrier) record nothing, so only a genuine delay paints a slot.
    local function shoveInitiative(tgt, id, opts)
        local shove = Status.initiativeShove(tgt, id, opts)
        if shove == 0 then return end
        local e = entryFor(tgt)
        e.initiativeAfter = (e.initiativeAfter or tgt.initiative) + shove
        e.initiativeCause = Status.defs[id] and Status.defs[id].name
    end
    local auraTags, auraStatuses, auraMods = adjacencyAura(unit.char, item)
    withStatusLifesteal(unit, auraMods) -- a status-granted thirst adds to the grid's, in the preview too
    -- Fold in a neighboring Alchemic Mastery charm's magnitude bonus (and any frenzy) exactly as
    -- Combat.useItem does, so the previewed number matches the hit the player is about to land.
    local effectiveAmount = castAmount(combat, unit, ab, tx, ty, auraMods)
    local fx = {
        user = unit, target = target, item = item, combat = combat, tx = tx, ty = ty,
        dest = dest, -- a two-stage throw's chosen landing (Heave); nil for every single-aim ability
        -- The wind-up depth this preview is priced at (nil unless the caller named one): `windup` the
        -- total tell, `held` the ticks chosen above the floor -- the same pair the live cast hands the
        -- effect, so a chargeable blow previews the damage it will actually land at that depth.
        windup = windup, held = previewHeld,
        -- The coin this preview is priced at, or 0. A player hovering an aim names none -- the spend is
        -- dialed in the confirm-time chooser, so the board shows 0 bought until that modal drives the real
        -- cast. The AI, though, passes the gold it INTENDS to pour (models/ai.lua) so its scorer prices the
        -- blow it is about to buy -- otherwise a purchasable ability always looks like it does nothing and
        -- an enemy who could afford a killing blow would never reach for it.
        spend = spend or 0,
        -- Flat, RAW damage (The Gilded Wound: the gold IS the blow). Priced through the same pure mitigation
        -- the live hit uses, RAW so neither the caster's Power adds nor the target's armour subtracts -- ten
        -- gold, one point delivered. Barriers/immunity still void it; nothing else does. Records like
        -- fx.damage and never mutates, so the dry run prices it truthfully.
        flatDamage = function(tgt, amount, tags)
            if not tgt then return 0 end
            local d = Combat.mitigatedDamage(tgt, math.max(0, math.floor(amount or 0)), tags or { "physical" }, { raw = true })
            local e = entryFor(tgt)
            e.damage = e.damage + d
            return d
        end,
        amount = effectiveAmount, -- the ability's scaled magnitude; effects derive heal/status/etc. from it
        -- The item's upgrade level, as the other two fx tables already carry it (Combat.abilityOutput
        -- and the live cast). It belongs on all three for the reason docs/architecture.md gives about
        -- the fx helpers: a dry run that is missing one silently swallows the effect from that point on.
        -- Without it an effect reaching for `fx.level` throws while building its ARGUMENTS
        -- (`{ amount = 4 + fx.level }`), before the inert stand-in it was calling is ever reached.
        --
        -- Nothing visible is broken by its absence TODAY, and it is worth being precise about why: every
        -- current fx.level user (Fireball, Sanctuary, Quicksand, Rain, Spike Trap, the summons) paints
        -- its ground AFTER it deals its damage, so the throw lands past the last line the preview
        -- actually reports and the damage is already recorded. The preview is correct by running order
        -- rather than by construction. This makes it correct by construction -- an effect that scales a
        -- heal or a second strike off fx.level would otherwise lose it, and would do so silently.
        level = item and item.level or 0,
        -- The monk's charge. Read-only, so the dry run answers truthfully; the SPEND below is inert
        -- here, because a preview that emptied the pool under the cursor would be a bug that read as
        -- one. It still reports what the live spend would take, so an effect scaling its damage off
        -- the returned figure previews the blow it is actually going to land.
        chi = Combat.chi(unit),
        spendChi = function(n)
            local have = Combat.chi(unit)
            return n and math.max(0, math.min(n, have)) or have
        end,
        -- The purse this cast could draw on, read truthfully off the live board so the previewed damage
        -- of a coin-scaled blow matches what it will land -- and an INERT spend that only reports what it
        -- would take, because a preview that emptied the purse under the cursor would be a bug that read
        -- as one (mirrors spendChi just above).
        purse = Combat.purseAvailable(combat, unit),
        spendPurse = function(n)
            local have = Combat.purseAvailable(combat, unit)
            return n and math.max(0, math.min(n, have)) or have
        end,
        unitAt = function(x, y) return Combat.unitAt(combat, x, y) end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
        -- A free tile beside (x, y) to set something down on, or nil when the spot is hemmed in.
        -- Read-only, so the dry run may answer it truthfully.
        openTileNear = function(x, y) return Combat.openTileNear(combat, x, y) end,
        -- Narrowed by a Careful Sigil exactly as the live cast is (Combat.castUnits), so the preview
        -- shows the allies it will spare rather than promising damage the swing then declines to deal.
        aoeUnits = function() return Combat.castUnits(combat, ab, tx, ty, unit, auraMods) end,
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
            -- A blow that folds a shove in (opts.knockback -- the Iron Mace, the Sworn Aegis) never
            -- passes through fx.knockback, so record where it would leave the target here, exactly as
            -- the knockback helper below does. A counter is gated on reach, and the answer is thrown
            -- from where the shove ends -- without this the panel promises a parry the mace shoves out of.
            if opts.knockback and tgt then
                e.restsX, e.restsY = Combat.knockbackTile(combat, unit, tgt, opts.knockback.distance or 1)
            end
            -- A status the blow CARRIES (a hammer's stun) never passes through fx.applyStatus, so
            -- record it here or the tooltip would show the damage and silently drop the stun.
            for _, c in ipairs(carriedStatuses(opts)) do
                local cdef = Status.defs[c.id]
                e.statuses[#e.statuses + 1] = { id = c.id, def = cdef, opts = c.opts }
                -- ...and flag the one thing the COUNTER preview needs to know about it: a carried
                -- status that shuts down reflexes means the on-hit answers won't fire, because it
                -- lands before them (Combat.dealFlatDamage). Recorded from the hit itself rather than
                -- sniffed out of e.statuses afterwards -- a stun applied the ordinary way, on the line
                -- AFTER the damage, does NOT suppress anything, and the two must not be confused.
                if cdef and cdef.disablesReactions then e.suppressesCounters = true end
                -- A carried stun/freeze shoves the target down the order the moment the blow lands, so
                -- project its delayed turn onto the timeline (Jolt, Ice Bolt inflict this way).
                shoveInitiative(tgt, c.id, c.opts)
            end
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
            -- A heal aimed at an INTERRED body (or at anything grave-cold) lands as a wound instead, so
            -- the preview has to show it as one -- a green number over a zombie the party is about to
            -- burn down is the preview lying about the one thing the player needed to know. The toll is
            -- unmitigated, so the previewed figure is the whole amount, exactly as it lands.
            if Combat.healingInverted(tgt) and (amount or 0) > 0 then
                -- Left to the sweep at the foot of abilityOutput to flag as lethal, like any other
                -- damage total: it is the entry's WHOLE damage that decides, not this one contribution.
                entryFor(tgt).damage = entryFor(tgt).damage + amount
                return 0
            end
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
            -- A directly-applied stun/freeze/sleep shoves the target's turn later; project it onto the
            -- timeline (Thunder Storm, Blizzard, and Sleep apply through this path rather than a hit).
            shoveInitiative(tgt, id, opts)
            return nil
        end,
        -- Banking a battle-scoped fact on the caster is a mutation: inert here, so replaying the effect
        -- on every hover frame neither advances the count nor flips the branch it takes (Turning Year's
        -- fire/frost, the Unspent Blow's tally). Reads stay a plain `fx.user.<field>` and are truthful,
        -- since `fx.user` is the real unit -- the preview simply shows the branch THIS cast would run.
        bank = function() touchesBoard() end,
        -- ...and banking on the ITEM is the same mutation aimed at the relic instead of the bearer.
        -- Inert for the sharper reason: `fx.item` here IS the player's real item, so a live write would
        -- empty a banked purse every time the aim cursor crossed a tile.
        bankItem = function() touchesBoard() end,
        -- Read-only, so the dry run may answer truthfully; the mutating ones are inert.
        hasStatus = function(tgt, id) return tgt ~= nil and Status.has(tgt, id) end,
        clearStatus = function() touchesBoard() end,
        -- Answers truthfully and finishes nothing. The read has to be honest -- an effect that branches
        -- on it (Second Utterance: finish the working in front of you, or promise the next one) would
        -- otherwise preview the wrong half of itself over a channeling ally -- but the dry run must not
        -- actually resolve anybody's Meteor Storm under the aim cursor, which is the loudest preview
        -- side effect there is. Flips `mutates` only when there IS a wind-up to finish, so aiming this
        -- at a body holding none still reads as a cast that does something (the status it grants).
        hastenChannel = function(tgt)
            if not (tgt and tgt.alive and tgt.channel) then return false end
            touchesBoard()
            return true
        end,
        swap = function() touchesBoard() return false end,
        -- Report what the drain WOULD take (against the pool it is aimed at) without taking it: the
        -- number is the whole cast for an effect that hands it straight back out -- Transfusion heals
        -- the ally for exactly what it draws from the caster, so a drain that reported 0 previewed a
        -- cast that did nothing, on the board and in the AI's scorer alike. Still counts as touching
        -- the board: emptying a foe's mana is a real effect even when no entry records it.
        drain = function(tgt, stat, amount)
            touchesBoard()
            if not tgt then return 0 end
            return Combat.drainableAmount(tgt.char, stat, amount)
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
        placeTrap = function() touchesBoard() return nil end,
        placeHazard = function() touchesBoard() return nil end,
        placeWall = function() touchesBoard() return nil end,
        -- Burying a charge and setting one off are board mutations, so both are inert here -- a dry run
        -- that planted a real fuse (and logged it) on every hover was the Saboteur's whole preview bug.
        -- plantCharge hands back a throwaway so a chained effect using the returned charge doesn't fault;
        -- detonate reports nobody hit, since a preview must never deal the blast it is only describing.
        plantCharge = function() touchesBoard() return {} end,
        detonate = function() touchesBoard() return 0 end,
        -- A dry run must not take the caster off the board -- and it must not PRICE it either. The
        -- panel shows what a self-destruct does to everyone standing around it; the bomber's own
        -- departure is the ability, not a casualty of it, and neither the hover nor the AI's outcome
        -- score has a row for it. See the live helper in resolveCast for why it is a dismissal.
        expendSelf = function() touchesBoard() return false end,
        -- A dry run must not queue a cue the board would draw: the explosion is a picture of the cast,
        -- not part of what it DOES, so the hover panel has no row for it and it stays silent here --
        -- and, being a picture, it does not count as touching the board either.
        burst = function() end,
        dispel = function() touchesBoard() return { revealed = 0, wallsDestroyed = 0 } end,
        -- Strips nothing, but REPORTS what it would strip, because effects read the return: without this
        -- entry the helper was absent from this table altogether, so ability_sentence and
        -- ability_the_question faulted while building their arguments and previewed as nothing at all.
        dispelUnit = function(tgt, n) touchesBoard() return Combat.dispellableOn(tgt, n) end,
        summon = function() touchesBoard() return previewStandIn() end,
        copy = function() touchesBoard() return previewStandIn() end,
        copyOf = function() touchesBoard() return previewStandIn() end,
        -- Inert like the rest, but it records WHERE the shove would leave its target, because that is
        -- the tile the target's own answer would be thrown from -- and a counter is gated on reach.
        -- Without this the hover promises a parry the mace then shoves out of range of (see
        -- Combat.previewCounters); with it, the panel and the live exchange agree.
        knockback = function(tgt, distance, opts)
            if tgt then
                local e = entryFor(tgt)
                -- `opts` carries a thrown body's dest (Heave phase 2) so the ghost rests where the
                -- live throw will; a plain shove passes none and keeps away-from-caster.
                e.restsX, e.restsY = Combat.knockbackTile(combat, unit, tgt, distance or 1, opts)
            end
            return 0, false
        end,
        -- The mirror of the above for a step-BACK: it records where the shove would leave the CASTER,
        -- for the same reason and with the same consequence reversed. A hit-and-run blow is thrown, then
        -- its striker walks out of reach -- so the panel must not promise a counter that the retreat has
        -- already stepped clear of.
        retreat = function(tgt, distance)
            if tgt then
                local e = entryFor(unit)
                e.restsX, e.restsY = Combat.knockbackTile(combat, tgt, unit, distance or 1)
                userRestsX, userRestsY = e.restsX, e.restsY
            end
            return 0
        end,
        pull = function() touchesBoard() return false end,
        -- The object layer answers where a throw/drag GRABS from (read-only, truthful) but moves
        -- nothing: a shoved prop deals no damage to a unit, so there is no row for it to record. Present
        -- so a Push/Heave/Pull effect that reads the tile's furniture completes rather than faulting
        -- mid-build (the reason the whole table exists -- see Combat.abilityOutput's tail).
        objectAt = function(px, py) return Combat.throwableAt(combat, px, py, unit.side) end,
        hurl = function() touchesBoard() return 0, false end,
        pullObject = function() touchesBoard() return false end,
        -- Inert to the board like the rest -- but a blink is the one mutation whose subject is the
        -- CASTER, and "where does this leave me" is half of what the cast is being weighed on. Record
        -- the landing (see userRestsX above): states/battle.lua marks that tile, and the counter
        -- preview weighs the blow from it, since a Shadow Step thrown from four tiles out is actually
        -- thrown from the square beside its mark and is answered from there.
        teleportUser = function(x, y)
            touchesBoard()
            if x and y then userRestsX, userRestsY = x, y end
            return false
        end,
        teleport = function() touchesBoard() return false end,
        -- A charge carries the CHARGER down the lane, so -- like a blink -- it is inert to the board but
        -- not silent about where it leaves you: record the landing (see userRestsX above), because for a
        -- rush that is most of what the cast is being weighed on. Combat.chargeTile walks it purely.
        charge = function(tgt, distance)
            touchesBoard()
            if tgt then userRestsX, userRestsY = Combat.chargeTile(combat, unit, tgt.x, tgt.y, distance) end
            return 0
        end,
        chargeInto = function(x, y, distance)
            touchesBoard()
            if x and y then userRestsX, userRestsY = Combat.chargeTile(combat, unit, x, y, distance) end
            return 0
        end,
        steal = function() touchesBoard() return nil end,
        -- Knowledge only, so there is nothing to preview on the timeline -- but pulling a hidden trap
        -- into the light IS something the cast does, so it counts as touching the board.
        reveal = function() touchesBoard() end,
        -- Inert to the unit, but records where the pull would land its turn: a hasten cuts the target's
        -- current initiative, so its next turn slides EARLIER on the strip (Haste on an ally). No cause
        -- name -- the ghost reads "rushed forward" rather than a status.
        hasten = function(tgt, fraction)
            if not tgt then return 0 end
            local e = entryFor(tgt)
            e.initiativeAfter = (e.initiativeAfter or tgt.initiative) * (1 - (fraction or 0.5))
            return e.initiativeAfter
        end,
        -- Board-mutating helpers are inert in a dry run; the read-only ones may answer truthfully.
        random = function() return 1 end,
        cleanse = function() touchesBoard() return 0 end,
        corpseAt = function(x, y) return Combat.corpseAt(combat, x, y) end,
        downedAt = function(x, y) return Combat.downedAt(combat, x, y) end,
        corpsesIn = function(cells)
            return Combat.corpsesIn(combat, cells or Combat.aoeCells(combat, ab, tx, ty, unit))
        end,
        reanimate = function() touchesBoard() return false end,
        raise = function() touchesBoard() return previewStandIn() end,
        -- Dual Wield's preview: a sub-strike shows the weapon's post-mitigation damage on the target,
        -- so the tooltip totals the swings. setSpeed is inert here (the timeline isn't previewed).
        strikeWith = function(weapon)
            local wab = weapon and weapon.activeAbility
            if not (wab and target) then return { damageDealt = 0 } end
            local d = Combat.computeDamage(combat, unit, target, weapon, { amount = Combat.abilityMagnitude(wab) })
            entryFor(target).damage = entryFor(target).damage + d
            return { damageDealt = d }
        end,
        setSpeed = function() touchesBoard() end,
        -- Takes (n, target) like its live twin -- an effect that aims one at an ally must take the same
        -- path here, or the preview branches differently from the cast.
        grantExtraAction = function() touchesBoard() return 0 end,
        log = function() end, -- flavour, not an effect: never counts as touching the board
        -- Board-mutating, so inert here -- but each still answers with the SHAPE its live twin does, or
        -- an effect that goes on to branch on the result would take a different path in the preview
        -- than it takes in the cast (see the note on fx.level above: a dry run missing a helper
        -- swallows the effect from that point on, silently).
        clearCooldowns = function() touchesBoard() return 0 end,
        recall = function() touchesBoard() return false end,
        bounty = function() touchesBoard() return 0 end,
        consumeCorpse = function() touchesBoard() return false end,
    }
    if ab.effect then pcall(ab.effect, fx) end
    -- A damage total >= the target's current HP would drop it: flag the lethal blow.
    for _, e in ipairs(order) do
        local hp = e.unit.char and e.unit.char.stats and e.unit.char.stats.health
        e.lethal = e.damage > 0 and hp ~= nil and e.damage >= (hp.current or 0)
    end
    return { entries = entries, order = order, mutates = mutates,
             userRestsX = userRestsX, userRestsY = userRestsY }
end

-- Pure: would this cast, aimed at (tx, ty), DO anything WORTH SWINGING AT -- land on a body the cast
-- is for, or touch the board at all?
-- False is the swing into empty air: a cleaving axe or a spear's line aimed at open ground that its
-- footprint catches nobody in, a bomb thrown where it will hurt no one. True the moment the dry run
-- records an affected unit, or reaches for a helper that would place / summon / teleport / steal /
-- reveal (see `mutates` in previewAbility).
--
-- Your own line is not a target. An OFFENSIVE footprint that catches nobody but friends is the same
-- empty swing as one that catches nobody at all: nobody arcs an axe through their own knight on
-- purpose, so the aim was a walk. Without this the ally read as a connection and the step vanished --
-- exactly where a company is tightest, shoulder to shoulder in a corridor, and exactly where the
-- player needs to shuffle. The cursor ring already knew (targetCells in states/battle.lua only ever
-- offers a facing that sweeps a unit of the TARGET side); it was the mouse's tie-break that didn't.
-- The caster itself still counts, so an ability whose work lands on the wielder -- a self-applied
-- stance thrown off a tile aim -- is not demoted to a step. Friendly fire is untouched: the swing
-- still hurts whoever is standing in it once it is thrown (rule 3, with the move spent, throws it).
--
-- This is what lets states/battle.lua resolve a click on a tile-aimed weapon. Those weapons -- every
-- spear, axe and greatsword, whose aimed tile is a FACING rather than a victim -- make EVERY tile in
-- reach a legal aim, so the move band is a subset of the cast band and no tile is left to mean "walk
-- here". Reading what the cast would actually do gives the tile back: a swing that connects with
-- nothing is a step. Ground-laying abilities (a bear trap, a summon, Writ of Fire) classify
-- themselves, since placing IS doing something -- no per-item declaration needed.
--
-- An ability with no `effect` at all counts as doing nothing.
function Combat.castDoesSomething(combat, unit, item, tx, ty)
    local ab = item and item.activeAbility
    if not (ab and ab.effect) then return false end
    local preview = Combat.previewAbility(combat, unit, item, tx, ty)
    if not preview then return false end
    if preview.mutates == true then return true end
    -- A support cast is aimed at friends by definition, so it counts every body it reaches.
    local sparesFriends = unit ~= nil and not Combat.isSupportAbility(ab)
    for _, e in ipairs(preview.order) do
        if not (sparesFriends and e.unit ~= unit and e.unit.side == unit.side) then return true end
    end
    return false
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
    local ab = item.activeAbility
    local list = Trait.counterPreview(combat, target, unit, {
        tags = collectTags(item, {}),
        damage = entry and entry.damage or 0,
        lethal = entry and entry.lethal,
        -- An area cast is answered by nothing, exactly as in Combat.dealDamage -- the preview reads the
        -- blast off the same `aoe` footprint the live hit does, so the panel can't promise a parry the
        -- bomb will never provoke.
        area = ab ~= nil and not Combat.isSingleTarget(ab),
        -- A blow that CARRIES hard control (the War Hammer's stun) lands it before the on-hit hooks
        -- are consulted, so the target is too rattled to answer -- previewAbility flags that on the
        -- entry when it replays the effect. Passing it on is what keeps this panel honest: without it
        -- the hover would warn of a parry that the hammer then never provokes.
        suppressed = entry and entry.suppressesCounters,
        fromX = opts.fromX, fromY = opts.fromY,
        -- Where the blow LEAVES its target, when it also shoves one (the mace, Water Ball). An answer
        -- waits for the action to finish (Combat.beginAnswers), so it is thrown from the tile the shove
        -- left the target on -- and a brawler shoved out of melee has nothing left to answer with.
        toX = entry and entry.restsX, toY = entry and entry.restsY,
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
        -- Sit at the origin (0, 0) -- the same cell the caster stand-in and the aim (fx.tx/ty) default to.
        -- An effect that applies its status only to a SPECIFIC computed tile (a spear that Disarms/Halts
        -- the FAR tile: farX = fx.tx + (fx.tx - fx.user.x) resolves to 0 here) then finds the dummy there
        -- and records the status, so the inventory tooltip's glossary names it. Without a position the
        -- check is `nil == 0`, and the signature status silently drops out of the tooltip.
        x = 0, y = 0,
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
    -- Hand the effect a SHALLOW COPY of the caster as fx.user, not the caster itself. Most effects only
    -- mutate the board through the inert helpers below, but a few BANK state directly on the unit --
    -- weapon_unspent_blow's `fx.user.unspentBlows`, weapon_marching_standard's `fx.user.standard`. That
    -- write is not inert: replayed once per hover frame it would advance the bank AND flip the branch the
    -- effect takes, so the tooltip flickers between the ordinary hit and its banked payoff (and the real
    -- count drifts just from hovering). The copy carries the current values, so a read still reports what
    -- THIS swing would do, while the write lands on a table we throw away. Safe here because aoeUnits /
    -- unitsNear below return only dummies, so no `u == fx.user` identity check can be fooled by the copy.
    local userProxy = {}
    for k, v in pairs(unit) do userProxy[k] = v end
    -- Pin the caster stand-in to the origin (0, 0), the cell the aim (fx.tx/ty) and the dummy also sit
    -- on. This dry run has no board, so the caster's REAL battle coordinates are meaningless here -- but
    -- an effect that afflicts a computed tile relative to the caster (a spear Disarming/Halting the FAR
    -- rank: fx.tx + (fx.tx - fx.user.x)) needs the caster at a known origin for that tile to resolve
    -- onto the dummy. Left at the actor's real x/y, the far tile lands off in space and the signature
    -- status silently drops out of the tooltip -- and worse, only in battle (a null-actor shop hover
    -- already stands the caster at 0, 0), so it looks fixed until a real unit hovers it.
    userProxy.x, userProxy.y = 0, 0
    -- A support cast aims at allies and gates its effect on `u.side == fx.user.side` (Blessing, Aegis,
    -- Benediction), so a stand-in fixed to the enemy side would fall through every one of those branches
    -- and the tooltip would name none of the statuses/heals the ability grants. Put the stand-in on the
    -- caster's side for a support ability, so its friendly branch actually runs. Offensive casts (Holy
    -- Light and the rest, gated the other way) keep the enemy-side dummy and their damage numbers.
    -- ...but `support` says how the cast READS (green, not red), not who it is aimed AT, and treating
    -- the two as the same thing silently blanked a whole class of tooltip. Stand Down is `support`
    -- because a refusal is not a blow, and it is pointed squarely at an enemy: with the stand-in flipped
    -- friendly, its own `fx.target.side == fx.user.side` guard returned on the first line and the
    -- Bastion's commission described itself as doing nothing at all.
    --
    -- So the AIM decides. An `enemy`/`unit` cast keeps the enemy stand-in whatever colour it reads; a
    -- support cast at anything else (an ally, a tile, the caster) gets the friendly one, which is what
    -- Blessing, Aegis and Sanctuary need to run their `u.side == fx.user.side` branch at all.
    local aimsAtFoe = ab.target == "enemy" or ab.target == "unit"
    if (ab.support and not aimsAtFoe) or ab.target == "ally" or ab.target == "self" then
        dummy.side = unit.side
    end
    local out = { damage = 0, heal = 0, statuses = {}, multi = ab.aoe ~= nil }

    -- A STAND-IN BOARD, for the thirteen effects that scan one. `fx.combat` used to be a flat nil
    -- here, and an effect that walks the roster (The Pyre burning every Marked foe, Benediction
    -- healing every ally, the Conductor arcing to everyone Wet) indexed it and threw -- inside the
    -- pcall, so the tooltip simply went blank and the ability described itself as doing nothing.
    --
    -- Two bodies, one a side, for the same reason aoeUnits hands back a single dummy: a roster scan
    -- should find SOMEBODY so the effect runs and reports, and exactly one somebody so a sweep cannot
    -- inflate its own damage. `turn` is present and empty -- a preview has no turn in progress, and an
    -- effect reading turn.startX (weapon_talons returning to its perch) must read nil, not fault.
    local mate = previewStandIn()
    mate.side = unit.side
    local board = { units = { dummy, mate }, turn = {} }

    local fx = {
        user = userProxy, target = dummy, item = item, combat = board, tx = 0, ty = 0,
        -- A channel's depth. Both are numbers in the live table and in Combat.previewAbility; absent
        -- here, `(fx.windup or 0)` was fine but `fx.held * n` was not, and a chargeable ability faulted.
        windup = 0, held = 0,
        amount = Combat.abilityMagnitude(ab),
        level = item and item.level or 0, -- so a summon/hazard/trap effect can quote its level-scaled output
        -- The charge this bearer holds, and an inert spend that only reports (see the note on the
        -- preview context above). There is no board here, so a stand-in unit simply holds none.
        chi = Combat.chi(unit),
        spendChi = function(n)
            local have = Combat.chi(unit)
            return n and math.max(0, math.min(n, have)) or have
        end,
        -- No board here (this is the shop/inventory tooltip, combat = nil), so there is no purse to read:
        -- a coin-scaled ability quotes its floor. The field must still EXIST and the spend must still
        -- return a number, or an effect building `{ amount = base + fx.spendPurse(n) }` throws while
        -- assembling its arguments -- the same trap fx.level and fx.chi are on all three tables to avoid.
        purse = 0,
        spendPurse = function(_) return 0 end,
        spend = 0, -- no coin chosen in a shop/inventory tooltip; a purchasable ability quotes its floor (nothing bought)
        -- Flat, un-statted damage, priced against the stand-in so a purchasable blow's tooltip can size it
        -- (0 here, since no coin is chosen in a shop hover). Mirrors the live fx.flatDamage.
        flatDamage = function(tgt, amount, tags)
            local d = Combat.mitigatedDamage(tgt or dummy, math.max(0, math.floor(amount or 0)), tags or { "physical" }, { raw = true })
            out.damage = out.damage + d
            return d
        end,
        -- The dummy sits at the origin (0, 0). An effect that looks up a SPECIFIC computed tile to
        -- afflict it -- a spear pinning the FAR rank via fx.unitAt(fx.tx + dx, fx.ty + dy), which
        -- resolves to (0, 0) against a zero-origin caster and aim -- then finds the stand-in there and
        -- records the status, so the tooltip's glossary names it. Any other cell is empty, as before.
        unitAt = function(x, y) if x == 0 and y == 0 then return dummy end return nil end,
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
            -- A carried status (see Combat.dealFlatDamage) bypasses fx.applyStatus, so the inventory
            -- tooltip has to read it off the hit itself to keep naming it.
            for _, c in ipairs(carriedStatuses(opts)) do
                out.statuses[#out.statuses + 1] = { id = c.id, def = Status.defs[c.id], opts = c.opts }
            end
            -- A folded shove (opts.knockback) never reaches fx.knockback either, so record its distance
            -- here or the tooltip drops "drives the target back" for the mace and the aegis.
            if opts and opts.knockback then out.knockback = opts.knockback.distance or 1 end
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
        -- A shelf hover has no board and its stand-in holds no wind-up, so there is never a channel to
        -- finish here: an effect that branches on it describes the other half, which is the right half
        -- for an item's own tooltip (the promise it makes to a body that is not already casting).
        hastenChannel = function() return false end,
        -- Reports the trade it would make. Answering false made every effect that swaps and then acts
        -- on the result (Safeguard taking an ally's place) bail on the line after.
        swap = function() out.swap = true; return true end,
        -- Hands back the full amount rather than what a real pool holds, exactly as `restore` below
        -- does and for the same reason: this run describes the ITEM, not a cast by a particular body
        -- (the caster here is often a 1 HP stand-in on a shop hover). A lending effect can then quote
        -- the heal it moves, instead of showing nothing because its stand-in had no blood to give.
        drain = function(_, _, amount)
            local n = math.max(0, amount or 0)
            out.drain = (out.drain or 0) + n
            return n
        end,
        -- Refilling a pool is an effect, and it was the only one here that computed its answer without
        -- recording it -- so a stamina or mana potion, whose entire text is the refill, reported an
        -- empty row and read as an item that does nothing.
        restore = function(_, _, amount)
            local n = amount or 0
            out.restore = (out.restore or 0) + n
            return n
        end,
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
        placeWall = function(_, _, id) out.wall = id or true; return nil end,
        -- No board and no clock here, so a fuse can neither be laid nor set off; both report nothing,
        -- like the other placers. plantCharge hands back a stand-in so a chained effect doesn't fault.
        plantCharge = function() return {} end,
        detonate = function() return 0 end,
        -- There is no board to leave here, and the row quotes what the ability DOES rather than what
        -- it costs the thing using it (the same reason `retreat` reports nothing).
        expendSelf = function() return false end,
        -- Cosmetic only, and there is no board to paint on: a preview of what an ability DOES has no row
        -- for the explosion it draws, so this reports and changes nothing.
        burst = function() end,
        dispel = function() return { revealed = 0, wallsDestroyed = 0 } end,
        -- Same reasoning as the preview table's copy. There is no board here (this is the shop/inventory
        -- tooltip), so the stand-in dummy carries no blessings and this answers an honest empty list --
        -- but it must EXIST, or an effect reaching for it faults before the tooltip renders a word.
        dispelUnit = function(tgt, n) return Combat.dispellableOn(tgt, n) end,
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
        -- The four verbs below were absent entirely, and each one faulted every effect that used it.
        -- Inert and reporting, like their neighbours.
        --
        -- A charge this stand-in does not hold: answer what was asked for, so an effect that scores its
        -- blow off the spend (`fx.damage(t, { amount = base * fx.spendCharge(k, n) })`) quotes its full
        -- form rather than throwing. Mirrors spendChi above.
        spendCharge = function(_, n) return n or 0 end,
        dismiss = function() out.dismiss = true; return true end,
        placeProp = function(_, _, id) out.prop = id; return nil end,
        -- Record the shape rather than wearing it: the tooltip wants to name what the caster becomes.
        transform = function(_, charId, opts)
            out.transform = charId
            out.transformDuration = opts and opts.duration
            return true
        end,
        -- No stash and no board here, so nothing is handed over -- but the item is recorded, so a
        -- describer can say what the cast would yield (ability_distil's draught).
        grantItem = function(_, itemId) out.grants = itemId; return nil end,
        knockback = function(_, distance) out.knockback = distance or 1; return 0, false end,
        retreat = function() return 0 end, -- the caster's own step-back moves nobody the row quotes
        pull = function() out.pull = true; return false end,
        -- No board here, so there is no furniture to grab: the object layer reports nothing and moves
        -- nothing. Present for the reason the tail of this table spells out -- a missing helper faults
        -- while the effect is still building its arguments, and the tooltip goes blank rather than wrong.
        objectAt = function() return nil end,
        hurl = function() return 0, false end,
        pullObject = function() return false end,
        teleportUser = function() out.teleport = true; return true end,
        teleport = function() out.teleport = true; return true end,
        charge = function(_, distance) out.charge = distance or 1; return 0 end,
        -- Tile-aimed, but the same tiles closed: the grade weighs a charge per tile of lane it takes
        -- (models/grade.lua), and what it was pointed at does not change how far it runs.
        chargeInto = function(_, _, distance) out.charge = distance or 1; return 0 end,
        steal = function() out.steal = true; return nil end,
        -- Record that the ability lays a foe's kit open, so the tooltip can name it (like `steal`).
        reveal = function() out.reveal = true end,
        hasten = function(_, ticks) out.hasten = (out.hasten or 0) + (ticks or 0); return 0 end,
        -- No board here, so the corpse/reanimation helpers report nothing; `raise` records what it
        -- would call so the inventory tooltip can name it, like `summon` does.
        random = function() return 1 end,
        cleanse = function() out.cleanse = true; return 0 end,
        corpseAt = function() return nil end,
        -- A FALLEN ALLY TO RAISE. This used to answer nil, and a revival effect bails on that before it
        -- reaches fx.reanimate -- so Revive, the Revive Scroll and the Reviving Salts each described
        -- themselves as doing nothing at all, in the shop and the inventory alike. Hand back a stand-in
        -- on the caster's own side, because every one of those effects gates on
        -- `body.side == fx.user.side` and an enemy-sided body would fall straight through the branch
        -- the same way nil did.
        downedAt = function()
            local body = previewStandIn()
            body.side = unit.side
            return body
        end,
        corpsesIn = function() return {} end,
        -- ...and record the raising, so a caller can say so. `fraction` is the share of max health the
        -- body comes back with -- what the ability's own magnitude means for this verb.
        reanimate = function(_, fraction)
            out.revives = fraction or 1
            return true
        end,
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
        -- Inert, like every mutator here: an effect that banks a battle-scoped fact on the caster
        -- (Turning Year's fire/frost half, the Unspent Blow's tally) writes it through this rather than
        -- assigning `fx.user.<field>`, so the inventory tooltip -- rebuilt on every hover -- neither
        -- advances the count nor flips the branch. (The userProxy above backstops any stray direct
        -- write for the same reason, but fx.bank is the path a data effect is meant to take.)
        bank = function() end,
        -- Inert for the same reason, and more urgently: this table hands the effect the REAL item as
        -- `fx.item` (it has to -- the tooltip quotes the item's own level and counters off it), so an
        -- effect that spent its purse directly would drain it on every hover of the inventory grid.
        bankItem = function() end,
        -- Inert here: the dry run reports what an ability WOULD do, and "acts again" is not a thing
        -- the inventory tooltip can render. It is recorded so a describer could name it if one ever wants to.
        -- Recorded on `out` whoever it is aimed at: this table summarises what the ability DOES for the
        -- inventory tooltip, and "hands out an extra action" is the same claim whether the action goes
        -- to the caster or to the ally it is pointed at. There is no board here to tell them apart.
        grantExtraAction = function(n) out.extraActions = (out.extraActions or 0) + (n or 1); return 0 end,
        log = function() end,
        -- There is no board and no clock here, so these report nothing and change nothing -- but they
        -- must EXIST, for the reason the whole of this table exists: a missing helper throws while the
        -- effect is still building its arguments, and the inventory tooltip goes blank rather than
        -- wrong, which is much harder to notice.
        clearCooldowns = function() return 0 end,
        recall = function() out.recall = true; return true end,
        bounty = function(amount) out.bounty = (out.bounty or 0) + (amount or 0); return 0 end,
        consumeCorpse = function() return false end,
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
        local d = Combat.unitGap(unit, other) -- nearest cell to nearest cell, so either body may be wide
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
                and not Combat.unitsSighted(combat, unit, other) then
                valid = false
            end
            if valid then out[#out + 1] = other end
        end
    end
    return out
end

-- Does this ability read as friendly (green preview) rather than hostile (red)? Ally/self targets
-- are supportive; enemy strikes and tile-targeted trap placements are hostile.
--
-- `support` overrides the guess in BOTH directions, and both directions are used: a tile/area cast
-- that lays down a friendly effect (a Sanctuary hazard) opts IN with `support = true`, and a
-- self-targeted blow opts OUT with `support = false` -- a Clear Out is aimed at your own tile because
-- that is where the spin is centred, not because it is a kindness (see ability_clear_out.lua).
function Combat.isSupportAbility(ab)
    if ab == nil then return false end
    if ab.support ~= nil then return ab.support end
    return ab.target == "ally" or ab.target == "self"
end

-- The tag list a cast/strike cue carries so the view can pick its picture -- the item's own tags plus
-- the active ability's, in that order, the same descriptive-tag-leads ordering ui/motif.lua reads. A
-- weapon says its family and shape ("dagger", "pierce"); the ability behind it adds the element it
-- throws ("fire"). The two together are what let a Fireball wand bloom and a Frost wand shatter off
-- one shared vocabulary, with nothing authored to say so. Mirrors states/battle.lua's fieldTags, which
-- builds the same list for the telegraph -- promise and result read the same because they are the same
-- tags. Nil-safe: an item with no tags and no ability yields nil, and the view falls back.
function Combat.fxTags(item, ab)
    if not item then return nil end
    ab = ab or item.activeAbility
    if not (ab and ab.tags) then return item.tags end
    local out = {}
    for _, t in ipairs(item.tags or {}) do out[#out + 1] = t end
    for _, t in ipairs(ab.tags) do out[#out + 1] = t end
    return out
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
-- What Combat.drainResource WOULD take, without taking it: the read-only twin the dry runs need. An
-- effect that pours back what it drained (Transfusion lending health, Drain Mana siphoning a pool)
-- reads the drain's return value and does nothing at all when it comes back 0 -- so a preview whose
-- drain reported nothing showed no heal, no siphon, and no reason for the AI to reach for the cast.
function Combat.drainableAmount(char, stat, amount)
    if not amount or amount <= 0 then return 0 end
    local res = char.stats[stat]
    local have = (type(res) == "table") and res.current or (res or 0)
    return math.max(0, math.min(amount, have))
end

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

-- Pay part of an incoming wound out of `target`'s mana instead of its health, and return how much was
-- covered. 0 for a unit carrying no Mana Shield, or one whose pool is dry -- at which point the blow
-- simply lands, which is the whole counterplay: you do not beat the shield, you empty it.
--
-- Final Fantasy Tactics' MP Switch. The `manaShield` field is item-level rather than an activeAbility
-- keyword because it describes what CARRYING the thing does, not what casting it does -- the same
-- reasoning as `waitBehavior` and `statusImmunity` (see docs/weapons.md on that distinction).
--
-- `ratio` is mana spent per point of damage covered. 1 is the FFT original (a point for a point);
-- above 1 the protection is real but expensive, which is how a small pool can still be made to guard a
-- large one without the item becoming the only defensive purchase in the game.
--
-- First shield in the grid wins, and they never stack: two of these is one of these. The pool is read
-- through the reservation-aware ceiling nowhere at all -- only `current` matters, since a reserved
-- point is still a point that is not there to spend.
function Combat.soakIntoMana(combat, target, dmg)
    if not dmg or dmg <= 0 then return 0 end
    local char = target and target.char
    if not (char and char.inventory and char.stats.mana) then return 0 end

    local shield
    for _, item in ipairs(Character.eachItem(char)) do
        if item.manaShield then shield = item break end
    end
    if not shield then return 0 end

    local ratio = shield.manaShield.ratio or 1
    local available = char.stats.mana.current or 0
    if available <= 0 or ratio <= 0 then return 0 end

    -- What the pool can actually cover, capped by the wound itself. Floored, so a partially-funded
    -- point of damage is never covered for free -- the last dregs of a pool round DOWN.
    local coverable = math.min(dmg, math.floor(available / ratio))
    if coverable <= 0 then return 0 end

    local spent = Combat.drainResource(char, "mana", coverable * ratio)
    if combat then
        Combat.logEvent(combat, "status", string.format("%s's %s turns %d of the blow into %d mana.",
            unitName(target), shield.name or "ward", coverable, spent), target)
    end
    return coverable
end

-- Pay part of an incoming wound out of `target`'s PURSE instead of its health, and return how much was
-- covered. The engine half of On Account (data/status/status_open_account.lua), which The Open Account
-- toggles on and off (data/items/ability/ability_open_account.lua).
--
-- The twin of Combat.soakIntoMana above, and deliberately the same shape: it runs on the far side of
-- mitigation, so what the account is asked to settle is the number that would actually have reached the
-- body -- armor gets its full say first, and a ward priced against the pre-armor figure would be
-- strictly better than armor.
--
-- The two numbers come from opposite places on purpose (the status's own header argues this at length):
-- `paysInGold` is the exchange RATE and belongs to the rule, so it is read off the def and is the same
-- wherever the rule turns up; `magnitude` is the CAP -- how much of a single blow the account will
-- cover -- and belongs to the granter, so it is read off the live instance, which the ability raises per
-- forge level. Anything past the cap lands on the flesh, which is what keeps this a ward against
-- attrition and no defence at all against one enormous hit.
--
-- Side-aware through Combat.spendPurse: an enemy wearing the status spends its own coffer and never
-- reaches the player's bank. Outside the campaign there is no purse at all, so the account covers
-- nothing and the blow simply lands -- inert, and the same counterplay the Mana Shield has: you do not
-- beat it, you empty it.
function Combat.soakIntoPurse(combat, target, dmg)
    if not dmg or dmg <= 0 then return 0 end
    local acct = target and Status.get(target, "status_open_account")
    if not acct then return 0 end

    local rate = (acct.def and acct.def.paysInGold) or 0
    if rate <= 0 then return 0 end
    local cap = acct.magnitude or 0
    local available = Combat.purseAvailable(combat, target)

    -- What the bank can actually cover, capped by the wound and by the account's per-blow ceiling.
    -- Floored, so a partially-funded point is never covered for free -- the last coppers round DOWN,
    -- exactly as the Mana Shield's dregs do.
    local coverable = math.min(dmg, cap, math.floor(available / rate))
    if coverable <= 0 then return 0 end

    local spent = Combat.spendPurse(combat, target, coverable * rate)
    -- spendPurse clamps to what is on hand; re-derive the coverage from what it actually took so a race
    -- against the clamp can never bill less than it covers.
    local covered = math.floor(spent / rate)
    if covered <= 0 then return 0 end
    Combat.logEvent(combat, "status", string.format("%s settles %d of the blow out of the purse (%dg).",
        unitName(target), covered, covered * rate), target)
    return covered
end

-- Bank gold lifted off the enemy mid-fight (data/items/utility/utility_skimmers_cut.lua). Returns what
-- was actually banked.
--
-- Gold has never existed inside a battle before this: it lives on the player (models/player.lua) and a
-- fight has no handle on one -- deliberately, since a netplay duel has no campaign player to pay. So a
-- skim accumulates HERE, on the combat, and rides out through the existing battle -> spoils -> player
-- channel that a won fight already uses (models/spoils.lua, states/battle.lua). No new path to the
-- purse, and nothing to keep in sync.
--
-- Two consequences, both of them deliberate and both worth knowing before carrying the item:
--   * PARTY ONLY. An enemy rogue wearing the same charm skims nothing, because there is no purse on
--     that side for it to go into. The charm is worth what it is worth to you.
--   * IT PAYS OUT ON A WIN. The gold is handed over with the spoils, so losing the fight loses the
--     takings with it. That is the honest reading of picking a man's pocket during a brawl you then
--     do not walk away from, and it keeps the item from being a reason to farm losses.
function Combat.skimGold(combat, unit, amount)
    if not combat or not amount or amount <= 0 then return 0 end
    if not unit or unit.side ~= "party" then return 0 end
    combat.skimmed = (combat.skimmed or 0) + amount
    return amount
end

-- Swap two units' tiles (the Rogue's Swap). Both arrivals spring whatever waits on the tile they land
-- on (Combat.enterTile: traps, hazards), exactly as a walk or a shove would -- so trading places into a
-- trap is as real as stepping onto one, unless Feather Boots carry the mover clear. Positions are set
-- together FIRST, then arrivals resolved, so enterTile never reads a stale collision mid-swap.
-- Neither passes a `reason`: a swap trades two units through each other without either crossing the
-- ground between, so it springs both tiles but bleeds neither.
function Combat.swapUnits(combat, a, b)
    if not (a and b and a.alive and b.alive) then return false end
    local aw, ah = a.w or 1, a.h or 1
    local bw, bh = b.w or 1, b.h or 1
    -- Equal footprints always trade cleanly: each lands exactly on the region the other just left.
    -- Bodies of DIFFERENT size may not -- one might overhang the board or a wall at the other's tile --
    -- so both destinations are checked, ignoring the two swappers themselves (they vacate together).
    -- A swap that can't seat both bodies is refused rather than jamming one half off the grid.
    if aw ~= bw or ah ~= bh then
        local function fitsIgnoringPair(w, h, ax, ay)
            for _, c in ipairs(Combat.cellsAt(w, h, ax, ay)) do
                local row = combat.arena and combat.arena.tiles and combat.arena.tiles[c.y]
                local cell = row and row[c.x]
                if not (cell and cell.walkable) then return false end
                if Combat.objectBlocksAt(combat, c.x, c.y) then return false end
                local occ = Combat.unitAt(combat, c.x, c.y)
                if occ and occ ~= a and occ ~= b then return false end
            end
            return true
        end
        if not (fitsIgnoringPair(aw, ah, b.x, b.y) and fitsIgnoringPair(bw, bh, a.x, a.y)) then
            return false
        end
    end
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
    local d = Combat.unitGap(watcher, mover)
    if d > range or d < Combat.abilityMinRange(ab) then return false end
    if ab.requiresSight and not Combat.unitsSighted(combat, watcher, mover) then
        return false
    end
    if per > 0 then spendResource(watcher.char, "stamina", per) end
    Combat.logEvent(combat, "action", string.format("%s fires on overwatch!", unitName(watcher)), watcher)
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
    return Trait.has(unit, "trait_overchannel")
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
        string.format("%s downs %s.", unitName(unit), item.name or "a potion"), unit)
    if stat == "health" then return Combat.applyHeal(combat, unit, amount) end
    return Combat.restoreResource(unit.char, stat, amount)
end

-- Alchemist's Reservoir: a caster that pays for a spell out of a flask when the mana runs dry (the
-- trait of the same name). Read exactly like Combat.canOverchannel beside it -- a capability the cost
-- path consults directly, since there is no "onSpend" trait event -- and it is the same bargain made
-- from a different pocket: Overchannel spends life it cannot get back, this spends stock it can.
-- True only when a mana draught is actually in the satchel, so an empty alchemist is blocked normally.
function Combat.canDrawOnPotion(unit)
    return Trait.has(unit, "trait_alchemists_reservoir")
        and Combat.carriedRestorative(unit, "mana") ~= nil
end

-- Pay an ability's `cost` for `unit`. Normally a plain spend; but an Overchannel unit short on mana
-- drains what mana it has and pays the shortfall out of health (1 HP per missing point). The single
-- spend path useItem / strikeTrap / strikeWall all route through, so casting-in-blood is uniform.
function Combat.spendCost(combat, unit, cost)
    if not cost then return end
    local char = unit.char
    -- A DAMPENING OATH standing within reach doubles what a working costs (the Spellbreaker's). A tax
    -- rather than a denial, which is the whole shape of that shelf: the caster still gets to cast, the
    -- enemy AI is not deadlocked, and what the spellbreaker has bought is that the other side runs dry
    -- first. Mana only -- an oath does not make a swing tire you faster.
    --
    -- Applied here, in the one spend path every cast routes through, and deliberately NOT in costBlock:
    -- affordability is checked against the printed price, so a caster who could just afford a spell is
    -- allowed to commit to it and then finds the pool emptied. Being taxed into nothing is the threat.
    if cost.stat == "mana" and cost.amount and cost.amount > 0 then
        for _, u in ipairs(combat.units or {}) do
            if u.alive and u.side ~= unit.side and Trait.flag(u, "dampensNearbyCasts")
                and math.max(math.abs(u.x - unit.x), math.abs(u.y - unit.y)) <= 3 then
                cost = { stat = cost.stat, amount = cost.amount * 2 }
                Combat.logEvent(combat, "status",
                    string.format("%s's working costs double under the oath.", unitName(unit)), unit)
                break
            end
        end
        -- BATTLE CASTING (the Battlemage's): a working thrown with a foe in your face costs less. The
        -- inverse of every caster's instinct, and the whole argument of the discipline -- a battlemage
        -- is cheapest exactly where a mage is most frightened. Applied after the oath, so a battlemage
        -- standing beside a spellbreaker pays double and then takes its discount off the doubled price.
        local bc = Trait.flag(unit, "cheaperInMelee")
        if bc then
            for _, u in ipairs(combat.units or {}) do
                if u.alive and u.side ~= unit.side
                    and math.max(math.abs(u.x - unit.x), math.abs(u.y - unit.y)) <= 1 then
                    local off = (bc.def and bc.def.magnitude or 30) / 100
                    cost = { stat = cost.stat, amount = math.max(1, math.floor(cost.amount * (1 - off))) }
                    break
                end
            end
        end
    end
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
                string.format("%s overchannels, burning %d health.", unitName(unit), shortfall), unit)
            return
        end
    end
    spendResource(char, cost.stat, cost.amount)
end

-- Pay ALL of `ab`'s costs for `unit`, in authored order. The one spend path useItem / strikeTrap /
-- strikeWall call, so a multi-pool cast can never be half-paid: costBlock has already cleared every
-- entry by the time anything gets here, and each goes through Combat.spendCost above, so drawing on
-- two pools loses none of what paying for one does (Overchannel, the Reservoir flask).
function Combat.spendCosts(combat, unit, ab)
    for _, cost in ipairs(Combat.abilityCosts(unit, ab)) do
        Combat.spendCost(combat, unit, cost)
    end
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
                    -- The whole body must fit where it blinks (its own cells don't block it), so a wide
                    -- unit's blink band drops any anchor its footprint couldn't clear. Matches blink().
                    if Combat.footprintFree(combat, unit.w or 1, unit.h or 1, x, y, unit) then
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
    -- The whole body must fit where it lands (its own current cells don't block the jump); a wide
    -- unit can't blink into a one-tile pocket. Range is measured from the nearest cell of the body.
    if not Combat.footprintFree(combat, unit.w or 1, unit.h or 1, x, y, unit) then
        return false, "blocked tile"
    end
    if Combat.cellGap(x, y, unit) > (mb.movement or 0) then return false, "out of range" end

    if mb.cost then spendResource(unit.char, mb.cost.stat, mb.cost.amount) end
    combat.turn.moved = true
    combat.turn.moveCost = 0 -- a blink owes no move initiative; its resource cost is the price
    unit.x, unit.y = x, y
    Combat.logEvent(combat, "move", string.format("%s blinks to (%d, %d).", unitName(unit), x, y), unit)
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
    return Combat.abilityCosts(unit, ab)[1]
end

-- EVERY pool ability `ab` draws on for `unit`, in authored order, each scaled by the unit's status
-- cost multiplier (Haste halves it). Empty for a free ability. This is the real source of truth --
-- `Combat.abilityCost` above is the first entry, kept for the callers that only ever ask about a
-- single-pool swing (see Trait.answerCost, which prices a whole list of its own).
--
-- Most weapons name one pool. A few spend two at once -- the crescent blade pays for its beam in
-- mana AND the swing that carries it in stamina -- and they are priced, gated, spent and drawn the
-- same way a one-pool cast is, because everything below iterates rather than reading `cost.stat`.
function Combat.abilityCosts(unit, ab)
    local mult = Status.costMultiplier(unit)
    local out = Item.costs(ab)
    for _, c in ipairs(out) do c.amount = math.floor(c.amount * mult + 0.5) end
    return out
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
    for _, cost in ipairs(Combat.abilityCosts(unit, ab)) do
        out[#out + 1] = { kind = "cost", stat = cost.stat, amount = cost.amount }
    end
    local reserve = Combat.abilityReserve(unit, ab)
    if reserve then out[#out + 1] = { kind = "reserve", stat = reserve.stat, amount = reserve.amount } end
    return out
end

-- The reason `unit` can't pay for `ab` -- a cost it can't spend or a reservation it can't commit --
-- as an itemBlockReason entry, or nil when it can. Shared by Combat.canAfford (which only wants the
-- yes/no) and Combat.itemBlockReason (which wants to say which pool fell short, and by how much).
local function costBlock(unit, ab)
    -- Every pool the cast draws on has to be payable, so a dual-cost weapon with the mana for its
    -- beam but no stamina for the swing is refused exactly as if the mana were what ran out. The
    -- FIRST authored pool that falls short is the one reported, so the message names a single
    -- shortfall the player can act on rather than listing everything at once.
    local costs = Combat.abilityCosts(unit, ab)
    for _, cost in ipairs(costs) do
        if resourceValue(unit.char, cost.stat) < cost.amount then
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
    end
    -- A reservation is spent like a cost and then locked away, so the caster must hold it now (and
    -- reserving health can never be lethal). Combat.useItem pays the cost before the effect takes
    -- the reservation, so when both draw the same pool the reservation only gets what the cost left.
    local res = Combat.abilityReserve(unit, ab)
    if res then
        local available = resourceValue(unit.char, res.stat)
        for _, cost in ipairs(costs) do
            if cost.stat == res.stat then available = available - cost.amount end
        end
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

-- Does `char` carry an item granting trait `id`? The out-of-battle twin of Trait.has, which reads the
-- traits ATTACHED to a live unit and so answers nothing before a fight has started. Innate blueprint
-- traits are deliberately not consulted: that field is dead (traits attach only from grid items).
local function gridGrantsTrait(char, id)
    for _, item in ipairs(Character.eachItem(char)) do
        for _, tid in ipairs(item.traits or {}) do
            if tid == id then return true end
        end
    end
    return false
end

-- The prices on `item` that `char`'s pools COULD NEVER MEET, however rested -- what the Loadout screen
-- warns about when a body is handed something it will never be able to use.
--
-- A DIFFERENT QUESTION FROM costBlock ABOVE, which is why it is a separate function rather than a
-- caller of it. That one asks whether a unit can pay right now, off `current`; out of combat a pool
-- that is merely empty refills before the next fight, so asked there it would cry wolf every time
-- somebody walked home tired. This one asks the permanent version: the CEILING, gear folded in
-- (Character.statTotal), against the price. A 12-mana working in the hands of a body with no mana at
-- all is a grid cell that will never do anything, and nothing on any screen used to say so -- the item
-- simply sat there greyed out in the fight, one battle too late to fix.
--
-- Both of costBlock's escape hatches are honoured, or the screen would warn about casts that work
-- perfectly well: Overchannel bills a mana shortfall to health, and the Alchemist's Reservoir opens a
-- carried flask mid-cast. Both are trait-borne, and traits attach at battle start, so out here they
-- are read off the grid (gridGrantsTrait) rather than off a unit.
--
-- Traits are priced too, not just the active ability: a Counter-Magic charm on a body with no mana is
-- the same dead slot as an unaffordable spell, and it is quieter, since a trait never even offers
-- itself to be clicked. Trait.ownCost decides which of them actually charge what they declare.
--
-- Returns { { stat, amount, ceiling, text }, ... }, one entry per pool that falls short -- ALL of
-- them, where the battle message names only the first. Mid-turn a player can act on one shortfall; the
-- Loadout is the screen where every one of them gets fixed, so it gets the whole list.
function Combat.unpayableCosts(char, item)
    local out = {}
    if not (char and item) then return out end

    local function consider(costs)
        for _, cost in ipairs(costs) do
            local ceiling = Character.statTotal(char, cost.stat)
            if ceiling < cost.amount then
                -- Mana has two other purses. Overchannel pays the shortfall in blood, and since a
                -- shortfall is never allowed to be lethal, health has to CLEAR the gap rather than
                -- merely meet it -- the same test costBlock makes.
                local covered = false
                if cost.stat == "mana" and gridGrantsTrait(char, "trait_overchannel") then
                    covered = Character.statTotal(char, "health") > cost.amount - ceiling
                end
                if cost.stat == "mana" and not covered
                    and gridGrantsTrait(char, "trait_alchemists_reservoir") then
                    local flask = Combat.carriedRestorative({ char = char }, "mana")
                    covered = flask ~= nil and ceiling + (flask.activeAbility.restore or 0) >= cost.amount
                end
                if not covered then
                    out[#out + 1] = { stat = cost.stat, amount = cost.amount, ceiling = ceiling,
                        text = string.format("Needs %d %s -- %s tops out at %d",
                            cost.amount, cost.stat, char.name or "this body", ceiling) }
                end
            end
        end
    end

    consider(Item.costs(item.activeAbility))
    for _, tid in ipairs(item.traits or {}) do
        consider(Item.costList(Trait.ownCost(Trait.instantiate(tid, item))))
    end
    return out
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
    -- ANY mana in the price makes it sorcery, not just a wholly mana-paid cast: a crescent blade
    -- that spends stamina on the swing is still working magic with the other hand.
    return Item.costsStat(ab, "mana")
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
        if item then
            item.activeSummon = nil
            -- EPHEMERAL stock (S4, field crafting) does not leave the battlefield. A poultice wrung out
            -- of a burning hedge is a thing you made out of the fight, and carrying it home would turn
            -- every Herbalist into a free-money printer between quests -- brew, walk out, sell.
            --
            -- Cleared here rather than at the grant, because the whole point is that it is real FOR the
            -- fight: it stacks, it is cast, it is stolen, it is previewed, exactly like bought stock.
            -- The only thing it may not do is persist.
            if item.ephemeral then char.inventory[i] = nil end
        end
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

    -- A sole action (Harrier's Bow) already taken this turn: it fires for free but it is still the
    -- turn's ACTION, so nothing else may be used after it -- only the move it left open. Refuses EVERY
    -- item (its own re-press included), so the skirmisher who shot is told to ride, not handed a second
    -- attack. Checked before the free gate so the message names the rule that actually applies.
    if unit.actionSpent then
        return { kind = "acted", reason = "action spent",
            text = "Already acted this turn -- move only" }
    end

    -- A free action already spent this turn. Checked before the resource gates so a skirmisher whose
    -- free shot is gone is told THAT, rather than being told it can afford a shot it may not take --
    -- the free ability is usually still perfectly affordable, which is exactly what makes the greyed
    -- slot confusing without this line.
    if ab.free and Combat.freeActionsLeft(unit) <= 0 then
        return { kind = "spent", reason = "free action spent",
            text = "Free action already used this turn" }
    end

    -- Halted: told to stand down, and standing down. Refuses EVERY ability -- weapon, spell, potion
    -- alike -- so it is checked before the three narrower gates below it, which would otherwise let a
    -- halted unit be told the more specific and less true thing ("no mana") about a cast it was never
    -- going to be allowed to make. It does not stop the unit MOVING: walking away is exactly what a
    -- unit ordered to stand down is left with, and leaving it that keeps the status a refusal of
    -- violence rather than a second Stun (see Status.halted).
    if Status.halted(unit) then
        return { kind = "halted", reason = "halted", text = "Halted -- cannot act this turn" }
    end

    -- Silenced: a mana cost can't be paid, so a mana ability is refused (one drawing on stamina or
    -- health still fires). Checked before affordability so the note reads "silenced", not "no mana".
    -- A cast drawing on mana AMONG other pools is refused whole: silence stops the working, and the
    -- stamina half of a crescent blade's price does not buy a partial one.
    if Item.costsStat(ab, "mana") and Status.silenced(unit) then
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
    -- A charge/counter item with an empty purse (the Gleaning Rod with no banked charge, the Reliquary
    -- of Tallies with nothing owed): there is nothing to spend, so the cast is refused rather than
    -- fired for no effect and a wasted turn. `ab.counter` reads the item's current count -- the very
    -- number the grid badge shows -- so the greyed slot, the refused click and the badge can never
    -- disagree. Kept after affordability so a caster who is ALSO out of mana is told the fixable thing.
    --
    -- `counterGates = false` opts out of the refusal while keeping the badge: a counter that merely
    -- SCALES the cast (the Long Count grows harder per turn taken, but swings fine at zero) is a readout,
    -- not a purse, so an empty count is a floor rather than a wasted turn.
    if ab.counter and ab.counterGates ~= false then
        local n = ab.counter(unit, item) or 0
        if n <= 0 then
            return { kind = "empty", reason = "empty", count = n,
                text = ab.counterEmpty or "Empty -- nothing banked to spend yet" }
        end
    end
    -- A signature gated behind an in-battle requirement (land N blows, heal N times, weather a hit)
    -- stays locked until the tally is met -- Combat.unlockMet reads the per-unit counters the seams
    -- bank, and an ability with no `unlock` is always met. Kept LAST among the gates: a locked
    -- signature that is ALSO unaffordable or silenced is told the more fixable thing first, and only
    -- once nothing else stands in the way does the slot read "still charging". `progress` rides along
    -- so the grid badge can draw the fraction without re-deriving it.
    if ab.unlock and unit then
        local met, cur, total = Combat.unlockMet(unit, item)
        if not met then
            local label = Combat.unlockLabel(unit, item)
            return { kind = "locked", reason = "locked", text = label,
                cur = cur, total = total,
                progress = (total and total > 0) and ((cur or 0) / total) or 0 }
        end
    end
    return nil
end

-- Lay a unit's whole kit open to the party (the Assayer's Eye): from now on the battle UI may show
-- its item grid and each item's tooltip. Just a flag on the body -- the reveal is a piece of KNOWLEDGE,
-- not a change to the fight, so it never touches initiative, resources or the board -- and it holds for
-- the rest of the fight (units are rebuilt per battle, so nothing carries out). Idempotent, which is
-- what lets the dry-run/preview fx call it harmlessly.
function Combat.revealInventory(combat, unit)
    if unit then unit.inventoryRevealed = true end
end

-- Has this unit's kit been assayed (Combat.revealInventory)? Drives the inventory-peek panel.
function Combat.inventoryRevealed(unit)
    return unit ~= nil and unit.inventoryRevealed == true
end

-- Lift one item from `victim`'s grid into `thief`'s. Items the blueprint marks `noSteal` (a
-- beast's fangs) can't be taken. Among the rest, the highest `stealPriority` wins -- that's how a
-- Decoy makes itself the obvious thing to grab -- and ties are broken at random.
--
-- The item goes into the thief's own grid; if that grid is full, a party thief pockets it into the
-- player's stash (combat.stash, wired to player.stash by the battle state -- unbounded), while an
-- enemy thief with nowhere to put it simply destroys it. Returns the stolen item, or nil if the
-- victim carried nothing worth taking.
--
-- A bearer of the Jealous Resin (Trait.flag `wardsTheft`) refuses the whole grid rather than one item,
-- so every theft vector -- Pickpocket, an enemy thief's own grab -- comes away empty. The refusal is logged
-- as a failure of the ATTEMPT and never names the charm: an enemy's grid is hidden until it is assayed
-- (Combat.revealInventory), and a log line that read "the Jealous Resin holds" would hand over an item
-- the player has not earned the right to see.
function Combat.steal(combat, thief, victim)
    if Trait.flag(victim, "wardsTheft") then
        Combat.logEvent(combat, "action",
            string.format("%s cannot get into %s's kit.", unitName(thief), unitName(victim)),
            { thief, victim })
        return nil
    end

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
            string.format("%s finds nothing to steal from %s.", unitName(thief), unitName(victim)),
            { thief, victim })
        return nil
    end

    local item = pool[Combat.roll(combat, #pool)]
    Character.removeItem(victim.char, item)
    Combat.logEvent(combat, "action", string.format("%s steals %s from %s.",
        unitName(thief), item.name or "an item", unitName(victim)), { thief, victim })

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
    withStatusLifesteal(user, auraMods) -- a sub-strike drinks under the Red Thirst exactly as the main swing does
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
        random = function(n) return Combat.roll(combat, n or 1) end,
        log = function(kind, text, subjects) return Combat.logEvent(combat, kind, text, subjects) end,
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
        -- Give ground: shove the STRIKER away from `t`, harmlessly. The twin of resolveCast's helper of
        -- the same name, and it has to exist on this table too -- a hit-and-run WEAPON (wolf fangs) runs
        -- its effect through here, not through resolveCast, and this path is not pcall-guarded.
        retreat = function(t, distance)
            if not t then return 0 end
            return Combat.knockback(combat, t, user, distance or 1, { amount = 0 })
        end,
        -- Battle-scoped state banked on the striker (a wand's fire/frost half): a sub-struck weapon
        -- runs its effect here too (Dual Wield), and this path is not pcall-guarded, so the helper has
        -- to exist or a swung weapon that banks would fault. Real, like the rest of strikeWith.
        bank = function(key, value) if user then user[key] = value end end,
        -- The item-scoped twin (a relic's own purse). Present for the same reason `bank` is: this path
        -- is not pcall-guarded, so a sub-struck weapon that banks on itself would fault without it.
        bankItem = function(key, value) if weapon then weapon[key] = value end end,
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

-- Bank technique for a roster member's action with `item`, and record it on the battle so the summary
-- can name what the fight earned. Keyed by what the item votes for (Discipline.growthClasses): a
-- discipline item banks its DISCIPLINE (a Ninja weapon grows data/growth/ninja.lua, not its two
-- parents), a plain item banks its single `class`. No-op for stock with neither.
--
-- ONE AWARD PER ACTION, where there used to be two. Technique was discipline-only, and a separate
-- class-vote floater existed to cover the silence that left: only 233 of 638 item files declare a
-- discipline and disciplines are LOCKED content, so an opening campaign hand -- weapon_iron_sword is
-- `class = "knight"` with no discipline -- banked nothing and floated nothing. The two awards needed a
-- precedence rule so one action was never reported twice under one name. Now that every house banks
-- the same currency there is one thing to report, so the rule and its second floater are gone.
--
-- CAPPED PER BATTLE, per key (Discipline.TECHNIQUE_PER_BATTLE). The cap is the whole reason this does
-- not reopen the grind door models/growth.lua deliberately shut: a `free` ability bills no initiative
-- and leaves the turn open, and nothing obliges a player to finish a fight, so the action count in one
-- encounter is not bounded by anything the rules enforce. Past the cap the player keeps playing and
-- stops banking, which is the correct shape -- the reward for committing is real and finite, and the
-- thirty-first cast of the same knife is farming.
--
-- The cap now bounds the LEVEL-UP READING as well as the wallet, since they are one ledger. That is
-- the intended reading of it: thirty actions of one house in a single fight is far past the point the
-- commitment has been demonstrated, and it keeps the anti-grind rule stated in one place.
--
-- The OTHER farm vector -- lose on purpose, keep the bank, try again -- closes itself: "Try Again"
-- restores the party from the pre-fight snapshot (states/game.lua), and the ledger rides in the
-- character snapshot (models/save.lua), so a retried fight starts from what the player had when they
-- first walked into it. Nothing here needs to defend against that; it just must not be moved out of
-- the saved character to somewhere the snapshot does not reach.
--
-- `combat.techniqueEarned` is the fight's running ledger, { [key] = amount } -- what the CAP is
-- measured against, since the cap is per house across the whole field. `combat.techniqueByActor` is
-- the same ledger split by whose hand banked it, `{ { char, name, houses = { { key, amount } } } }` in
-- first-award order, and it is what the summary panel reports: technique is earned per body (the bill
-- spends from one body, and specializing is what makes it pay), so "+6 Rogue" is only half a fact
-- until it says which of the four earned it. `combat.techniqueAward` is the LAST award only -- a
-- one-shot the battle state drains to float "+2 Ninja" over the caster (states/battle.lua) and then
-- clears, so a capped-out action floats nothing rather than a misleading zero.
function Combat.awardTechnique(combat, unit, item)
    combat.techniqueAward = nil
    local key = Discipline.growthClasses(item)[1]
    if not key then return 0 end

    combat.techniqueEarned = combat.techniqueEarned or {}
    local earned = combat.techniqueEarned[key] or 0
    local amount = math.min(Discipline.TECHNIQUE_PER_ACTION,
        Discipline.TECHNIQUE_PER_BATTLE - earned)
    if amount <= 0 then return 0 end

    Character.recordTechnique(unit.char, key, amount)
    combat.techniqueEarned[key] = earned + amount
    combat.techniqueAward = { unit = unit, discipline = key, amount = amount }

    -- Linear scans, not maps keyed by char/key: a fight banks for a handful of bodies across a handful
    -- of houses, and an ordered list is what both the display and a stable reading want anyway.
    combat.techniqueByActor = combat.techniqueByActor or {}
    local actor
    for _, a in ipairs(combat.techniqueByActor) do
        if a.char == unit.char then actor = a; break end
    end
    if not actor then
        actor = { char = unit.char, name = unitName(unit), houses = {} }
        combat.techniqueByActor[#combat.techniqueByActor + 1] = actor
    end
    local house
    for _, h in ipairs(actor.houses) do
        if h.key == key then house = h; break end
    end
    if not house then
        house = { key = key, amount = 0 }
        actor.houses[#actor.houses + 1] = house
    end
    house.amount = house.amount + amount
    return amount
end

-- Perform an item action: validate range + target kind + resource cost, spend the cost,
-- run the ability's effect(fx), push the actor back by the ability speed, and consume the
-- item if it's a consumable. Returns (true, result) or (false, reason). `result` is
-- { damageDealt, healed } aggregated across the effect's helper calls. A channeled ability
-- instead winds up here and resolves later via Combat.resolveChannel (see the channel branch).
function Combat.useItem(combat, unit, item, tx, ty, windup, dest, spend)
    if not unit.alive then return false, "dead" end
    local ab = item.activeAbility
    if not ab then return false, "no ability" end
    -- Everything that gates the cast regardless of where it's aimed (spent stack, cost/reservation,
    -- grid adjacency) -- the same check the grayed-out slot and the refused arm run.
    local blocked = Combat.itemBlockReason(unit, item)
    if blocked then return false, blocked.reason end

    -- Range is measured from the NEAREST cell of the caster's body to the aimed tile, so a wide unit
    -- reaches from whichever part of it is closest (cellGap == manhattan for a 1×1 caster). The aimed
    -- tile itself may be any cell of a big TARGET's footprint -- Combat.unitAt below resolves the
    -- occupant from it -- so a 2×2 foe can be struck from beside any of its four cells.
    local dist = Combat.cellGap(tx, ty, unit)
    if dist > Combat.abilityRange(combat, unit, ab) + Combat.adjacencyRangeBonus(unit.char, item) then
        return false, "out of range"
    end
    if dist < Combat.abilityMinRange(ab) then
        return false, "too close"
    end
    if ab.requiresSight and not Combat.unitHasSight(combat, unit, tx, ty) then
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
        -- point placement (a trap, a powder keg) still refuses a tile a unit stands on -- or one a
        -- standing OBJECT already holds. Without that second half the placement layers would accept
        -- the cast, spend the turn, and then quietly refuse the tile themselves (Trap/Wall/Prop.place
        -- all return nil on a taken cell) -- the turn gone and nothing on the board to show for it.
        if not ab.allowOccupied and (Combat.unitAt(combat, tx, ty) or Combat.objectAt(combat, tx, ty)) then
            return false, "occupied tile"
        end
    end

    local target = Combat.unitAt(combat, tx, ty)
    if target then
        if ab.target == "enemy" and target.side == unit.side then return false, "invalid target" end
        if ab.target == "ally" and target.side ~= unit.side then return false, "invalid target" end
        if ab.target == "self" and target ~= unit then return false, "invalid target" end
    end
    -- A sight-gated single-target strike needs a real foe in its line -- line of sight is to a TARGET,
    -- not to bare ground, and empty ground trivially passes unitHasSight above. Without this the shot
    -- could be committed at an empty tile purely to bank its on-draw reward (The Held Breath's Unseen
    -- lands the instant the draw COMMITS, in the channel branch below) -- a weapon that must see its
    -- mark turned into a free invisibility aimed at nothing. The gate the arm/aim UI already enforces,
    -- restated in the model so no path (the AI, a network peer) can reach past it. An AoE cast is
    -- exempt: it aims at a cell, not a body, so it may legitimately fall on open ground.
    if ab.requiresSight and ab.target == "enemy" and not ab.aoe
        and not (target and target.alive and target.side ~= unit.side) then
        return false, "no line of sight"
    end

    -- Affordability was settled by itemBlockReason above (nothing has been spent since), so the
    -- cast is committed from here: pay the cost. The reservation isn't taken until the effect
    -- produces the summon that holds it (below).
    Combat.spendCosts(combat, unit, ab)

    -- The cast is now committed (never a preview or a refused arm reaches here). Bank it toward any
    -- signature gated on casting, and settle a fired signature's own unlock -- re-locking a repeatable
    -- one to the current tally, or latching a `once` one open. Both run at commit, so a channel that
    -- winds up now (and lands later) still counts and re-locks exactly once.
    Combat.tally(unit, "cast", 1)
    Combat.unlockConsume(unit, item)

    -- A channeled ability (a large AOE spell) doesn't resolve now: the caster winds up for its
    -- `windup` ticks, during which every other unit gets to act and may walk out of the
    -- threatened tiles. Everything is committed at cast-start -- the cost is spent above, and a
    -- consumable is spent here too -- so an interrupted channel is a fully-wasted cast. The effect
    -- itself runs later, from Combat.resolveChannel when the caster's slot comes back around, and
    -- only THEN is ab.speed charged. Ending the turn by the wind-up (not ab.speed) is what places
    -- the caster back in the order at exactly its resolution slot, so no separate scheduler exists.
    --
    -- The wind-up is those ticks and nothing else: the turn's move cost is DEFERRED past the
    -- resolution (endTurn's `defer`) rather than stacked onto it. Walking before a cast must not
    -- stretch the caster's own telegraph -- that would hand the foes under the blast extra turns to
    -- stroll out of it, and silently punish repositioning. The ground is still paid for, on the far
    -- side: the debt lands on the resolving turn, so the caster's NEXT action comes at the same tick
    -- either way and only the resolution slot moves earlier.
    local windLo, windHi = Item.windupRange(ab)
    if windHi > 0 then
        -- SECOND UTTERANCE (data/traits/trait_second_utterance.lua): a mage that just landed a channel
        -- has one cast in hand that needs no wind-up at all. Spend the charge and fall straight through
        -- to resolveCast, which is exactly what an unchanneled ability does -- so the spell lands now
        -- and bills `ab.speed` instead of ending the turn on `ticks`.
        --
        -- Checked here, at the top of the channel branch, rather than anywhere earlier: the charge must
        -- be spent ONLY when there was really a wind-up to skip, or an ordinary Fire Bolt would eat it.
        -- Deliberately NOT decrementing a `consumesItem` stack -- resolveCast does that itself when it
        -- was not told the channel path already had (see its `spent` argument), and doing it here too
        -- would charge a scroll twice for one casting.
        if Status.has(unit, "status_second_utterance") then
            Status.remove(combat, unit, "status_second_utterance")
            Combat.logEvent(combat, "action",
                string.format("%s speaks %s again, and it needs no winding.",
                    unitName(unit), item.name or "the working"), unit)
            return resolveCast(combat, unit, item, ab, tx, ty, nil, nil, nil, dest, spend)
        end
        -- A chargeable wind-up (Saber's signature): the caster picks how long to hold the swing,
        -- anywhere in the ability's own [min, max] TOTAL ticks, and the effect reads both how long it
        -- ran (fx.windup) and how much of that was chosen above the floor (fx.held) to scale its blow.
        -- A longer wind-up is a longer, breakable tell -- the extra ticks land on both the "channeling"
        -- badge's duration and the initiative the turn bills, so the resolution slot itself moves later
        -- and every foe gets those turns to walk clear or shatter it.
        --
        -- Clamped here so a bad depth from anywhere (a stale network command, a bug) can never stretch
        -- the tell past what the ability allows, nor cut it below the floor: `min` is what a signature
        -- swing always commits to, `max` the cap. A missing depth (an AI cast that named none, an old
        -- peer) opens at the floor rather than being refused.
        local ticks = math.max(windLo, math.min(math.floor(windup or windLo), windHi))
        local held = ticks - windLo
        -- DEPTH vs TIME. `ticks`/`held` are the COMMITMENT -- how long she chose to hold, and how far
        -- past the floor -- and they are what every wind-up-scaled EFFECT is scored on (this weapon's
        -- bonus off `held`, a benediction's heal and the Long Prayer's radius off the total `windup`),
        -- so they are left undiscounted: the payoff is worth what the hold was worth. `timeTicks` is how
        -- long that hold actually takes on the TIMELINE, and it rides the same costMultiplier knob every
        -- other timeline cost does (Combat.abilityCost) -- Haste halves it, Mired doubles it, Graven
        -- shaves it. The two come apart precisely so a hasted wind-up lands the FULL payoff in HALF the
        -- tell: the player has half the time to walk clear, and the blow at the end is no softer.
        -- Floored at one tick -- a wind-up still has to hang for a beat.
        local timeTicks = math.max(1, math.floor(ticks * Status.costMultiplier(unit) + 0.5))
        if ab.consumesItem then item.quantity = math.max(0, (item.quantity or 1) - 1) end
        -- `windup` = the commitment the effect scales its payoff on (undiscounted); the TELL it actually
        -- hangs for is timeTicks, which is what the badge below and endTurn (the resolution slot) bill.
        unit.channel = { item = item, ab = ab, tx = tx, ty = ty, windup = ticks, held = held }
        Status.apply(combat, unit, "status_channeling", { duration = timeTicks + 1 })
        -- A view cue for the wind-up STARTING (the Channeling badge is silent -- hideLog). Pushed like
        -- every other fx event so the view sounds it once, on the real cast, and never on a dry-run
        -- preview (which does not drain fx). Both sides: an enemy Meteor Storm winding up rings it too.
        Combat.pushFx(combat, { type = "channel", unit = unit })
        -- `channelStatus`: a status the caster gains ON COMMIT and carries through the wind-up, for the
        -- one thing an `effect` cannot express -- an effect runs when the cast RESOLVES, and this has to
        -- land on the beat the tell goes up, before the enemy's turn to punish it. Declared rather than
        -- hooked, so the one weapon that wants it (weapon_held_breath: drawing makes the archer unseen)
        -- needs no fx context built at a point in the turn where there is nothing to aim one at.
        --
        -- It rides the wind-up's own length (the actual tell, so a hasted draw hides for the shorter
        -- time it is actually drawing), and it is applied AFTER `status_channeling`, so a status that
        -- interrupts channels cannot cancel the very cast it was granted by.
        if ab.channelStatus then
            Status.apply(combat, unit, ab.channelStatus, { duration = timeTicks + 1 })
        end
        -- `channelAfflict`: a status stamped on WHOEVER IS ALREADY STANDING in the wind-up's footprint
        -- the moment she commits -- the sibling of `channelStatus` (which lands on the caster) aimed one
        -- step outward, at the bodies the blow is telegraphed to sweep rather than at the caster. Declared
        -- here for the same reason: an `effect` runs when the cast RESOLVES, and a telegraph that only
        -- bites after the blow lands is not a telegraph.
        --
        -- What it buys is the difference between a tell you can ignore and a tell you have to answer. A
        -- wind-up aimed at open ground costs its target one step; one that makes the bodies under it
        -- COWER (weapon_first_motion's Cowering cuts their movement) shortens how far that step can carry
        -- them, so walking out of a committed blow is a decision rather than a reflex. Unlike a hazard it
        -- is NOT terrain: it lands once, on the occupants present at commit, so a foe who was already
        -- clear is never touched and the counterplay is to not be standing there when she commits.
        --
        -- Side-agnostic -- any body caught in the footprint, foe or friend, exactly as an unowned zone
        -- would have been -- and it rides the wind-up's own length by default, so a deeper hold cows
        -- longer. `{ status, duration }` overrides that; a bare id string takes the status blueprint's
        -- own default duration instead.
        if ab.channelAfflict then
            local ca = ab.channelAfflict
            local statusId = (type(ca) == "table" and ca.status) or ca
            local afflictFor = (type(ca) == "table" and ca.duration) or (timeTicks + 1)
            local seen, afflicted = {}, {}
            for _, cell in ipairs(Combat.aoeCells(combat, ab, tx, ty, unit)) do
                local occ = Combat.unitAt(combat, cell.x, cell.y)
                if occ and occ.alive and not seen[occ] then
                    seen[occ] = true
                    afflicted[#afflicted + 1] = occ
                    Status.apply(combat, occ, statusId, { duration = afflictFor })
                end
            end
            -- The flinch is a grip that lasts exactly as long as the wind-up hangs over its victims:
            -- it is lifted the moment she STOPS channeling and the blow lands (Combat.resolveChannel),
            -- because there is no longer an incoming swing to cower from -- the flat `duration` is only
            -- a fade-out for the interrupt case. Recorded on the channel so the resolve can find the
            -- bodies it stamped; an interrupt (Saber cut down mid-swing) deliberately does NOT lift it
            -- -- the fear rides the body, not the ground (tests/saber_debut_spec.lua).
            unit.channel.afflict = { status = statusId, units = afflicted }
        end
        -- The wind-up is an action too: a cast beat on begin-channel, then a second when it resolves
        -- (resolveCast, turns later). So a channeled spell reads both as it is loosed and as it lands.
        Combat.pushFx(combat, { type = "cast", unit = unit, tx = tx, ty = ty,
            support = Combat.isSupportAbility(ab), tags = Combat.fxTags(item, ab) })
        local channelEntry = Combat.logEvent(combat, "action",
            string.format("%s begins channeling %s.", unitName(unit), item.name or "an ability"), unit)
        -- Hang the item on the line so the combat-log panel can show its full tooltip on hover --
        -- what the spell being channeled actually is (same as the cast line in resolveCast).
        if channelEntry then channelEntry.item = item end
        -- Bill the TELL, not the depth: the resolution slot comes back after timeTicks, so a hasted
        -- wind-up resolves sooner while the effect still scores its bonus on the undiscounted `held`.
        endTurn(combat, unit, timeTicks, true)
        return true, { channeling = true }
    end

    return resolveCast(combat, unit, item, ab, tx, ty, nil, nil, nil, dest, spend)
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
                string.format("The charge arcs through the water into %s.", unitName(victim)), victim)
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
function resolveCast(combat, unit, item, ab, tx, ty, alreadyConsumed, windup, held, dest, spend)
    local target = Combat.unitAt(combat, tx, ty)
    local reserve = Combat.abilityReserve(unit, ab)

    -- A CAST WARD on the aimed body swallows the whole working before it begins (Status.castWardOn --
    -- the Sealed Reliquary). Gated on three things, and each of them is the counterplay:
    --
    --   * SINGLE TARGET. A blast that catches the warded unit among others goes straight past the
    --     ward, which is the standing answer to it -- an area effect does not aim at anybody.
    --   * HOSTILE. A ward that ate its own side's heals would be a curse; it only ever answers a cast
    --     from the other side of the field.
    --   * ONE CHARGE, spent here. The second spell that turn lands, so the ward buys a decision rather
    --     than a turn: which of your castings do you spend against it?
    --
    -- The caster still PAID -- cost, cooldown, the turn itself -- because it is the spell that was
    -- stopped, not the casting. Returning before the effect (and before the cast log's sub-events) is
    -- what makes this categorical rather than a mitigation: no damage, no status, no displacement, no
    -- summon. Combat.beginAnswers is deliberately not opened, since nothing happened to answer.
    if target and target.alive and target.side ~= unit.side and Combat.isSingleTarget(ab) then
        local ward = Status.castWardOn(target)
        if ward then
            Status.consumeBarrier(combat, target, ward)
            Combat.logEvent(combat, "status", string.format("%s's %s swallows %s whole.",
                unitName(target), ward.name or ward.id, item.name or "the working"), { target, unit })
            -- The turn still ends and still bills its initiative, on the same reasoning: the casting
            -- happened. Returning resolveCast's own (true, result) shape so every caller -- the battle
            -- state, the AI, the channel resolver -- reads a spent action exactly as it always does.
            endTurn(combat, unit, Combat.actionSpeed(unit, ab, item))
            return true, { damageDealt = 0, healed = 0, warded = true }
        end
    end

    -- AN AID WARD on the aimed body swallows a FRIENDLY working the same way (Status.aidWardOn -- the
    -- Sealed Hand). The mirror of the block above, side test inverted, and every clause of its fairness
    -- carries over unchanged: single-target only, one charge spent here, and the caster still paid.
    --
    -- Written as its own block rather than by loosening the test above, because the two are opposite
    -- purchases and must stay legible as such. The note above says a ward that ate its own side's heals
    -- "would be a curse" -- and that is exactly right: this one IS a curse, put on an enemy on purpose,
    -- so it is spelled out separately instead of making one gate ambiguous about whose side it serves.
    if target and target.alive and target.side == unit.side and Combat.isSingleTarget(ab) then
        local ward = Status.aidWardOn(target)
        if ward then
            Status.consumeBarrier(combat, target, ward)
            Combat.logEvent(combat, "status", string.format("%s's %s refuses %s.",
                unitName(target), ward.name or ward.id, item.name or "the working"), { target, unit })
            endTurn(combat, unit, Combat.actionSpeed(unit, ab, item))
            return true, { damageDealt = 0, healed = 0, warded = true }
        end
    end

    -- A visible "someone is acting" beat on the CASTER, pushed for every ability -- a heal, a summon,
    -- a self-buff, a strike alike -- so the view can lean/pulse the actor toward the targeted cell and
    -- glow it (green for a friendly cast, warm for an offensive one). Previously only a blow that drew
    -- blood animated the actor (the view derived a lunge from the damage cue); a cure or a summon
    -- resolved with the caster standing dead still. See ui/combat_fx.
    Combat.pushFx(combat, { type = "cast", unit = unit, tx = tx, ty = ty,
        support = Combat.isSupportAbility(ab), tags = Combat.fxTags(item, ab) })

    -- Effect context: bound helpers let a data-file effect compose damage/heal/AoE
    -- without touching this module. Results are accumulated for the caller/UI.
    -- Adjacency auras from neighboring items (e.g. a Fire Stone next to this weapon) fold extra
    -- tags into every hit and inflict their status on any target this cast damages.
    local auraTags, auraStatuses, auraMods = adjacencyAura(unit.char, item)
    withStatusLifesteal(unit, auraMods) -- the Red Thirst, folded in beside the grid's own charms
    -- The cast's effective magnitude (see castAmount): the ability's own declared amount, raised by a
    -- neighboring Alchemic Mastery charm and by any `frenzy` the ability declares. An amount-less
    -- effect (a pure summon or cleanse) stays nil, so a bonus never conjures damage out of nothing.
    -- Threaded into fx.amount (for effects that read it directly, e.g. a heal) AND into fx.damage's
    -- default opts.amount below -- Combat.dealDamage bases its hit on opts.amount/ab.damage, not on
    -- fx.amount, so a damage bomb needs it fed in there too.
    local effectiveAmount = castAmount(combat, unit, ab, tx, ty, auraMods)
    -- THE ARCANE CONDUIT (the Battlemage's): a charm that sharpens the items sitting NEXT TO IT in the
    -- grid, funded by the caster's banked Arcane rather than free. Read here, in resolveCast, which is
    -- the REAL cast path -- the damage preview goes through Combat.computeDamage and never reaches this,
    -- which is the only reason a spend may sit in this function at all.
    --
    -- The first aura in the game that costs something. Everything in the `aura` block has always been
    -- free once bought, so grid position was a layout puzzle; this makes it a spending decision, since
    -- the conduit can only sharpen as many casts as the caster has banked.
    -- TWO points per sharpen, and the reason is arithmetic rather than taste: Arcane banks off the
    -- `cast` tally, so a sharpened cast credits the pool one point on its way past. At a cost of one the
    -- conduit would net zero and simply always be on, which is not a spending decision, it is a passive
    -- wearing a resource bar. At two it is "cast twice, sharpen once".
    if effectiveAmount and Combat.chargePool(unit, "arcane") >= 2 then
        local conduit = Trait.flag(unit, "arcaneConduit")
        if conduit and conduit.item and Combat.gridAdjacent(unit.char, conduit.item, item) then
            Combat.spendCharge(unit, "arcane", 2)
            effectiveAmount = math.floor(effectiveAmount * (1 + (conduit.def.magnitude or 50) / 100))
            Combat.logEvent(combat, "action",
                string.format("%s's conduit sharpens the working.", unitName(unit)), unit)
        end
    end
    local result = { damageDealt = 0, healed = 0 }
    -- The initiative this action bills at end of turn. Read through Combat.actionSpeed rather than off
    -- `ab.speed` directly, so the number charged here is the number the timeline ghost and the hover
    -- preview already quoted -- a Quickened Sigil's discount included. An effect may still override it
    -- (Dual Wield sets the summed speed of the weapons it swings) through fx.setSpeed.
    local ctl = { speed = Combat.actionSpeed(unit, ab, item) }
    -- Latched while a TWINNED cast is resolving its fork, so the fork cannot fork again (see fx.damage).
    local twinning = false
    -- Declared before it is filled, so a helper below may call a sibling helper on the SAME table --
    -- `local fx = { ... }` would leave `fx` out of scope inside its own constructor, and the twin fork
    -- has to re-enter fx.damage to inherit the aura tags and lifesteal the first hit carried.
    local fx
    fx = {
        user = unit, target = target, item = item, combat = combat,
        tx = tx, ty = ty, -- the targeted cell, for tile-targeted abilities (e.g. placing a trap)
        dest = dest, -- a two-stage throw's chosen landing (Heave); nil for every single-aim ability
        amount = effectiveAmount, -- effects derive heal/status/restore magnitude from it
        -- The item's upgrade level (0..N). What a summon/hazard/trap/wall scales off: the stronger the
        -- forged item, the tougher the creature it calls and the harder/longer-lived the ground it lays.
        level = item.level or 0,
        -- The monk's charge as it stands at the moment of the cast, and the live spend that empties it
        -- (Combat.chi / Combat.spendChi). `spendChi()` with no argument takes ALL of it and hands back
        -- what it took, which is what a chi-dump scales its damage off; `spendChi(n)` takes a fixed
        -- bite. Routed through fx rather than called on the model directly so the damage PREVIEW, which
        -- runs this same effect against an inert context, reports the blow without draining the pool.
        chi = Combat.chi(unit),
        spendChi = function(n) return Combat.spendChi(unit, n) end,
        -- The general form of the two lines above: any named pool the caster's grid declares
        -- (Combat.chargeDef). `chargePool(key)` reads it, `spendCharge(key)` with no amount takes ALL
        -- of it and hands back what it took -- which is what a dump scales its payoff off. Routed
        -- through fx for the same reason chi is: the damage preview runs this effect against an inert
        -- context, and a pool that drained under the cursor would be a bug that read as one.
        --
        -- NOT named `fx.charge`: that is already the Charge ability's shove, further down this table.
        chargePool = function(key) return Combat.chargePool(unit, key) end,
        spendCharge = function(key, n) return Combat.spendCharge(unit, key, n) end,
        -- The battle purse (the player's campaign gold) as it stands, and the live spend that draws it
        -- down. `spendPurse(n)` takes up to n and hands back what it actually took, so a money ability
        -- scales its blow off the coin it could afford; with no purse injected (a duel, a draft run) it
        -- takes 0 and the ability is inert. Routed through fx for the same reason chi and the charge
        -- pools are: the damage preview runs this effect against an inert context, and a purse that
        -- drained under the cursor would be a bug that read as one. See Combat.spendPurse.
        purse = Combat.purseAvailable(combat, unit),
        spendPurse = function(n) return Combat.spendPurse(combat, unit, n) end,
        -- The wind-up this cast actually ran for, in TOTAL ticks (0 for an ability that resolves at
        -- once), and `held`: how many of those the caster CHOSE above the ability's floor. They are
        -- the same number for an ability whose floor is 0, and they differ for one that always
        -- commits to a base tell (The First Motion cannot be loosed shallower than its `min`).
        --
        -- Both are offered because scaling wants one or the other and neither can be derived from the
        -- other without also knowing the ability's own range -- which would send every effect back to
        -- the ability table for a number the engine already has in hand. Saber's signature reads
        -- `held`: patience made arithmetic, the longer she held the edge past her floor, the harder it
        -- lands (see the ability's effect and Combat.useItem's channel branch).
        windup = windup or 0,
        held = held or 0,
        -- The gold this cast was told to spend, chosen at the swing by the spend chooser (ui/panels/
        -- spend_chooser.lua) and threaded in through Combat.useItem, mirroring `windup`. A purchasable
        -- ability reads it and pays it (fx.spendPurse(fx.spend)) to size its blow -- The Gilded Wound
        -- carves one point of damage per ten. 0 when nothing was chosen (a non-purchasable cast, or the
        -- AI without a coffer to spend), so the effect simply lands nothing bought.
        spend = spend or 0,
        -- Flat, RAW damage: the gold IS the blow (The Gilded Wound). Raw so neither the caster's Power adds
        -- nor the target's armour subtracts -- ten gold buys one point delivered, exactly, whoever it lands
        -- on. Barriers and immunity still void it (the `raw` path honours those); nothing else touches it.
        -- Routed through fx like every mutation, so the damage preview prices it without dealing it.
        flatDamage = function(tgt, amount, tags)
            if not tgt then return 0 end
            local d = Combat.dealFlatDamage(combat, tgt, math.max(0, math.floor(amount or 0)), tags or { "physical" }, nil, user, { raw = true })
            result.damageDealt = result.damageDealt + d
            return d
        end,
        unitAt = function(x, y) return Combat.unitAt(combat, x, y) end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
        -- A free tile beside (x, y) to set something down on, or nil when the spot is hemmed in.
        -- Read-only, so the dry run may answer it truthfully.
        openTileNear = function(x, y) return Combat.openTileNear(combat, x, y) end,
        -- Who this cast catches -- the footprint's occupants, minus the caster's own side when a
        -- Careful Sigil sits beside it (Combat.castUnits). Every area effect reaches its victims
        -- through here, which is what makes one charm work on every blast in the game.
        aoeUnits = function() return Combat.castUnits(combat, ab, tx, ty, unit, auraMods) end,
        -- The cells this ability's AoE footprint covers (reads `ab.aoe`); an effect iterates them to
        -- paint the ground -- e.g. Fireball dropping a fire hazard on every blasted tile. Deliberately
        -- NOT narrowed by Careful: the sigil steers the blast, not the ground it leaves behind.
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
            -- TWINNED (a neighbouring Twinned Sigil): a single-target cast forks into one more body
            -- beside the one it was aimed at. Re-entered through this same closure, so the fork carries
            -- everything the original did -- the aura's granted tags, its on-hit status, its lifesteal
            -- -- rather than being a second, thinner spell nobody could account for.
            --
            -- `twinning` latches for the duration of the fork so the copy cannot itself fork: one twin,
            -- never a chain. It is a plain upvalue rather than a depth counter because there is exactly
            -- one level to guard, and a flag says that where a number would only imply it.
            if auraMods.twin and not twinning then
                local other = Combat.twinTarget(combat, unit, ab, tgt)
                if other then
                    twinning = true
                    fx.damage(other, { amount = opts.amount, tags = opts.tags })
                    twinning = false
                end
            end
            return d
        end,
        -- Paint a visual explosion on a tile (defaults to the caster's own): the detonation READ,
        -- separate from the wound. fx.damage already bursts on each body a blast catches, but a
        -- self-centred blast that catches nobody would otherwise go off invisibly -- so the bomb throws
        -- its own ring from where it stood (data/items/ability/ability_self_destruct.lua). Purely
        -- cosmetic; it deals nothing. `tags` shapes/tints it (fire -> orange bloom); nil falls back to
        -- the item's own fx tags.
        burst = function(x, y, tags, opts)
            Combat.spawnBurst(combat, x or unit.x, y or unit.y, tags or Combat.fxTags(item, ab), opts)
        end,
        heal = function(tgt, amount)
            if not tgt then return 0 end
            local h = Combat.applyHeal(combat, tgt, amount)
            result.healed = result.healed + h
            -- THE SHARED LEDGER (the Apothecary's): a heal that landed also lends the patient a share
            -- of the healer's own guard (status_lent_guard). Here rather than in Combat.applyHeal
            -- because this is the one heal path that knows WHO did the healing -- applyHeal is handed
            -- only a patient, which is exactly why the Crusader's allyHealed tally lives there and this
            -- does not. Envy's verb on the priest's action: healing that lends rather than only heals.
            if h > 0 and tgt ~= unit and Trait.flag(unit, "lendsGuard") then
                Status.apply(combat, tgt, "status_lent_guard", { applier = unit })
            end
            -- A heal that actually restored something banks a `healDone` on the CASTER (applyHeal
            -- itself knows only the patient) -- what a mercy signature gated on healing counts. An
            -- AoE heal that lands on three allies is three, which is what "heal N times" reads as.
            if h > 0 then Combat.tally(unit, "healDone", 1) end
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
        -- Finish a wind-up somebody ELSE is still holding: their channelled spell resolves on this beat
        -- rather than hanging over the board until their slot comes back around (Second Utterance spoken
        -- at a mage already mid-working). Returns true only if there was a channel to finish, so an
        -- effect can fall through to whatever it does for a body holding none.
        --
        -- Routed through Combat.resolveChannel -- the same door the caster's own slot would have opened
        -- -- so the spell reads the LIVE board, lifts its own channelAfflict, logs its resolution and
        -- banks its trait exactly as it always does. Nothing here is a second, thinner casting.
        --
        -- The tempo is settled inside endTurn's out-of-band branch (see the note there): the channeler
        -- pays the ability's speed from where it stands, so its next real turn lands on the tick it was
        -- always going to. What this buys is the deletion of the telegraph, never free initiative.
        hastenChannel = function(tgt)
            if not (tgt and tgt.alive and tgt.channel) then return false end
            Combat.logEvent(combat, "action",
                string.format("%s speaks for %s, and the working needs no more winding.",
                    unitName(unit), unitName(tgt)), { unit, tgt })
            Combat.resolveChannel(combat, tgt)
            return true
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
            opts = opts or {}
            -- ...and WHO set it, so a standing rule can key off the trapper rather than the faction
            -- (Trap.trigger's Quarry's Due). An arena-authored trap has no placer and never will.
            if opts.placer == nil then opts.placer = unit end
            local trap = Trap.place(combat, px, py, id, unit.side, opts)
            if trap and unit.side == "party" then
                Combat.logEvent(combat, "trap",
                    string.format("%s places %s at (%d, %d).", unitName(unit), trap.name or "a trap", px, py),
                    unit)
            end
            return trap
        end,
        -- Summon a hazard (fire/rain/sanctuary) on a tile, tagged with the caster's side (for the
        -- renderer's tint). Always visible; placeable on occupied ground; refreshes rather than
        -- stacks an identical hazard already there.
        placeHazard = function(px, py, id, opts)
            opts = opts or {}
            opts.side = opts.side or unit.side
            local zone = Hazard.place(combat, px, py, id, opts)
            -- THE WARDEN'S WRIT: a bearer whose charm declares `haltsOwnHazards` stamps every zone it
            -- lays as Halting (Hazard.onEnter reads the rider). Applied here rather than inside
            -- Hazard.place so it only ever catches ground a UNIT deliberately laid -- a hazard that
            -- spread on its own, or one the arena was authored with, is nobody's writ.
            if zone and Trait.flag(unit, "haltsOwnHazards") then zone.halts = true end
            return zone
        end,
        -- Raise a wall segment on a tile, owned by the caster's side (models/wall.lua). Summon Wall
        -- calls this once per tile of its 3x1 line; a tile that can't hold a wall (a unit on it,
        -- solid terrain, another wall) is silently skipped by Wall.place returning nil.
        placeWall = function(px, py, id, opts)
            opts = opts or {}
            opts.side = opts.side or unit.side
            return Wall.place(combat, px, py, id, opts)
        end,
        -- Stand a prop on a tile (models/prop.lua): a powder keg an alchemist rolls out, a crate. Takes
        -- NO side -- a prop belongs to nobody, and a keg the party set down will take the party's line
        -- apart just as readily. `opts.amount` scales its effect by the placing item's upgrade level
        -- (a forged keg blasts harder), exactly as it does for a trap. A tile that can't hold one -- a
        -- body on it, solid ground, another object -- is silently skipped by Prop.place returning nil.
        placeProp = function(px, py, id, opts)
            local prop = Prop.place(combat, px, py, id, opts)
            if prop then
                Combat.logEvent(combat, "trap",
                    string.format("%s sets down %s at (%d, %d).", unitName(unit),
                        prop.name or "an object", px, py), unit)
            end
            return prop
        end,
        -- Bury a fused charge on a tile, owned by the acting unit's side (the Saboteur's Sapper's Line).
        -- Combat.plantCharge already logs a party placement and stays quiet for an enemy's, the same
        -- rule placeTrap follows. Routed through fx (rather than called on Combat directly) so the two
        -- dry runs above can hand back an inert stand-in and never plant a real fuse under the cursor.
        plantCharge = function(px, py, opts) return Combat.plantCharge(combat, unit, px, py, opts) end,
        -- Set off every charge THIS unit has laid, at once (the Detonator), returning how many went up.
        detonate = function() return Combat.detonateAll(combat, unit) end,
        -- The prop or visible trap standing on a tile, as (object, kind) -- what a throw grabs when the
        -- tile it aimed at holds furniture rather than a body. Scoped to the actor's side, so it can
        -- never turn up a trap that side has not detected.
        objectAt = function(px, py) return Combat.throwableAt(combat, px, py, unit.side) end,
        -- Throw that object `distance` tiles straight away from the actor; a collision hurts both ends.
        -- The object-layer twin of fx.knockback (see Combat.hurlObject).
        hurl = function(obj, kind, distance, opts)
            if not obj then return 0 end
            return Combat.hurlObject(combat, unit, obj, kind, distance, opts)
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
        -- The caster SPENDS ITSELF on this cast: it comes off the field the instant the effect says
        -- so, and the cast it is still inside finishes without it (the Bomblet's Self-Destruct --
        -- data/items/ability/ability_self_destruct.lua).
        --
        -- Deliberately Combat.dismiss and not a death, for two reasons that point the same way.
        -- Nothing STRUCK it: there is no killer to credit, no corpse to raise from something that
        -- came apart, and no death-reflex on the field that a body hitting the ground should feed.
        -- And, decisively, dismissal fires no Trait.onDeath -- which is exactly what keeps a Volatile
        -- bearer from bursting TWICE, once as the ability that IS the blast and once as the trait
        -- that answers being killed by somebody else (data/traits/trait_volatile.lua).
        --
        -- Inert in both dry runs, so the AI never prices the body an effect spends: for the one kind
        -- of unit that carries this, its own life is the ammunition rather than a cost it should be
        -- talked out of paying (see the friendly-KILL term in models/ai.lua's outcomeScore).
        --
        -- Returns false for a caster already gone -- a chain of bursts can kill this one before its
        -- own line is reached (its neighbour's blast catches it), and the second removal is a no-op.
        expendSelf = function(text)
            if not unit.alive then return false end
            Combat.dismiss(combat, unit, text or string.format("%s is gone.", unitName(unit)))
            return true
        end,
        -- Reveal invisible units and tear down `illusion` walls across a set of cells (Dispel
        -- Illusions). Defaults to the ability's own AoE footprint around the aimed tile.
        dispel = function(cells)
            return Combat.dispel(combat, cells or Combat.aoeCells(combat, ab, tx, ty, unit))
        end,
        -- S5: strip blessings from ONE body. The single-target counterpart to fx.dispel above, which
        -- clears an area's illusions and reveals what is hiding in it -- a different job entirely, and
        -- the reason Confessor's Needle shipped admitting it could not do this half.
        --
        -- `n` caps how many come off (nil = all). Returns what was taken, so an effect can scale off it.
        dispelUnit = function(tgt, n) return Combat.dispelUnit(combat, tgt, n) end,
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
        --
        -- `opts.noClaim` skips the claim (the reservation is still bound): for the item whose summon is
        -- not what the item IS. A relic that exists to call a creature must fall silent while that
        -- creature stands, or the field fills up with wolves -- but a WEAPON that happens to plant
        -- something (data/items/weapon/weapon_marching_standard.lua drives its own colours into the
        -- ground as it thrusts) would be disarming its bearer for as long as the standard held, which
        -- is the opposite of what planting it should buy. Same word, same meaning, as ctx.summon's.
        summon = function(charId, px, py, opts)
            local summoned = Summon.spawn(combat, unit, charId, px, py, opts)
            if summoned and summoned.alive then
                if not (opts and opts.noClaim) then item.activeSummon = summoned end
                if reserve then Combat.reserve(unit.char, reserve.stat, reserve.amount, summoned) end
                Combat.summonRiders(combat, unit, summoned)
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
        -- Give ground: shove the CASTER `distance` tiles straight away from `tgt`, harmlessly (no
        -- collision damage, so backing into a wall simply doesn't move it). A hit-and-run attacker's
        -- step-back after landing a blow -- out of reach before the answer is thrown (weapon_wolf_fangs).
        retreat = function(tgt, distance)
            if not tgt then return 0 end
            return Combat.knockback(combat, tgt, unit, distance or 1, { amount = 0 })
        end,
        -- Drag a unit to a tile adjacent to the caster (needs line of sight).
        pull = function(tgt)
            if not tgt then return false end
            return Combat.pull(combat, unit, tgt)
        end,
        -- Drag a standing OBJECT (a prop, a visible trap) up against the caster -- the object-layer
        -- twin of fx.pull, as fx.hurl is fx.knockback's (see Combat.pullObject). A drag hurts nothing,
        -- so a barrel pulled in arrives intact.
        pullObject = function(obj, kind)
            if not obj then return false end
            return Combat.pullObject(combat, unit, obj, kind)
        end,
        -- Teleport the CASTER onto a tile, springing whatever it lands on (Leaping Crash's jump).
        teleportUser = function(x, y) return Combat.teleportUnit(combat, unit, x, y) end,
        -- Teleport SOMEBODY ELSE onto a tile. The general form of the line above, and kept separate
        -- from it rather than replacing it: the overwhelming majority of blink effects move their own
        -- caster, and a helper that made every one of them pass `fx.user` would be noise on all of
        -- them to serve the two (the Muster Rift, the Backward Glance) that move another body.
        -- Springs the arrival tile exactly as any other teleport does.
        teleport = function(tgt, x, y)
            if not tgt then return false end
            return Combat.teleportUnit(combat, tgt, x, y)
        end,
        -- Pin the target in front and drive it (and the caster behind it) `distance` tiles ahead,
        -- trampling anyone in the lane (Charge).
        charge = function(tgt, distance)
            if not tgt then return 0 end
            return Combat.charge(combat, unit, tgt, distance)
        end,
        -- The same rush aimed at a TILE: drive whoever stands there, or run the empty lane yourself
        -- (Combat.chargeInto). What the Charge ability casts through, and why it doubles as a way to
        -- move -- fx.charge above needs a body, and open ground is exactly what it cannot be pointed at.
        chargeInto = function(x, y, distance)
            return Combat.chargeInto(combat, unit, x, y, distance)
        end,
        -- FIELD CRAFTING (S4): put a freshly-made item into a unit's grid. Marked `ephemeral`, so it is
        -- real for this fight -- it stacks, casts, previews and can be stolen exactly like bought stock
        -- -- and is stripped on the way out (Combat.releaseClaims). Carrying field-brewed goods home
        -- would make a Herbalist a money printer between quests: brew, walk out, sell.
        --
        -- Returns the item, or nil when the grid is full. A full grid is a real answer rather than an
        -- error: the apothecary's satchel has nine cells like everyone else's, and deciding what to
        -- carry is the game. Callers narrate the failure.
        grantItem = function(tgt, itemId, opts)
            return Combat.grantItem(combat, tgt or unit, itemId, opts)
        end,
        -- Lift a random item off a unit (Combat.steal picks it; a Decoy volunteers itself).
        steal = function(tgt)
            if not tgt then return nil end
            return Combat.steal(combat, unit, tgt)
        end,
        -- Lay a foe's whole kit open (the Assayer's Eye): the battle UI may thereafter show its item
        -- grid and each item's tooltip. Pure knowledge -- it moves and costs nothing -- so it is safe
        -- to run on the dry-run/preview fx too (where it merely records that the ability reveals).
        reveal = function(tgt) Combat.revealInventory(combat, tgt) end,
        -- Rush a unit forward in the initiative order by cutting its current initiative. Mutating
        -- initiative straight from an effect mirrors what Stun does from a status hook.
        hasten = function(tgt, fraction)
            if not tgt then return 0 end
            tgt.initiative = tgt.initiative * (1 - (fraction or 0.5))
            return tgt.initiative
        end,
        -- A random integer in 1..n, drawn from this battle's own sequence (see Combat.roll), so a
        -- scattershot ability scatters the same way on a replay -- and identically on two machines
        -- watching one fight. What Meteor Storm rolls to pick its tiles, and any future dice.
        random = function(n) return Combat.roll(combat, n or 1) end,
        -- Strip every debuff from a unit (Cure). Returns the number removed.
        cleanse = function(tgt)
            if not tgt then return 0 end
            return Combat.cleanse(combat, tgt)
        end,
        -- The reachable corpse on a tile, or nil -- a harvestable body (Raise Dead / the Ledger's Due
        -- pick the body they stand over). An incapacitated body is NOT one; Revive reads fx.downedAt.
        corpseAt = function(x, y) return Combat.corpseAt(combat, x, y) end,
        -- The reachable INCAPACITATED body on a tile, or nil (Revive / Reviving Salts pick the body they
        -- stand over -- one still inside its window, which fx.reanimate then brings back).
        downedAt = function(x, y) return Combat.downedAt(combat, x, y) end,
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
        -- Hand `target` (the caster by default) `n` more actions, default 1: the turn re-opens instead
        -- of ending, and the tempo is banked and settled when it finally does (Combat.grantExtraAction).
        --
        -- IT MAY BE AIMED AT SOMEBODY ELSE, and what that means is worth stating, because this used to
        -- be caster-only on the grounds that "a unit whose turn is not open has no turn to re-open".
        -- That was half right. The grant sits on the body (`unit.extraActions`) and is spent by endTurn,
        -- so aiming it at an ally who is not acting does not re-open a closed turn -- it PROMISES their
        -- next one two actions instead of one. That is a real thing to hand somebody on a timeline
        -- where initiative is the only currency, and it is the shape "let another body act again" has
        -- to take here; an ability that wants it to arrive sooner as well pairs it with fx.hasten.
        grantExtraAction = function(n, target) return Combat.grantExtraAction(target or unit, n) end,
        -- Stash a battle-scoped fact ON THE CASTER (a wand's fire/frost half, the Unspent Blow's banked
        -- count, a planted standard). Effects must write such state THROUGH this helper rather than
        -- assigning `fx.user.<field>` directly: the two damage previews replay the very same effect and
        -- supply an INERT bank, so a hover neither advances the count nor flips the branch the effect
        -- takes (the flicker fx.spendCharge / fx.setSpeed avoid the same way). Reads stay a plain
        -- `fx.user.<field>` -- truthful in every builder because they mutate nothing.
        bank = function(key, value) if unit then unit[key] = value end end,
        -- The same stash, but ON THE ITEM rather than on its bearer: a purse that belongs to the relic
        -- and not to whoever is holding it this battle (the Gleaning Rod's charges, the Gleaner's
        -- Mantle's). Separate from fx.bank because the two answer different questions -- state banked on
        -- the unit follows the BODY and is battle-scoped, state banked on the item follows the OBJECT and
        -- survives being handed to somebody else. An effect must not write `fx.item.<field>` directly for
        -- exactly the reason it must not write `fx.user.<field>`: both damage previews replay the effect
        -- against the REAL item table, so a hover would empty the purse under the cursor.
        bankItem = function(key, value) if item then item[key] = value end end,
        -- Write a line straight into the combat log, for an ability whose entry must not read as
        -- what it actually is (a Decoy reports a move, not a cast -- see `ab.silent`). Hands back
        -- the entry, so an effect can keep a handle on a line it may later have to correct.
        log = function(kind, text, subjects) return Combat.logEvent(combat, kind, text, subjects) end,
        -- Clear every timer standing on a unit at once -- the trait cooldowns AND the per-item
        -- reflex timers, which are the same table keyed two ways (see Combat.setCooldown). What the
        -- Hour Returned spends itself to buy: not another cast, but every cast you have already made.
        -- Returns how many timers it wiped, so the effect can decline to narrate an empty refresh.
        clearCooldowns = function(tgt) return Combat.clearCooldowns(tgt) end,
        -- Put a unit back on the tile it stood on at the start of its previous turn (Combat.recall).
        -- Undo as a spell. Returns false when there is no remembered tile yet, or the ground it
        -- remembers is no longer free.
        recall = function(tgt) return Combat.recall(combat, tgt) end,
        -- Promise the party coin for this battle, over and above the spoils it earns (Combat.bounty).
        -- What a bounty pays out and what a corpse sold to the Ledger fetches.
        bounty = function(amount) return Combat.bounty(combat, amount) end,
        -- Consume a corpse outright: it leaves the field, unraisable and unrevivable. The other half of
        -- a transaction that turns a body into something else (the Ledger's coin), and deliberately
        -- separate from fx.bounty so the two can be priced apart.
        consumeCorpse = function(corpse) return Combat.consumeCorpse(combat, corpse) end,
    }

    -- Log the action itself before its effect runs, so the cast heads the sub-events it spawns
    -- (damage / heal / status / trap lines). Offensive casts read "attacks with", the rest "uses".
    -- A `silent` ability skips this and narrates itself through fx.log, so the log can lie about
    -- what just happened (the Decoy reports a move).
    if not ab.silent then
        local verb = (ab.target == "enemy") and "attacks with" or "uses"
        local entry = Combat.logEvent(combat, "action",
            string.format("%s %s %s.", unitName(unit), verb, item.name or "an item"), unit)
        -- Hang the item on the line so the combat-log panel can show its full tooltip on hover --
        -- what the weapon or spell that was just swung actually is.
        if entry then entry.item = item end
    end

    -- Hold what the effect provokes until the effect is done provoking it (see Combat.beginAnswers):
    -- a blow that shoves its target away answers from where the shove left it, not from where it landed.
    Combat.beginAnswers(combat)
    if ab.effect then ab.effect(fx) end

    -- Water quenches fire: a cast carrying the "water" tag douses any dousable hazard across its
    -- footprint (the AoE cells, or just the aimed cell). Runs after the effect so a water AoE that
    -- also lays down rain clears the fire it fell on. Uses the full cast tag set (item + ability).
    local castTags = collectTags(item, nil)
    -- THE RESONANT GRIP remembers what you last threw: the element of the most recent cast is kept on
    -- the caster so a weapon strike can carry it (see Combat.dealDamage). Recorded for everyone rather
    -- than only for a charm-holder, because it costs one field and a charm bought three turns later
    -- should not have to explain why it starts empty.
    for _, t in ipairs(castTags) do
        if Combat.ELEMENT_TAGS[t] then unit.lastCastElement = t end
    end
    local footprint = ab.aoe and Combat.aoeCells(combat, ab, tx, ty, unit) or { { x = tx, y = ty } }
    if hasTag(castTags, "water") then
        Hazard.douse(combat, footprint, castTags)
    end

    -- A DAMAGING cast breaks what STANDS in its footprint. Props are furniture, not bodies, so
    -- fx.aoeUnits never turns one up and a data-file effect that iterates its victims will never hit
    -- one -- which left a volley of arrows falling politely around a powder keg. Swept here instead,
    -- once, for every cast alike: the barrel's rule is "hit it and it goes off" (models/prop.lua), and
    -- a blast that covers its tile has hit it whatever element it was made of. A barrel (health 1)
    -- bursts and takes the ring with it; a tougher crate splinters down over several such hits.
    --
    -- Gated on the ability DECLARING damage rather than merely carrying a magnitude, so a placement or
    -- a heal that happens to overlap the furniture leaves it standing -- a fire working that only laid
    -- a hazard down does not detonate a keg it floated a flame over; catching it is then the standing
    -- fire's slow work, not the placement's. Props take the cast's raw magnitude (they have no defense
    -- and no tag mitigation -- Prop.damage), and Prop.at returns only the living, so a keg the chain
    -- already splintered is simply gone from a later cell and nothing is hit twice.
    if ab.damage and effectiveAmount and effectiveAmount > 0 then
        for _, c in ipairs(footprint) do
            local prop = Prop.at(combat, c.x, c.y)
            if prop then Prop.damage(combat, prop, effectiveAmount, unit) end
        end
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
    -- counter-cast is not billed to the initiative of the unit that provoked it. The on-hit answers the
    -- cast provoked are thrown first, in the order the blows landed, and then the on-cast ones -- the
    -- same order they ran in when the answers were still inline.
    Combat.endAnswers(combat)
    Trait.onCast(combat, unit, { item = item, ability = ab, tx = tx, ty = ty })
    -- ...and the field's own answer to a working having been done in it (the Gaunt Vigil). Fired after
    -- the caster's own hook, so a ward that punishes sorcery bites on the far side of a finished spell
    -- rather than into the middle of one.
    Trait.onAnyCast(combat, unit, { item = item, ability = ab, tx = tx, ty = ty })

    -- Remember the last PHYSICAL action, for the Understudy to repeat
    -- (data/items/ability/ability_understudy.lua). It is stamped onto every unit of the ACTING side
    -- rather than kept on the combat, and that is not redundancy -- an ability's `usable` gate is
    -- handed only (unit, item) and is required to stay a pure read of the unit and its grid
    -- (Combat.itemBlockReason), so a record it cannot reach is a record the greyed-out slot and the
    -- tooltip cannot honour. A handful of units per side makes the write cheaper than the back-
    -- reference it replaces.
    --
    -- Per side, so a copy is always of an ally's work and never of the thing that just hit you: that is
    -- what makes it a rehearsal rather than a second Counter Magic
    -- (data/traits/trait_counter_magic.lua answers the enemy's magic; this borrows your own side's
    -- muscle, and the two never overlap).
    --
    -- Weapons and abilities only, and only non-magical ones (Combat.isMagicItem: any mana in the price
    -- makes it sorcery). A potion, a summon or a worn charm is not a MOTION, and there is nothing in
    -- watching someone drink to learn. Stored by reference: the Understudy re-runs the very item, so a
    -- forged sword is copied at the level it was actually swung at.
    if (item.type == "weapon" or item.type == "ability") and not Combat.isMagicItem(item)
        and not Combat.isDepleted(item) then
        for _, u in ipairs(combat.units) do
            if u.side == unit.side then u.lastPhysical = item end
        end
    end

    -- Bank a class-tagged action on the actor's ledger (models/growth.lua, models/discipline.lua). A
    -- weapon strike, a spell, or a thrown consumable all land here. Only a real player roster member
    -- counts: `control == "player"` excludes AI escortees, and `not summoned` excludes summons (both
    -- use transient char instances that would never persist the ledger anyway).
    if Combat.isPlayerControlled(unit) and not unit.summoned then
        Combat.awardTechnique(combat, unit, item)
    end

    -- Using an item ends the turn: advance by (this turn's move cost) + the ability speed (or the
    -- speed an effect chose through fx.setSpeed -- Dual Wield's summed weapon speeds).
    --
    -- ...unless the ability is FREE, which bills no initiative and leaves the turn open. Distinct from
    -- fx.grantExtraAction, which hands the turn back only AFTER banking the full price of the action
    -- that closed it (endTurn's surge branch): one is free, the other is bought on credit. A free cast
    -- still paid its stamina or mana and still spent its stack -- what it did not spend is tempo.
    --
    -- The counter lives on the UNIT rather than on `combat.turn`, because Combat.itemBlockReason --
    -- which greys the slot and writes the tooltip -- is handed only (unit, item) and is required to
    -- stay a pure read of the unit and its grid. A counter it could not reach is a limit the player
    -- discovers by clicking a button that does nothing. Cleared in Combat.startTurn.
    --
    -- Guarded even though every free ability carries a resource cost: the cost bounds how often you can
    -- AFFORD to press it, never how many times per turn you may, and a full stamina bar spent inside
    -- one initiative slot is not a burst, it is a solo.
    if ab.free and Combat.freeActionsLeft(unit) > 0 then
        unit.freeActionsUsed = (unit.freeActionsUsed or 0) + 1
        -- A SOLE ACTION (Harrier's Bow) is free of initiative and free of the move, but it is NOT free
        -- of the turn's action: latch it so Combat.itemBlockReason refuses everything after it. The move
        -- stays open (it is gated on combat.turn.moved, which this never sets), so "fire, then ride"
        -- holds -- fire, then only ride. Battle Tonic declares no soleAction and keeps the whole turn.
        if ab.soleAction then unit.actionSpent = true end
    else
        endTurn(combat, unit, ctl.speed)
    end

    -- Consume one use: decrement the stack (a bundle of consumables), floored at 0. The spent
    -- slot STAYS in the inventory as an empty stack -- Combat.isDepleted then blocks activation
    -- until it's restocked (Character.addItem merges a fresh stack back in). Non-stacked items
    -- carry quantity 1, so this leaves an empty, greyed-out slot after their single use.
    if ab.consumesItem and not auraMods.preserve and not alreadyConsumed then
        item.quantity = math.max(0, (item.quantity or 1) - 1)
    end

    -- ...and one off every COATING that sharpened it (Combat.spendAuras). Unconditional where the line
    -- above is not: `alreadyConsumed` says the CAST's own stack was spent at channel-start, which has
    -- nothing to say about the vial beside it -- a coating is spent when the working it sharpened
    -- actually lands, and a channel lands here. Said out loud in the log, because a stack that dropped
    -- silently is a stack the player will swear they still had.
    for _, coating in ipairs(Combat.spendAuras(unit.char, item)) do
        if Combat.auraSpent(coating) then
            Combat.logEvent(combat, "action",
                string.format("%s's %s is used up.", unitName(unit), coating.name or "coating"), unit)
        end
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
    Status.remove(combat, unit, "status_channeling")
    -- Lift the wind-up's flinch: whoever was made to Cower under the telegraphed swing
    -- (channelAfflict) is released the moment she stops channeling, because the blow has now landed
    -- and there is no incoming swing left to cower from. Only on resolve -- an interrupt leaves it, so
    -- cutting Saber down does not un-flinch the body she stamped (tests/saber_debut_spec.lua).
    if pending.afflict then
        for _, occ in ipairs(pending.afflict.units) do
            if occ.alive then Status.remove(combat, occ, pending.afflict.status) end
        end
    end
    Combat.logEvent(combat, "action",
        string.format("%s's %s resolves.", unitName(unit), pending.item.name or "channel"), unit)
    local ok, info = resolveCast(combat, unit, pending.item, pending.ab, pending.tx, pending.ty, true,
        pending.windup, pending.held)
    -- SECOND UTTERANCE: a mage carrying the trait banks a free wind-up the moment a channel LANDS --
    -- never when one begins, and never when one is interrupted, so the charge is paid for by a spell
    -- that actually resolved. Granted after the cast rather than before so a caster cut down by its own
    -- working (an unsided blast under its feet) is not handed a buff on the way out.
    if ok and unit.alive and Trait.has(unit, "trait_second_utterance") then
        Status.apply(combat, unit, "status_second_utterance")
    end
    return ok, info
end

-- Cancel a channel in progress: drop the pending payload and the badge, and log the fizzle. A hard
-- commit -- the mana (and any consumable) spent to begin the channel are gone, NOT refunded, so an
-- interrupt is a fully-wasted cast. Idempotent (a multi-tile knockback calls it once). Returns true if
-- a channel was actually interrupted. `reason` is a short phrase for the log ("stunned", "displaced").
-- `steadfast` on the channelling ability refuses the interruption outright: the wind-up rides out any
-- hard control that lands on it (Stun, Freeze, a Silence on a mana channel). One weapon carries it --
-- weapon_kingsfall -- and it is the whole of what that weapon buys, so the flag lives on the ABILITY
-- rather than on the unit: a fighter is only unbreakable while swinging that particular greatsword, and
-- picking up a second channelled item does not inherit it.
--
-- Note the control itself still lands in full. Kingsfall's bearer is stunned, shoved down the order, and
-- swings anyway -- what it declines is the cancellation, never the status. That keeps the counterplay
-- honest: a stun aimed at a Kingsfall is not wasted, it is only insufficient.
function Combat.interruptChannel(combat, unit, reason)
    if not unit.channel then return false end
    -- VIGIL BEADS (the Theurge's): a bearer whose charm declares `steadfastChannels` cannot have ANY
    -- wind-up broken. The flag lives on the UNIT where `steadfast` lives on the ABILITY, and that is
    -- the whole difference between the two: Kingsfall makes one particular greatsword unbreakable and
    -- its bearer is ordinary the moment they put it down, while this makes the CASTER unbreakable and
    -- every channel they own inherits it. One is a weapon; this is a discipline.
    if Trait.flag(unit, "steadfastChannels") then
        Combat.logEvent(combat, "status",
            string.format("%s does not falter (%s).", unitName(unit), reason or "disrupted"), unit)
        return false
    end
    if unit.channel.ab and unit.channel.ab.steadfast then
        Combat.logEvent(combat, "status",
            string.format("%s does not falter (%s).", unitName(unit), reason or "disrupted"), unit)
        return false
    end
    unit.channel = nil
    Status.remove(combat, unit, "status_channeling")
    Combat.logEvent(combat, "status",
        string.format("%s's channel is interrupted (%s)!", unitName(unit), reason or "disrupted"), unit)
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
    local dist = Combat.cellGap(x, y, unit)
    if dist > Combat.abilityRange(combat, unit, ab) then
        return false, "out of range"
    end
    if dist < Combat.abilityMinRange(ab) then
        return false, "too close"
    end
    if ab.requiresSight and not Combat.unitHasSight(combat, unit, x, y) then
        return false, "no line of sight"
    end
    Combat.spendCosts(combat, unit, ab)

    -- Damage the trap by the weapon's attack stat (magical weapons use magicDamage). Traps have
    -- no defense, so this is the raw stat, floored.
    Combat.logEvent(combat, "trap", string.format("%s strikes %s.", unitName(unit), trap.name or "a trap"), unit)
    Combat.pushFx(combat, { type = "cast", unit = unit, tx = x, ty = y, support = false, tags = Combat.fxTags(weapon, ab) })
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
    local dist = Combat.cellGap(x, y, unit)
    if dist > Combat.abilityRange(combat, unit, ab) then return false, "out of range" end
    if dist < Combat.abilityMinRange(ab) then return false, "too close" end
    if ab.requiresSight and not Combat.unitHasSight(combat, unit, x, y) then
        return false, "no line of sight"
    end
    Combat.spendCosts(combat, unit, ab)

    Combat.logEvent(combat, "trap", string.format("%s strikes %s.", unitName(unit), wall.name or "a wall"), unit)
    Combat.pushFx(combat, { type = "cast", unit = unit, tx = x, ty = y, support = false, tags = Combat.fxTags(weapon, ab) })
    Wall.damage(combat, wall, Combat.computeTrapDamage(unit, weapon))

    endTurn(combat, unit, ab.speed or Combat.DEFAULT_SPEED)
    return true, { wall = wall }
end

-- Strike a prop at (x, y) with `weapon`: the prop analogue of Combat.strikeWall, and the ONLY verb an
-- explosive barrel has. Same shape as its two siblings -- validate range + affordability, spend, damage
-- the object by the weapon's attack stat, end the turn -- so shooting a keg from across the board is
-- the same click as breaking a wall, which is what makes "pop it at range" a move the player already
-- knows how to make. Props are always visible, so there is no visibility gate.
--
-- Note the range check runs against the weapon's OWN reach: a barrel is a legitimate target for a bow,
-- and that is the whole safe answer to a board littered with them. Returns (true, { prop }) or
-- (false, reason).
function Combat.strikeProp(combat, unit, weapon, x, y)
    if not unit.alive then return false, "dead" end
    local prop = Prop.at(combat, x, y)
    if not prop then return false, "no prop" end
    local ab = weapon and weapon.activeAbility
    if not ab then return false, "no ability" end
    local blocked = Combat.itemBlockReason(unit, weapon)
    if blocked then return false, blocked.reason end
    local dist = Combat.cellGap(x, y, unit)
    if dist > Combat.abilityRange(combat, unit, ab) then return false, "out of range" end
    if dist < Combat.abilityMinRange(ab) then return false, "too close" end
    if ab.requiresSight and not Combat.unitHasSight(combat, unit, x, y) then
        return false, "no line of sight"
    end
    Combat.spendCosts(combat, unit, ab)

    Combat.logEvent(combat, "trap",
        string.format("%s strikes %s.", unitName(unit), prop.name or "an object"), unit)
    Combat.pushFx(combat, { type = "cast", unit = unit, tx = x, ty = y, support = false, tags = Combat.fxTags(weapon, ab) })
    Prop.damage(combat, prop, Combat.computeTrapDamage(unit, weapon), unit)

    endTurn(combat, unit, ab.speed or Combat.DEFAULT_SPEED)
    return true, { prop = prop }
end

-- Strike whatever standing OBJECT is on (x, y) -- a conjured wall or a scattered prop -- without the
-- caller having to know which layer it is. Combat.objectAt already answers "something with HP is
-- standing there and it is not a body"; this is the verb that goes with it, and it exists because the
-- enemy planner (models/ai.lua) decides to break a thing in its way WITHOUT caring what kind of thing
-- it is. The player's own click path knows the kind from the tooltip it is already drawing and calls the
-- specific verb; a plan descriptor carries only a tile. Returns whatever the chosen verb returns:
-- (true, { wall | prop }) or (false, reason).
function Combat.strikeObject(combat, unit, weapon, x, y)
    local obj, kind = Combat.objectAt(combat, x, y)
    if not obj then return false, "no object" end
    if kind == "prop" then return Combat.strikeProp(combat, unit, weapon, x, y) end
    return Combat.strikeWall(combat, unit, weapon, x, y)
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
                string.format("%s's %s comes apart!", unitName(u), s.name or s.id), u)
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
--
-- The decision itself lives in models/ai.lua -- posture, rule list, and a scored search over
-- (stand tile, item, target). This stays as the entry point because it is the name the battle
-- state and the tutorial's scripted overrides already call, and the descriptor shape it returns
-- is the contract between the two. Required lazily: ai.lua reaches back into this module for
-- reach, targeting and previews, so a require at the top of either file would close a cycle.
function Combat.planEnemyAction(combat, unit)
    return require("models.ai").plan(combat, unit)
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

-- The tiles the living protectees stand on RIGHT NOW -- what a `defend` HUD marks. Unlike a
-- `reach`/`hold` objective's fixed ground, the thing a defend fight is fought over is a unit, and
-- units move: this reads their current cells so the wash follows the survivors rather than the
-- anchor region they happened to spawn on. Excludes summons for the same reason isProtectedAlive
-- does -- an impersonating duplicate is not the charge.
function Combat.protectedTiles(combat, charId)
    local tiles = {}
    for _, u in ipairs(combat.units) do
        if u.alive and u.side == "party" and u.char.id == charId and not u.summoned then
            tiles[#tiles + 1] = { x = u.x, y = u.y }
        end
    end
    return tiles
end

-- Resolve the arena objective to "win" / "loss" / nil. A total party wipe is always a
-- loss. Called after each action so the battle state can fire onWin/onLoss.
--
-- `obj.protect` is a *composable* loss condition, not a win type: it names a party-side
-- character (usually an escorted ally, see Arena.build's `spec.allies`) whose death fails
-- the battle whatever the win type is. That is what expresses an escort -- "hold for a while,
-- and the caravan must live" -- without exit tiles or pathing.
--
-- TIME IS TICKS, EVERYWHERE. A timed objective's `duration` is a count of ticks -- the same unit
-- `combat.clock` accumulates (elapsed INITIATIVE, see Combat.rebase) and the same unit the HUD quotes
-- beside the hourglass glyph. "Turns" is not a concept the player is ever shown, so it is not one an
-- objective is authored in either: a designer writes the tick count directly and the number on screen
-- is the number they wrote. (Status.TICKS_PER_TURN exists only for per-turn regen rates, not here.)

-- Is a living unit of `side` standing on any of `tiles` (the resolved ground of a `reach` or
-- `hold` objective -- see Arena.resolveRegion)? The one reader both tile objectives share.
function Combat.occupies(combat, tiles, side)
    for _, t in ipairs(tiles or {}) do
        for _, u in ipairs(combat.units) do
            if u.alive and u.side == side and u.x == t.x and u.y == t.y then return true end
        end
    end
    return false
end

-- Does the party CONTROL the objective ground right now? Standing on it is not enough: an enemy
-- with a boot on any of the same tiles contests it and the count stops. That is what makes `hold`
-- a fight over ground rather than a stopwatch you start by walking somewhere.
function Combat.holdsGround(combat, tiles)
    if not tiles or #tiles == 0 then return false end
    if Combat.occupies(combat, tiles, "enemy") then return false end
    return Combat.occupies(combat, tiles, "party")
end

-- Bank the ticks that just elapsed toward a `hold` objective, when the party held the ground for
-- them. Called from Combat.rebase, which is the only place that knows how much time passed --
-- Combat.evaluate runs after every action and would have no idea how long any of them took.
function Combat.accrueHold(combat, elapsed)
    local obj = combat.objective
    if not obj or obj.type ~= "hold" then return end
    if Combat.holdsGround(combat, obj.tiles) then
        combat.heldTicks = (combat.heldTicks or 0) + (elapsed or 0)
    end
end

-- ---------------------------------------------------------------------------
-- The `control` objective: a moving score node, contested by BOTH sides.
--
-- The multiplayer/draft ruleset. Unlike the authored one-sided objectives above, this is genuinely
-- symmetric: each side banks a point for every tick it SOLELY holds the node, the node relocates on
-- a schedule, and the higher score at the tick limit wins. It is the one objective a duel other than
-- killAll ever uses, so it answers for either side directly rather than mirroring the party's result.
--
-- Everything the node's POSITION depends on is a pure function of `combat.clock` and the authored
-- schedule -- never wall-clock time, never RNG drawn here -- because a live duel is lockstep and both
-- clients must agree on where the node is from the tick count alone, or the fight desyncs.
--
--   objective = {
--       type = "control",
--       maxTicks = 300,               -- the fight ends here; higher score wins
--       nodes = { <tileList>, ... },  -- waypoints; nodes[i] is a list of { x, y }
--       moveEvery = 60,               -- ticks between relocations (cycles through `nodes`)
--   }
-- A single fixed node is just `nodes = { tiles }` (or `tiles = ...`) with no `moveEvery`.
-- ---------------------------------------------------------------------------

-- Which waypoint is live right now, derived from the clock alone so two lockstep clients never
-- disagree. Cycles through `nodes` every `moveEvery` ticks; a single node (or no schedule) stays 1.
function Combat.controlNodeIndex(combat)
    local obj = combat.objective
    local nodes = (obj and obj.nodes) or {}
    local every = obj and obj.moveEvery
    if #nodes <= 1 or not every or every <= 0 then return 1 end
    return (math.floor((combat.clock or 0) / every) % #nodes) + 1
end

-- The tiles of the node the fight is currently fought over: the live waypoint, or the fixed region.
function Combat.controlTiles(combat)
    local obj = combat.objective
    if not obj or obj.type ~= "control" then return {} end
    local nodes = obj.nodes or {}
    if #nodes == 0 then return obj.tiles or {} end
    return nodes[Combat.controlNodeIndex(combat)] or {}
end

-- Which side, if either, SOLELY controls `tiles` right now: a boot from the other side contests it
-- and no one scores (the same rule holdsGround expresses for the one-sided `hold`, made two-sided).
-- Returns "party", "enemy", or nil (contested or empty).
function Combat.controlledBy(combat, tiles)
    local party = Combat.occupies(combat, tiles, "party")
    local enemy = Combat.occupies(combat, tiles, "enemy")
    if party and not enemy then return "party" end
    if enemy and not party then return "enemy" end
    return nil
end

-- Bank the ticks that just elapsed toward whichever side held the node across them. Called from
-- Combat.rebase (the only place that knows how much time passed). Records the last holder so a tied
-- score can be broken by who held the point last (see Combat.controlWinner).
function Combat.accrueControl(combat, elapsed)
    local obj = combat.objective
    if not obj or obj.type ~= "control" then return end
    combat.score = combat.score or { party = 0, enemy = 0 }
    local holder = Combat.controlledBy(combat, Combat.controlTiles(combat))
    if holder then
        combat.score[holder] = (combat.score[holder] or 0) + (elapsed or 0)
        combat.lastHolder = holder
    end
end

-- A side's banked control score.
function Combat.scoreFor(combat, side)
    return (combat.score or {})[side or "party"] or 0
end

-- Who wins a `control` fight on score: the higher total, then (tie) the side with more units still
-- standing, then (still tied) whoever held the node last, then nil for a true draw. The tie-break is
-- documented rather than incidental so both clients settle a photo finish identically.
function Combat.controlWinner(combat)
    local party, enemy = Combat.scoreFor(combat, "party"), Combat.scoreFor(combat, "enemy")
    if party > enemy then return "party" end
    if enemy > party then return "enemy" end
    local pa, ea = Combat.aliveCount(combat, "party"), Combat.aliveCount(combat, "enemy")
    if pa > ea then return "party" end
    if ea > pa then return "enemy" end
    return combat.lastHolder -- nil when neither has ever held it: a genuine draw
end

-- Ticks until the node hops to its next waypoint, or nil for a node that never moves (a single
-- waypoint, or no schedule). Derived from the clock alone, exactly as controlNodeIndex is, so the
-- countdown a player reads is the same one both lockstep clients would compute.
function Combat.controlMovesIn(combat)
    local obj = combat and combat.objective
    if not obj or obj.type ~= "control" then return nil end
    local nodes = obj.nodes or {}
    local every = obj.moveEvery
    if #nodes <= 1 or not every or every <= 0 then return nil end
    return every - ((combat.clock or 0) % every)
end

-- ---------------------------------------------------------------------------
-- The objective, read for the UI
-- ---------------------------------------------------------------------------

-- The marked ground the objective is currently decided on: the tiles the board washes amber/green
-- (ui/battle_map.lua drawObjective) and the tooltip describes. `control` follows its moving node, a
-- `defend` with a charge follows the body it is fought over (which walks), and the authored tile
-- objectives (`reach`/`hold`, and a `defend`'s anchor region) name fixed ground. Empty for an
-- objective decided on bodies rather than ground (killAll, assassinate, survive) -- and for a defend
-- whose charge has already fallen, where the loss is sealed and there is nothing left to mark.
function Combat.objectiveGround(combat)
    local obj = combat and combat.objective
    if not obj then return {} end
    if obj.type == "control" then return Combat.controlTiles(combat) end
    if obj.type == "defend" and obj.protect then return Combat.protectedTiles(combat, obj.protect) end
    return obj.tiles or {}
end

-- The time still owed on a timed objective, in TICKS, or nil for one that has no clock. `survive`
-- counts down the elapsed clock; `hold` counts only the ticks the party actually held the ground
-- (Combat.accrueHold), so its number stalls whenever the post is contested; `control` counts down to
-- its tick limit. `defend` is NOT here: it is wave-based, not timed (see Combat.allWavesArrived).
function Combat.objectiveRemaining(combat)
    local obj = combat and combat.objective
    if not obj then return nil end
    if obj.type == "survive" then
        return math.max(0, math.ceil((obj.duration or 0) - (combat.clock or 0)))
    elseif obj.type == "hold" then
        return math.max(0, math.ceil((obj.duration or 0) - (combat.heldTicks or 0)))
    elseif obj.type == "control" then
        return math.max(0, math.ceil((obj.maxTicks or 0) - (combat.clock or 0)))
    end
    return nil
end

local function tileIn(tiles, x, y)
    for _, t in ipairs(tiles or {}) do
        if t.x == x and t.y == y then return true end
    end
    return false
end

-- What the objective makes of the tile at (x, y), or nil when that tile is not marked ground. The
-- read behind the wash: which fight is being had over this square, and how it currently stands. The
-- board can only say "marked" and "counting" in two colours, so everything else about the contest --
-- who holds it, the scores, when the node hops -- has to be readable by hovering it.
--
-- Model-side and free of any UI, so the tooltip (ui/tile_tooltip.lua) has only to phrase what it is
-- handed, and so this can be tested headless:
--
--   { type,               -- the objective's type ("control" / "hold" / "reach" / "defend")
--     tiles,              -- all the marked ground (this tile is one of it)
--     party, enemy,       -- is either side standing on that ground right now
--     holder,             -- the side holding it ALONE ("party"/"enemy"), else nil (contested/empty)
--     playerSide,         -- the side the local player commands (a draft/PvP fight can be either)
--     remaining,          -- ticks still owed on the objective's clock, when it has one
--     movesIn, scores,    -- control only: the node's hop countdown, and both banked scores
--     who, protect }      -- the char id a reach / defend objective is pointed at
function Combat.objectiveTileInfo(combat, x, y)
    local obj = combat and combat.objective
    if not obj then return nil end
    local tiles = Combat.objectiveGround(combat)
    if not tileIn(tiles, x, y) then return nil end

    local info = {
        type = obj.type,
        tiles = tiles,
        party = Combat.occupies(combat, tiles, "party"),
        enemy = Combat.occupies(combat, tiles, "enemy"),
        playerSide = combat.playerSide or "party",
        remaining = Combat.objectiveRemaining(combat),
        who = obj.who,
        protect = obj.protect,
    }
    -- Sole occupancy is the whole rule both tile objectives turn on (holdsGround / controlledBy):
    -- one boot from the other side and nobody is holding anything.
    if info.party ~= info.enemy then info.holder = info.party and "party" or "enemy" end
    if obj.type == "control" then
        info.movesIn = Combat.controlMovesIn(combat)
        info.scores = { party = Combat.scoreFor(combat, "party"),
                        enemy = Combat.scoreFor(combat, "enemy") }
    end
    return info
end

-- Has `wave` finished sending, given its firing state? A one-shot is spent the moment it fires; a
-- `count`-capped recurrence once it has fired that many times; an uncapped `every` wave is NEVER spent,
-- because an endless tide is exactly what it was authored to be and a fight carrying one has to be won
-- some other way (a reach objective's synthesized trickle is the live example).
function Combat.waveSpent(wave, st)
    if not (wave and st) or (st.fires or 0) == 0 then return false end
    if not wave.every then return true end
    return wave.count ~= nil and st.fires >= wave.count
end

-- Has every reinforcement this fight owes already walked on? Asked by the two objectives whose end is
-- not in the player's hands while the board is empty -- `defend` (win once the last wave is dead) and
-- `survive` (same, below) -- so that no victory is awarded in the quiet before the next wave lands. No
-- waves at all reads as arrived, so a defend with only its opening set wins the moment that set falls.
--
-- Read off `combat.waveState` where there is one: a wave has arrived when it has FIRED, not when the
-- clock passes its `at`. The two used to be the same statement and no longer are -- a cleared survive
-- pulls the next muster forward off its tick (states/battle.lua), and a fight judged by the clock would
-- then sit on an empty field until the mark it already answered. The clock remains the fallback for a
-- combat with no firing state at all (a model-only caller, a fixture), where nothing has fired early
-- because nothing walks the waves on.
function Combat.allWavesArrived(combat, obj)
    local state = combat.waveState
    for i, w in ipairs((obj and obj.waves) or {}) do
        local st = state and state[i]
        if st then
            if not Combat.waveSpent(w, st) then return false end
        elseif (combat.clock or 0) < (w.at or 0) then
            return false
        end
    end
    return true
end

-- The side across the board. Two sides is the game; this exists so the rules below can be written
-- from a point of view instead of from the party's, and is not a step toward N-sided combat.
Combat.OPPOSING = { party = "enemy", enemy = "party" }

-- Is `side` finished -- nothing standing AND nobody left to send in? The one question the outcome rules
-- ask about a side's existence, so the bench is honoured everywhere at once: a party with a body still
-- benched has not lost, and neither has the enemy won by clearing the four in front of them. Identical
-- to "aliveCount == 0" for any side without a bench, which is every side but the party.
function Combat.eliminated(combat, side)
    return Combat.aliveCount(combat, side) == 0 and Combat.benchCount(combat, side) == 0
end

-- Has `side` won, lost, or neither? Returns "win", "loss", or nil for a fight still in progress.
--
-- Being wiped out is a loss for anyone, and killAll reads across the board, so those two rules --
-- the whole of a duel -- are genuinely symmetric and answer for either side.
--
-- The authored objectives are not, and are not pretending to be: `reach`, `hold`, `assassinate`,
-- `survive` and `protect` are written FOR the party by a quest, and asking whether the enemy has
-- achieved the party's objective is a question with no meaning. Campaign play only ever asks about
-- the party; a duel only ever uses killAll. If an objective is ever authored to be contested, this
-- is where it would have to grow a per-side statement of it.
function Combat.outcomeFor(combat, side)
    side = side or "party"
    local foe = Combat.OPPOSING[side] or "enemy"

    -- Wiped out -- unless somebody is still on the bench. A company of eight is a company of eight all
    -- the way down: the fight is over when there is no one left to send in, not when the four who
    -- happened to be standing have fallen. Only the party has a bench (Combat.benchCount), so this reads
    -- exactly as it always did for every other side. See docs/deployment.md.
    if Combat.eliminated(combat, side) then return "loss" end

    local obj = combat.objective or { type = "killAll" }

    -- `control` is the contested, two-sided objective the top comment said would one day have to grow
    -- a per-side statement. It is symmetric, so it is stated ONCE here for whichever side is asking,
    -- above the party-mirror clause below (which exists for the one-sided authored objectives). A wipe
    -- is still a loss for the wiped side (handled at the top) and a win for the last side standing;
    -- otherwise the tick limit decides it on score.
    if obj.type == "control" then
        if Combat.eliminated(combat, foe) then return "win" end -- last side standing takes it
        if (combat.clock or 0) >= (obj.maxTicks or math.huge) then
            local winner = Combat.controlWinner(combat)
            if winner == side then return "win" end
            -- The other side's win, or a true draw: both read the tick limit as a loss. A draw taking
            -- the loss slot is the documented floor of the tie-break -- nobody earned the round.
            return "loss"
        end
        return nil
    end

    -- Everything below this line is an objective a quest wrote for the party: a column to escort, a
    -- mark to kill, ground to hold. The other side is not pursuing its own version of it -- its job
    -- is to stop the party -- so its standing is exactly the party's, mirrored. Stated once here
    -- rather than threaded through every branch, because the branches themselves genuinely are
    -- about the party and reading them that way is correct.
    if side ~= "party" and obj.type ~= "killAll" then
        local theirs = Combat.outcomeFor(combat, "party")
        if theirs == "win" then return "loss" end
        if theirs == "loss" then return "win" end
        return nil
    end

    if obj.protect and not Combat.isProtectedAlive(combat, obj.protect) then
        return "loss"
    end

    if obj.type == "reach" then
        -- `who` names the ONE body that has to make it -- an escorted column, whose arrival is the
        -- whole job. Without it, an escort degenerates into a footrace the player wins by sprinting
        -- a scout across the line and leaving the wagons standing in the road.
        --
        -- Summons are excluded for the same reason `protect` and `assassinate` exclude them: a
        -- duplicate sharing the charge's `char.id` must not be able to finish the escort for it.
        if obj.who then
            for _, u in ipairs(combat.units) do
                if u.alive and u.side == "party" and u.char.id == obj.who and not u.summoned then
                    for _, t in ipairs(obj.tiles or {}) do
                        if u.x == t.x and u.y == t.y then return "win" end
                    end
                end
            end
            return nil
        end
        -- Any body across the line ends it. Deliberately not "every" body: the point of an
        -- extraction is getting THROUGH, and a rule that waits for stragglers turns the whole
        -- thing back into a killAll with extra walking.
        if Combat.occupies(combat, obj.tiles, "party") then return "win" end
        return nil
    elseif obj.type == "hold" then
        if (combat.heldTicks or 0) >= (obj.duration or math.huge) then return "win" end
        return nil
    elseif obj.type == "assassinate" then
        for _, u in ipairs(combat.units) do
            -- A summoned duplicate shares its origin's `char.id`, so it would otherwise read as the
            -- mark still standing. Only the real thing counts.
            --
            -- The mark is matched THROUGH a transform. A general who sheds its human body for its demon
            -- one (trait_boss_phases' `transform` response) is the SAME unit in a new shape, so its
            -- current `char.id` no longer matches the id the quest named. Reading the shape's stashed
            -- original (Transform.originalChar) keeps the mark stable across the swap -- without it the
            -- fight would end the instant a general phased, and its second form would never be fought.
            if u.alive and u.side == "enemy" and not u.summoned then
                local original = Transform.originalChar(u)
                if u.char.id == obj.target or (original and original.id == obj.target) then
                    return nil -- target still standing, in whichever body it is wearing
                end
            end
        end
        return "win"
    elseif obj.type == "survive" then
        -- Outlast a clock: win once the elapsed ticks pass the authored `duration`. The consecrated
        -- rite in data/quests/cathedral/quest_cathedral_slot_03.lua is the live user.
        if combat.clock >= (obj.duration or math.huge) then return "win" end
        -- ...or once there is nothing left to outlast. A cleared board with every reinforcement already
        -- spent means the fight is decided and the remaining ticks are dead air -- the player would be
        -- pressing Wait on an empty field to satisfy a clock that no longer measures anything.
        --
        -- Rarely the ending that fires, and deliberately: a survive is dealt an ENDLESS tide by default
        -- (Arena.normalizeObjective), and an uncapped recurrence is never spent, so the ordinary fight is
        -- won on the clock with demons still walking in. This branch is what the opt-out lands on -- an
        -- authored `waves` list that runs dry, or an explicit empty one -- plus the lull inside any
        -- finite tide, which spawnWaves answers by pulling the next muster forward instead of waiting.
        if Combat.eliminated(combat, foe) and Combat.allWavesArrived(combat, obj) then return "win" end
        return nil
    elseif obj.type == "defend" then
        -- A WAVE-based hold with a body to keep alive: win once every demon is defeated -- the whole
        -- board cleared AND every authored reinforcement wave already arrived (so a lull between the
        -- opening kill and the next wave landing is not a premature victory). The protectee is enforced
        -- by the `obj.protect` loss clause above; its death fails the fight whatever the board looks
        -- like. Unlike `survive` there is no clock to outlast -- the fight ends when the demons do.
        if Combat.allWavesArrived(combat, obj) and Combat.eliminated(combat, foe) then
            return "win"
        end
        return nil
    else -- killAll (default)
        if Combat.eliminated(combat, foe) then return "win" end
        return nil
    end
end

-- The fight's standing as the player sees it. `combat.playerSide` is the side the local player is
-- running -- "party" in every campaign battle, and in a duel the side this machine is holding, so
-- the same board reads as a win to one player and a loss to the other while the state underneath
-- them stays identical.
function Combat.evaluate(combat)
    return Combat.outcomeFor(combat, combat.playerSide or "party")
end

return Combat
