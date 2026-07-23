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

-- Unwrap a hit's `opts.inflicts` -- the status a blow CARRIES (see Combat.dealFlatDamage) -- into the
-- id and the Status.apply opts it rides with. Accepts a bare id ("status_stun") or a table naming one
-- ({ id = "status_stun", magnitude = 6 }). Returns nil for a hit that carries nothing.
--
-- Shared by the live path and BOTH damage previews, which is the whole reason it is a function: a
-- carried status is invisible to the tooltip's fx.applyStatus recorder, so a preview that didn't
-- unwrap it here would quietly stop naming the stun the player is about to land.
local function carriedStatus(opts)
    local carried = opts and opts.inflicts
    if not carried then return nil end
    if type(carried) == "string" then return carried, nil end
    return carried.id, carried
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
local function flatStat(unit, name)
    local base = unit.char.stats[name] or 0
    return base + ((unit.bonus and unit.bonus[name]) or 0) + Status.statBonus(unit, name)
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
        timeless = opts.timeless, -- stands outside the initiative timeline (Combat.inTimeline)
        -- Where this unit was put down. The AI's leashed postures measure from it (models/ai.lua:
        -- a `guard` holds a radius around its anchor, a `holdGround` never leaves it), so it has to
        -- be the tile it STARTED on and not wherever it happens to stand now.
        anchorX = x, anchorY = y,
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
        -- The side the local player is running, and so the side "win" and "loss" are spoken from.
        -- Always the party in campaign play; a duel sets it per machine, which is how one board
        -- reads as a victory to one player and a defeat to the other.
        playerSide = "party",
        -- This battle's own draw sequence, a function of the seed that built the board. Absent for
        -- a combat with no seeded arena (a scripted layout), which falls back to Combat.random.
        rng = (arena and arena.seed) and Combat.newRandom(arena.seed) or nil,
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
                anchorX = u.x, anchorY = u.y, -- start tile; the leashed AI postures measure from it
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
    -- Censers lay the ground they carry (Combat.layIncense), and it has to happen HERE rather than
    -- ride in on the Combat.rebase above: that call runs before this table exists, so the line above
    -- would throw its cloud away a moment after it was laid. From here on the bearer keeps it -- from
    -- Combat.enterTile as they move, and from Combat.rebase for one who never does.
    for _, unit in ipairs(combat.units) do
        Combat.layIncense(combat, unit)
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
        if Combat.inTimeline(u) and (not minInit or u.initiative < minInit) then minInit = u.initiative end
    end
    if not minInit then return end
    for _, u in ipairs(combat.units) do
        if Combat.inTimeline(u) then u.initiative = u.initiative - minInit end
    end
    combat.clock = combat.clock + minInit
    -- Bank the same elapsed time toward a `hold` objective, if the party held the ground across it.
    -- Here rather than in Combat.evaluate because this is the only place that knows how much time
    -- passed; evaluate runs per action and cannot tell a long one from a short one.
    Combat.accrueHold(combat, minInit)
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
-- silent until it counts back to 0 -- the recharge Combat.tickCooldowns runs from rebase, beside
-- Status.tick. Deliberately generic: any future "once every N ticks" effect hangs its key here
-- rather than inventing its own clock.
-- ---------------------------------------------------------------------------

-- Put `key` on cooldown for `ticks` on `unit` (refreshes to the longer of any existing remaining).
function Combat.setCooldown(unit, key, ticks)
    unit.cooldowns = unit.cooldowns or {}
    unit.cooldowns[key] = math.max(unit.cooldowns[key] or 0, ticks or 0)
end

