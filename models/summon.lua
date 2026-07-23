-- Summoning: putting a new, fully-fledged character onto the battlefield mid-fight. Pure logic
-- (no love.graphics), so it loads under the headless tests, mirroring models/status.lua and
-- models/hazard.lua -- and like them it pulls models/combat.lua through a LAZY require inside its
-- functions, so combat.lua -> summon.lua stays a one-way dependency with no load-time cycle.
--
-- A summon is an ordinary unit: it lives in combat.units, takes turns in the initiative order, and
-- every query (unitAt / turnOrder / the renderer / the AI) finds it with no special casing. What
-- marks it out is a handful of fields Combat.addUnit carries:
--   * summoner -- the unit sustaining it. When that unit dies the summon vanishes (and any
--                 resource it reserved is released). This is what keeps `killAll` resolvable.
--   * control  -- "player" / "ai" / "none"; inherited from the summoner unless overridden, so an
--                 enemy-summoned wolf is AI-run for free and a player's is yours to command.
--   * fragile  -- any hit at all is lethal (a doppelganger, a decoy).
--   * summoned -- it is not a "real" combatant; Combat.evaluate ignores it for `assassinate`.
--   * summonRemaining -- ticks left before it fades on its own (from opts.duration). Absent on an
--                 indefinite summon, which stands until it is killed. See Summon.tick.
--
--   Summon.spawn(combat, caster, "character_wolf_grunt", x, y, { scaling = { health = 2 }, amount = 10 })
--   Summon.spawn(combat, caster, "character_fire_elemental", x, y, { duration = 24 })  -- fades on a timer
--   Summon.copy(combat, caster, x, y, { fragile = true, control = "none", decoy = true })
--
-- Being an ordinary unit cuts both ways: a summon ARRIVES on its tile (Combat.enterTile), so an
-- opposing trap beneath it springs and a hazard burning there catches it, exactly as if it had
-- walked in. Both calls therefore return a unit that may already be dead -- a fragile double planted
-- on a spike trap never draws breath. Check `unit.alive` before binding anything to it.
--
-- Reached from a data-file ability effect through `fx.summon` / `fx.copy` (see Combat.useItem),
-- which also binds the ability's reservation to the unit that comes back -- but only to a live one.

local Character = require("models.character")
local Item = require("models.item")

local Summon = {}

-- Copy a stat block: resource pools ({max,current}) are duplicated, everything else is a number.
local function copyStats(stats)
    local out = {}
    for key, value in pairs(stats) do
        if type(value) == "table" then
            out[key] = { max = value.max, current = value.current }
        else
            out[key] = value
        end
    end
    return out
end

-- Add `amount` to a stat, whether it's a flat number or a resource pool (a pool grows its max AND
-- its current, so a scaled summon arrives at full health rather than wounded).
local function addStat(stats, key, amount)
    local value = stats[key]
    if type(value) == "table" then
        value.max = value.max + amount
        value.current = value.current + amount
    else
        stats[key] = (value or 0) + amount
    end
end

-- Apply an ability's summon power to the summoned creature. Scaling is ADDITIVE and per-stat:
-- `scaling = { health = 2, damage = 0.5 }` with amount 10 grants +20 health and +5 damage. This
-- mirrors Combat.dealDamage's `damage + attackStat`: the ability's magnitude, added on top of a base.
local function applyScaling(stats, scaling, amount)
    if not (scaling and amount) then return end
    for key, factor in pairs(scaling) do
        addStat(stats, key, math.floor(amount * factor + 0.5))
    end
end

-- Overwrite stats from the ability's `stats` table. A pool override sets both max and current,
-- so `stats = { health = 60 }` means "this wolf has 60 health", not "60 max, still wounded".
local function applyOverrides(stats, overrides)
    for key, value in pairs(overrides or {}) do
        if type(stats[key]) == "table" then
            stats[key] = { max = value, current = value }
        else
            stats[key] = value
        end
    end
end