-- Wipe every recharging timer on `unit` and report how many were standing. The one thing in this
-- game that gives an action BACK rather than making one bigger (data/items/utility/utility_hour_
-- returned.lua) -- and the reason it is worth its own helper is that "a cooldown" here is one table
-- keyed two ways: a trait's own id, and an item's reflex key (see Combat.itemCooldown). A refresh that
-- knew about only one of those would silently leave half a kit recharging.
function Combat.clearCooldowns(unit)
    if not (unit and unit.cooldowns) then return 0 end
    local n = 0
    for key in pairs(unit.cooldowns) do
        unit.cooldowns[key] = nil
        n = n + 1
    end
    return n
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
--   healDone                -- mended someone                  (the cast's fx.heal)
--   cast                    -- committed to an ability         (Combat.useItem)
--   turnTaken               -- began a turn                    (Combat.startTurn)
--   companionDamage         -- a summon of this unit drew blood (Combat.dealDamage)
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

-- Verb fragments for the auto-generated lock label, when an unlock declares no `text` of its own.
local UNLOCK_LABELS = {
    hitDealt = "Land", damageDealt = "Deal", hitTaken = "Weather", damageTaken = "Soak",
    kill = "Fell", allyDown = "Lose", healDone = "Mend", cast = "Cast", turnTaken = "Hold",
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
-- recharge feel), while a `once` unlock latches open for the rest of the battle. A `when`-gated or
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
            -- left alone. The trait's own onDamaged puts "unspent_heart" on cooldown for every wound
            -- taken, so the rate here is simply gated on that timer having run out -- which is the
            -- whole mechanic, and why the trait file itself has nothing in it but the shutting.
            --
            -- Sits with the recoveries rather than in the trait because this is where recovery lives:
            -- a trait has no per-tick hook (and deliberately shouldn't -- see models/trait.lua), and a
            -- status would put a countdown on the badge row that told the enemy exactly when the heart
            -- comes back.
            if Trait.has(u, "trait_unspent_heart") and not Combat.onCooldown(u, "unspent_heart") then
                Combat.restoreResource(u.char, "health", Combat.UNSPENT_HEART_REGEN * elapsed)
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
function Combat.freeEdgeTile(combat, edge)
    for _, t in ipairs(Combat.edgeTiles(combat, edge, 3)) do
        if not Combat.unitAt(combat, t.x, t.y) then return t.x, t.y end
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

-- The edge a point has drifted closest to. Used by `flank` to bring reserves in beside the party.
local function nearestEdge(combat, px, py)
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
        return nearestEdge(combat, px, py)
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
-- it crosses, so it holds while it keeps moving and fades once it stops. The Pilgrim's Sandals' mending
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
    -- An Overwatch stance is a one-turn watch: it lapses the moment its holder comes back around to
    -- act, so the unit chooses anew each turn whether to hold the line again.
    if unit then unit.overwatch = nil end
    -- Answers are paced by an escalating price rather than a cooldown (see Trait.answerCost): each
    -- answer since the bearer last acted costs double the one before it, and coming back around to
    -- act is what clears the tally. So a unit surrounded by three foes answers the first blow at
    -- price, the second at double and the third at quadruple, and runs itself dry holding the
    -- doorway -- the job the old per-trait recharge did, but visible in a pool the player can watch.
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
    end
    if unit then Status.onTurnStart(combat, unit) end
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
function Combat.overwatch(combat, unit)
    if not unit.alive then return false, "dead" end
    local behavior = Combat.waitBehavior(unit)
    unit.overwatch = { staminaPerShot = behavior.stamina or 0 }
    Combat.logEvent(combat, "action", string.format("%s takes overwatch.", unitName(unit)), unit)
    endTurn(combat, unit, behavior.speed or Combat.FOCUS_SPEED)
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
                    -- only). Standing objects and impassable terrain always bar the way.
                    local enemy = occ ~= nil and occ.side ~= unit.side and not phasing
                    -- A flier crosses any ground (walkable or not) and is never slowed by it; everyone
                    -- else pays what the terrain asks and stops at what it can't walk on. Objects (a
                    -- wall, a barrel) and enemies bar the way for both -- they are obstacles, not footing.
                    local passable = flying or cell.walkable
                    if passable and not enemy and not Combat.objectBlocksAt(combat, nx, ny) then
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

    local out = {}
    for _, s in ipairs(stands) do
        -- The same reach the cast gate computes (Combat.abilityRange, which Combat.useItem checks):
        -- the stand tile's sighted field bonus on top, a range-cutting debuff (Blind) taken back off,
        -- floored at 1. The malus has to bite HERE too or the band -- and every preview, cursor and
        -- click plan keyed off it -- lights tiles useItem then refuses, and the click dies saying
        -- nothing.
        local r = math.max(1, range + Combat.fieldRangeBonus(combat, requiresSight, s.x, s.y)
            - Status.rangeMalus(unit))
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
        if Combat.objectBlocksAt(combat, c.x, c.y) then return nil, "wall" end
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
        string.format("%s moves to (%d, %d).", unitName(unit), dest.x, dest.y), unit)
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
    local fromX, fromY = walk.unit.x, walk.unit.y -- the tile being vacated, for a trail laid behind
    walk.unit.x, walk.unit.y = tile.x, tile.y
    Combat.enterTile(combat, walk.unit, tile.x, tile.y, "walk", fromX, fromY)
    -- A unit walking into an opposing Overwatch stance's firing line is shot for it. Only a walk
    -- triggers this (not a knockback or a summon appearing), so it lives here rather than in enterTile.
    Combat.triggerOverwatch(combat, walk.unit)
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
    return steps
end

-- Walk `plan` out and hand back the route for a view to replay. See walkOut. Note this DRAINS the
-- cue queue as it goes -- the cues live in the returned steps instead, and the caller is expected to
-- feed them to its animation controller. Callers that just want the move to happen want moveUnit.
function Combat.runMove(combat, plan)
    return walkOut(combat, plan, true), combat.turn.moveCost
end

-- Move a unit to (x, y) if reachable this turn, all in one go. The headless equivalent of the
-- battle state's watchable walk (planMove -> beginMove -> stepMove per tile): same legality gate,
-- same traps sprung, same initiative owed. Leaves the cue queue alone, so a headless caller that
-- never drains is unaffected. Returns ok plus the move initiative it charged.
function Combat.moveUnit(combat, unit, x, y)
    local plan, reason = Combat.planMove(combat, unit, x, y)
    if not plan then return false, reason end
    walkOut(combat, plan, false)
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

-- Slide `unit` one tile by (dx, dy), triggering whatever it lands on. Returns false on a blocked
-- tile without moving it.
local function shoveStep(combat, unit, dx, dy)
    local nx, ny = unit.x + dx, unit.y + dy
    if not canShoveInto(combat, nx, ny) then return false end
    local fromX, fromY = unit.x, unit.y -- as Combat.stepMove: the vacated tile a trail lays behind on
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
function Combat.knockbackTile(combat, source, target, distance)
    if not (source and target) then return target and target.x, target and target.y end
    local dx, dy = signDominant(target.x - source.x, target.y - source.y)
    local x, y = target.x, target.y
    if dx == 0 and dy == 0 then return x, y end
    for _ = 1, (distance or 1) do
        if not canShoveInto(combat, x + dx, y + dy) then break end
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
    local amount = opts.amount or Combat.COLLISION_DAMAGE
    local dx, dy = signDominant(target.x - source.x, target.y - source.y)
    if dx == 0 and dy == 0 then return 0, false end

    -- Where the shove starts, so the view can glide the target out of it rather than snapping it
    -- across the lane (the model resolves the whole slide in this one atomic pass).
    local oX, oY = target.x, target.y
    local total = distance or 1
    local moved = 0
    for _ = 1, total do
        local ok, blocker, kind = canShoveInto(combat, target.x + dx, target.y + dy)
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
            return shoveDone(combat, target, oX, oY, moved), true
        end
        shoveStep(combat, target, dx, dy)
        moved = moved + 1
        Combat.logEvent(combat, "move",
            string.format("%s is knocked back to (%d, %d).", unitName(target), target.x, target.y), target)
        -- A trap or hazard on the tile it was driven onto may have finished it; stop the slide.
        if not target.alive then return shoveDone(combat, target, oX, oY, moved), false end
    end
    return shoveDone(combat, target, oX, oY, moved), false
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
    local dx, dy = signDominant(obj.x - source.x, obj.y - source.y)
    if dx == 0 and dy == 0 then return 0, false end

    local name = obj.name or "an object"
    local total = distance or 1
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
    local moved = 0
    while manhattan(source.x, source.y, target.x, target.y) > 1 do
        local dx, dy = signDominant(source.x - target.x, source.y - target.y)
        if not shoveStep(combat, target, dx, dy) then break end
        moved = moved + 1
        Combat.logEvent(combat, "move",
            string.format("%s is pulled to (%d, %d).", unitName(target), target.x, target.y), { target, source })
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
    if manhattan(user.x, user.y, target.x, target.y) ~= 1 then return 0 end -- must be pinned in front
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
    if math.floor(mitigated + 0.5) < 1 then rows.note = "Floored to the minimum of 1." end
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

    -- Every surviving ally of the fallen banks an `allyDown` -- what a signature that answers a
    -- comrade's death gates on (Combat.tally). A summon/decoy leaving the field is not a comrade lost,
    -- so only a real fallen combatant (one that leaves a corpse) sends the news.
    if not target.summoned and not target.decoyOf then
        for _, u in ipairs(combat.units) do
            if u.alive and u ~= target and u.side == target.side then Combat.tally(u, "allyDown", 1) end
        end
        -- ...and EVERYONE still standing, on both sides, heard the body drop. The tally above is news
        -- for one side; this is the field itself changing, and a reflex that feeds on death does not
        -- care whose it was (Trait.onAnyDeath -- data/traits/trait_blood_fever.lua). Gated by the same
        -- condition for the same reason: a conjuration winking out is not a body hitting the ground.
        Trait.onAnyDeath(combat, target)
    end

    -- Ground the dead unit was holding open goes with it: cut down a banner and its square stops being
    -- hallowed on this beat. The statuses it was granting are not stripped here -- Hazard.reap ends
    -- those the moment it finds no zone underfoot, so a zone that vanishes and a unit that walks away
    -- unwind through exactly the same path.
    Hazard.dropOwnedBy(combat, target)
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
    -- A body already going down mid-shove takes no further processing. When a killing blow folds a
    -- knockback in (the Iron Mace, the Sworn Aegis -- opts.knockback below), the target is marked
    -- mortally wounded and carried to where it will fall BEFORE killUnit finishes it -- and anything it
    -- slams into on the way re-enters here (a wall, a trap it is flung across). It is already doomed
    -- and killUnit is queued, so a second death path would fell it twice; skip it.
    if target.mortallyWounded then return 0 end
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
    Combat.pushFx(combat, { type = "damage", unit = target, amount = dmg,
        lethal = hp.current <= 0, attacker = attacker })
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
    local function inflictCarried()
        local id, carryOpts = carriedStatus(opts)
        if id then Status.apply(combat, target, id, carryOpts) end
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
    local magical = hasTag(tags, "magical")
    local atkStat = magical and "magicDamage" or "damage"
    local ab = item and item.activeAbility
    -- Additive: the ability's damage plus the attacker's attack stat (opts.amount overrides the
    -- declared damage for a one-off hit). Mitigation then subtracts the target's defense + resists.
    local base = (opts.amount or (ab and ab.damage) or 0) + flatStat(user, atkStat) + unarmedDamageBonus(user, item)
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
        -- A summon's blow also banks onto its summoner, so a signature can charge off the deeds of the
        -- creature it fields -- the Wolfsong Horn fills as Kaya's wolf draws blood (companionDamage).
        if user.summoner then Combat.tally(user.summoner, "companionDamage", dealt) end
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
    -- An UNCLOSING WOUND refuses the mend outright. Sat at the top of the one funnel every heal in the
    -- game runs through -- a spell, a potion, a Regeneration tick, a lifesteal drink, a Sanctified
    -- Presence -- so nothing has to learn the rule twice and nothing can route around it.
    local blocked = Status.blocksHealing(target)
    if blocked and (amount or 0) > 0 then
        Combat.logEvent(combat, "status",
            string.format("%s cannot be mended: %s.", unitName(target), blocked.name or blocked.id), target)
        return 0
    end
    -- A DEFERRAL banks the mend instead of landing it (the Sealed Hour). Negative on the ledger, since
    -- the ledger is denominated in damage -- and this is the whole reason a deferral is a bargain
    -- rather than a pure ward: mending banked under it does not save anyone in the meantime either.
    local deferral = Status.deferralOn(target)
    if deferral and (amount or 0) > 0 then
        Status.defer(deferral, -(amount or 0))
        Combat.logEvent(combat, "heal",
            string.format("%s's mending is held for later (%d).", unitName(target), amount or 0), target)
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
    return healed
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
        if u.side == "party" and not u.alive and u.corpse
            and not u.summoned and not u.decoyOf then
            local hp = u.char.stats.health
            hp.current = math.max(1, math.floor((hp.max or 0) * fraction))
            u.alive = true
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
            local carriedId, carryOpts = carriedStatus(opts)
            if carriedId then
                local cdef = Status.defs[carriedId]
                e.statuses[#e.statuses + 1] = { id = carriedId, def = cdef, opts = carryOpts }
                -- ...and flag the one thing the COUNTER preview needs to know about it: a carried
                -- status that shuts down reflexes means the on-hit answers won't fire, because it
                -- lands before them (Combat.dealFlatDamage). Recorded from the hit itself rather than
                -- sniffed out of e.statuses afterwards -- a stun applied the ordinary way, on the line
                -- AFTER the damage, does NOT suppress anything, and the two must not be confused.
                if cdef and cdef.disablesReactions then e.suppressesCounters = true end
                -- A carried stun/freeze shoves the target down the order the moment the blow lands, so
                -- project its delayed turn onto the timeline (Jolt, Ice Bolt inflict this way).
                shoveInitiative(tgt, carriedId, carryOpts)
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
        -- Inert like the rest, but it records WHERE the shove would leave its target, because that is
        -- the tile the target's own answer would be thrown from -- and a counter is gated on reach.
        -- Without this the hover promises a parry the mace then shoves out of range of (see
        -- Combat.previewCounters); with it, the panel and the live exchange agree.
        knockback = function(tgt, distance)
            if tgt then
                local e = entryFor(tgt)
                e.restsX, e.restsY = Combat.knockbackTile(combat, unit, tgt, distance or 1)
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
            end
            return 0
        end,
        pull = function() return false end,
        teleportUser = function() return false end,
        teleport = function() return false end,
        charge = function() return 0 end,
        steal = function() return nil end,
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
        grantExtraAction = function() return 0 end,
        log = function() end,
        -- Board-mutating, so inert here -- but each still answers with the SHAPE its live twin does, or
        -- an effect that goes on to branch on the result would take a different path in the preview
        -- than it takes in the cast (see the note on fx.level above: a dry run missing a helper
        -- swallows the effect from that point on, silently).
        clearCooldowns = function() return 0 end,
        recall = function() return false end,
        bounty = function() return 0 end,
        consumeCorpse = function() return false end,
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
            -- A carried status (see Combat.dealFlatDamage) bypasses fx.applyStatus, so the inventory
            -- tooltip has to read it off the hit itself to keep naming it.
            local carriedId, carryOpts = carriedStatus(opts)
            if carriedId then
                out.statuses[#out.statuses + 1] = { id = carriedId, def = Status.defs[carriedId], opts = carryOpts }
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
        retreat = function() return 0 end, -- the caster's own step-back moves nobody the row quotes
        pull = function() out.pull = true; return false end,
        teleportUser = function() return false end,
        teleport = function() return false end,
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
        -- Inert here: the dry run reports what an ability WOULD do, and "acts again" is not a thing
        -- the inventory tooltip can render. It is recorded so a describer could name it if one ever wants to.
        grantExtraAction = function(n) out.extraActions = (out.extraActions or 0) + (n or 1); return 0 end,
        log = function() end,
        -- There is no board and no clock here, so these report nothing and change nothing -- but they
        -- must EXIST, for the reason the whole of this table exists: a missing helper throws while the
        -- effect is still building its arguments, and the inventory tooltip goes blank rather than
        -- wrong, which is much harder to notice.
        clearCooldowns = function() return 0 end,
        recall = function() return false end,
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
                    local cell = combat.arena.tiles[y][x]
                    if cell.walkable and not Combat.unitAt(combat, x, y)
                        and not Combat.objectBlocksAt(combat, x, y) then
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
    if Combat.unitAt(combat, x, y) or Combat.objectBlocksAt(combat, x, y) then return false, "occupied tile" end
    if manhattan(unit.x, unit.y, x, y) > (mb.movement or 0) then return false, "out of range" end

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
function Combat.useItem(combat, unit, item, tx, ty, windup)
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
            return resolveCast(combat, unit, item, ab, tx, ty)
        end
        -- A chargeable wind-up (Saber's signature): the caster may pour EXTRA ticks into the swing
        -- beyond the base `channel`, up to `ab.windup.max`, and the effect reads how deep it was held
        -- (fx.windup) to scale its blow. A longer wind-up is a longer, breakable tell -- the extra
        -- ticks land on both the "channeling" badge's duration and the initiative the turn bills, so
        -- the resolution slot itself moves later and every foe gets those turns to walk clear or
        -- shatter it. Clamped here so a bad `windup` from anywhere (a stale network command, a bug)
        -- can never stretch the tell past what the ability allows.
        -- Clamp to the ability's own [min, max]: `min` is a floor a chargeable signature always pays
        -- (First Motion cannot be loosed at +0 -- see its `windup`), `max` the cap. A missing/short
        -- `windup` (a stale command, an AI cast, an old peer) is raised to the floor rather than refused.
        local lo = (ab.windup and ab.windup.min) or 0
        local hi = (ab.windup and ab.windup.max) or 0
        local extra = math.max(lo, math.min(math.floor(windup or lo), hi))
        local ticks = ab.channel + extra
        if ab.consumesItem then item.quantity = math.max(0, (item.quantity or 1) - 1) end
        unit.channel = { item = item, ab = ab, tx = tx, ty = ty, windup = extra }
        Status.apply(combat, unit, "status_channeling", { duration = ticks + 1 })
        -- The wind-up is an action too: a cast beat on begin-channel, then a second when it resolves
        -- (resolveCast, turns later). So a channeled spell reads both as it is loosed and as it lands.
        Combat.pushFx(combat, { type = "cast", unit = unit, tx = tx, ty = ty,
            support = Combat.isSupportAbility(ab) })
        Combat.logEvent(combat, "action",
            string.format("%s begins channeling %s.", unitName(unit), item.name or "an ability"), unit)
        endTurn(combat, unit, ticks, true)
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
function resolveCast(combat, unit, item, ab, tx, ty, alreadyConsumed, windup)
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
    withStatusLifesteal(unit, auraMods) -- the Red Thirst, folded in beside the grid's own charms
    -- The cast's effective magnitude (see castAmount): the ability's own declared amount, raised by a
    -- neighboring Alchemic Mastery charm and by any `frenzy` the ability declares. An amount-less
    -- effect (a pure summon or cleanse) stays nil, so a bonus never conjures damage out of nothing.
    -- Threaded into fx.amount (for effects that read it directly, e.g. a heal) AND into fx.damage's
    -- default opts.amount below -- Combat.dealDamage bases its hit on opts.amount/ab.damage, not on
    -- fx.amount, so a damage bomb needs it fed in there too.
    local effectiveAmount = castAmount(combat, unit, ab, tx, ty, auraMods)
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
        amount = effectiveAmount, -- effects derive heal/status/restore magnitude from it
        -- The item's upgrade level (0..N). What a summon/hazard/trap/wall scales off: the stronger the
        -- forged item, the tougher the creature it calls and the harder/longer-lived the ground it lays.
        level = item.level or 0,
        -- The EXTRA wind-up ticks poured into a chargeable channel (0 for everything else). Saber's
        -- signature reads it to scale the blow: patience made arithmetic -- the longer she held the
        -- edge, the harder it lands (see the ability's effect and Combat.useItem's channel branch).
        windup = windup or 0,
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
        heal = function(tgt, amount)
            if not tgt then return 0 end
            local h = Combat.applyHeal(combat, tgt, amount)
            result.healed = result.healed + h
            -- A mend that actually restored something banks a `healDone` on the CASTER (applyHeal
            -- itself knows only the patient) -- what a mercy signature gated on healing counts. An
            -- AoE mend that lands on three allies is three, which is what "heal N times" reads as.
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
        -- A random integer in 1..n, drawn from this battle's own sequence (see Combat.roll), so a
        -- scattershot ability scatters the same way on a replay -- and identically on two machines
        -- watching one fight. What Meteor Storm rolls to pick its tiles, and any future dice.
        random = function(n) return Combat.roll(combat, n or 1) end,
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
        -- Hand the caster `n` more actions this turn (default 1): the turn re-opens instead of ending,
        -- and the tempo is banked and settled when it finally does (Combat.grantExtraAction). Granted
        -- to the CASTER rather than to a target, which is the only shape the timeline can honour -- a
        -- unit whose turn is not open has no turn to re-open.
        grantExtraAction = function(n) return Combat.grantExtraAction(unit, n) end,
        -- Write a line straight into the combat log, for an ability whose entry must not read as
        -- what it actually is (a Decoy reports a move, not a cast -- see `ab.silent`). Hands back
        -- the entry, so an effect can keep a handle on a line it may later have to correct.
        log = function(kind, text, subjects) return Combat.logEvent(combat, kind, text, subjects) end,
        -- Clear every recharging thing on a unit at once -- the trait cooldowns AND the per-item
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
    -- what makes it a rehearsal rather than a second Perfect Recall
    -- (data/traits/trait_perfect_recall.lua answers the enemy's magic; this borrows your own side's
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
    Combat.logEvent(combat, "action",
        string.format("%s's %s resolves.", unitName(unit), pending.item.name or "channel"), unit)
    local ok, info = resolveCast(combat, unit, pending.item, pending.ab, pending.tx, pending.ty, true, pending.windup)
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
function Combat.interruptChannel(combat, unit, reason)
    if not unit.channel then return false end
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
    Combat.spendCosts(combat, unit, ab)

    -- Damage the trap by the weapon's attack stat (magical weapons use magicDamage). Traps have
    -- no defense, so this is the raw stat, floored.
    Combat.logEvent(combat, "trap", string.format("%s strikes %s.", unitName(unit), trap.name or "a trap"), unit)
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
    Combat.spendCosts(combat, unit, ab)

    Combat.logEvent(combat, "trap", string.format("%s strikes %s.", unitName(unit), wall.name or "a wall"), unit)
    Combat.pushFx(combat, { type = "cast", unit = unit, tx = x, ty = y, support = false })
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
    local dist = manhattan(unit.x, unit.y, x, y)
    if dist > Combat.abilityRange(combat, unit, ab) then return false, "out of range" end
    if dist < Combat.abilityMinRange(ab) then return false, "too close" end
    if ab.requiresSight and not Combat.hasLineOfSight(combat, unit.x, unit.y, x, y) then
        return false, "no line of sight"
    end
    Combat.spendCosts(combat, unit, ab)

    Combat.logEvent(combat, "trap",
        string.format("%s strikes %s.", unitName(unit), prop.name or "an object"), unit)
    Combat.pushFx(combat, { type = "cast", unit = unit, tx = x, ty = y, support = false })
    Prop.damage(combat, prop, Combat.computeTrapDamage(unit, weapon), unit)

    endTurn(combat, unit, ab.speed or Combat.DEFAULT_SPEED)
    return true, { prop = prop }
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

-- Have all of a wave-based `defend` fight's reinforcement waves walked on? A wave arrives once the
-- clock passes its `at` tick (states/battle.lua spawnWaves runs BEFORE this fight is judged, so the
-- moment the clock reaches the mark the bodies are already on the board). "All arrived" is therefore
-- just the clock reaching the last wave's tick. Combined with a cleared board it is the wave-based
-- win: no victory is awarded in the quiet before the next wave lands. No waves at all reads as arrived,
-- so a defend with only its opening set wins the moment that set falls.
function Combat.allWavesArrived(combat, obj)
    for _, w in ipairs((obj and obj.waves) or {}) do
        if (combat.clock or 0) < (w.at or 0) then return false end
    end
    return true
end

-- The side across the board. Two sides is the game; this exists so the rules below can be written
-- from a point of view instead of from the party's, and is not a step toward N-sided combat.
Combat.OPPOSING = { party = "enemy", enemy = "party" }

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

    if Combat.aliveCount(combat, side) == 0 then return "loss" end

    local obj = combat.objective or { type = "killAll" }

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
            if u.alive and u.side == "enemy" and u.char.id == obj.target and not u.summoned then
                return nil -- target still standing
            end
        end
        return "win"
    elseif obj.type == "survive" then
        -- Outlast a clock: win once the elapsed ticks pass the authored `duration`. The consecrated
        -- rite in data/quests/rite_of_ashes.lua is the live user.
        if combat.clock >= (obj.duration or math.huge) then return "win" end
        return nil
    elseif obj.type == "defend" then
        -- A WAVE-based hold with a body to keep alive: win once every demon is defeated -- the whole
        -- board cleared AND every authored reinforcement wave already arrived (so a lull between the
        -- opening kill and the next wave landing is not a premature victory). The protectee is enforced
        -- by the `obj.protect` loss clause above; its death fails the fight whatever the board looks
        -- like. Unlike `survive` there is no clock to outlast -- the fight ends when the demons do.
        if Combat.allWavesArrived(combat, obj) and Combat.aliveCount(combat, foe) == 0 then
            return "win"
        end
        return nil
    else -- killAll (default)
        if Combat.aliveCount(combat, foe) == 0 then return "win" end
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