-- "inherit" (or an absent value) takes the summoner's controller, so a summon fights for whoever
-- called it without every ability having to say so.
local function resolveControl(control, summoner)
    if control == nil or control == "inherit" then return summoner.control end
    return control
end

-- Count every timed summon down by `elapsed` ticks and dismiss the ones that run out. Called from
-- Combat.rebase with the ticks that just elapsed, exactly like Status.tick and Hazard.tick -- so a
-- duration is measured in the same currency as a Burn or a patch of fire, not in turns.
--
-- A summon with no `duration` has no `summonRemaining` and is skipped: it stands until something
-- kills it, or until its summoner falls. `Combat.dismiss` does the unwinding (the reservation it
-- held is released, and the ability that called it becomes castable again).
function Summon.tick(combat, elapsed)
    if not elapsed or elapsed <= 0 then return end
    local Combat = require("models.combat")
    for _, unit in ipairs(combat.units) do
        if unit.alive and unit.summonRemaining then
            unit.summonRemaining = unit.summonRemaining - elapsed
            if unit.summonRemaining <= 0 then
                unit.summonRemaining = 0
                Combat.dismiss(combat, unit,
                    string.format("%s's time runs out and it fades away.", unit.char.name or "The summon"))
            end
        end
    end
end

-- Summon the character blueprint `charId` onto (x, y), sustained by `summoner`.
-- opts = {
--   stats    = { health = 60 },       -- flat overrides of the blueprint's stats
--   items    = { "weapon_fangs" },           -- replaces the blueprint's startingItems entirely
--   traits   = { "trait_blood_price" },     -- innate traits the CALL binds to the creature (see below)
--   scaling  = { health = 2 },        -- per-stat multipliers of `amount`, added on top
--   amount   = 10,                    -- the ability's summon power (fx.amount)
--   duration = 24,                    -- ticks it stands before fading; omit for an indefinite summon
--   control  = "player"|"ai"|"none"|"inherit",
--   timeless = true,                  -- an object, not a body: no turns, no slot in the turn order
--   fragile  = true, side = "party",
-- }
-- Returns the new unit.
function Summon.spawn(combat, summoner, charId, x, y, opts)
    local Combat = require("models.combat")
    opts = opts or {}

    local char = Character.instantiate(charId)
    if opts.items then
        char.inventory = {}
        for _, itemId in ipairs(opts.items) do
            Character.addItem(char, Item.instantiate(itemId))
        end
    end
    -- Traits the CALL binds to the creature, rather than ones the creature was born with: a price the
    -- summoner pays, a leash, a fuse. They belong to the ability because that is what struck the
    -- bargain -- the same blueprint summoned by a different ability owes nothing (data/traits/
    -- blood_price.lua). Trait.attach reads char.traits when the unit joins the field, so setting it
    -- here is enough; Character.instantiate leaves it nil, since a body's own reactions ride on its
    -- items instead (models/character.lua).
    char.traits = opts.traits
    applyOverrides(char.stats, opts.stats)
    applyScaling(char.stats, opts.scaling, opts.amount)

    local unit = Combat.addUnit(combat, char, opts.side or summoner.side, x, y, {
        control = resolveControl(opts.control, summoner),
        summoner = summoner,
        fragile = opts.fragile,
        summoned = true,
        duration = opts.duration,
        timeless = opts.timeless,
    })
    Combat.logEvent(combat, "system",
        string.format("%s summons %s.", summoner.char.name or "Unit", char.name or "a creature"),
        { summoner, unit })
    -- A conjured body occupies its tile like any other: an opposing trap under it springs, and a
    -- hazard burning there takes hold. Last, and after the announcement, because the creature may not
    -- survive its own arrival -- the caller must check `unit.alive` before binding anything to it.
    Combat.enterTile(combat, unit, x, y)
    return unit
end

-- Build a character from a LIVE one rather than from a blueprint, so the result carries that
-- character's current stats, wounds and all. Shared by both copy paths below.
--
-- Items are re-instantiated by id, skipping any the blueprint marks `noCopy`: without that a
-- doppelganger would carry the doppelganger ability and summon itself, and a decoy would carry
-- another decoy. Reservations are never copied -- they belong to the caster who committed them.
-- Innate traits DO come along: a copy of Wrath's general rages like the original.
local function buildCopyChar(src)
    local char = {
        id = src.id,
        name = src.name,
        sprite = src.sprite,
        stats = copyStats(src.stats),
        inventory = {},
        traits = src.traits,
        unarmed = Item.instantiate((src.unarmed and src.unarmed.id) or Character.DEFAULT_UNARMED),
    }
    for i = 1, Character.MAX_INVENTORY do
        local item = src.inventory[i]
        if item and not item.noCopy then
            char.inventory[i] = Item.instantiate(item.id, item.quantity)
        end
    end
    return char
end

-- Summon a duplicate of `summoner` itself -- same stats, same kit (a doppelganger), or a mute
-- double that only has to look right (a decoy).
--
-- `opts.decoy` tags the copy as the caster's decoy, so destroying it reveals them (see Combat's
-- death path).
function Summon.copy(combat, summoner, x, y, opts)
    local Combat = require("models.combat")
    opts = opts or {}

    local char = buildCopyChar(summoner.char)

    local unit = Combat.addUnit(combat, char, summoner.side, x, y, {
        control = resolveControl(opts.control, summoner),
        summoner = summoner,
        fragile = opts.fragile,
        summoned = true,
        duration = opts.duration,
    })
    -- Tagged before the tile can kill it: a decoy struck down must be recognised as one (the death
    -- path unmasks the caster), and a trap under it does exactly that.
    if opts.decoy then unit.decoyOf = summoner end
    -- A decoy must be indistinguishable from the real thing, so it announces nothing; the ability
    -- fakes a move line of its own (data/items/utility/utility_decoy.lua).
    if not opts.decoy then
        Combat.logEvent(combat, "system",
            string.format("%s conjures a double.", summoner.char.name or "Unit"), summoner)
    end
    Combat.enterTile(combat, unit, x, y) -- as in Summon.spawn: the double may not outlive its arrival
    return unit
end

-- Copy SOMEONE ELSE. Where Summon.copy duplicates the caster (pride: the mage admiring itself),
-- this puts a duplicate of an arbitrary `target` on the copier's side (envy: the wanting of another's
-- shape). It backs the Philosopher's Stone and the general of Envy alike -- the ability the player
-- buys at the top of the Crucible's shelf is the one used against them at the end of its line.
--
-- The copy is `summoned`, which is what keeps the objectives honest and needs no special casing: a
-- duplicate shares its origin's `char.id`, and both Combat.evaluate's assassinate branch and
-- Combat.isProtectedAlive already filter on that flag. Copying the mark does not spare it; copying an
-- escorted charge does not stand in for it.
--
-- `opts.summoner` defaults to `copier`, so killing the copier dismisses the copy -- an enemy that
-- wears your knight's face dies with the thing wearing it, `killAll` stays resolvable, and no
-- orphaned enemy unit walks around carrying a party member's id. Pass `summoner = false` for a copy
-- that must outlive its maker.
function Summon.copyOf(combat, copier, target, x, y, opts)
    local Combat = require("models.combat")
    opts = opts or {}

    local char = buildCopyChar(target.char)

    local summoner = copier
    if opts.summoner ~= nil then summoner = opts.summoner or nil end

    local unit = Combat.addUnit(combat, char, opts.side or copier.side, x, y, {
        control = resolveControl(opts.control, copier),
        summoner = summoner,
        fragile = opts.fragile,
        summoned = true,
        duration = opts.duration,
    })
    Combat.logEvent(combat, "system", string.format("%s takes the shape of %s.",
        copier.char.name or "Unit", target.char.name or "a foe"), { copier, target })
    Combat.enterTile(combat, unit, x, y) -- as above: the shape may not outlive its arrival
    return unit
end

return Summon
