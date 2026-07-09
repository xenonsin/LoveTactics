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
--
--   Summon.spawn(combat, caster, "wolf_grunt", x, y, { scaling = { health = 2 }, power = 10 })
--   Summon.copy(combat, caster, x, y, { fragile = true, control = "none", decoy = true })
--
-- Reached from a data-file ability effect through `fx.summon` / `fx.copy` (see Combat.useItem),
-- which also binds the ability's reservation to the unit that comes back.

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

-- Apply an ability's `power` to the summoned creature. Scaling is ADDITIVE and per-stat:
-- `scaling = { health = 2, damage = 0.5 }` with power 10 grants +20 health and +5 damage. This
-- mirrors Combat.dealDamage's `power + attackStat`, so "Power" reads the same everywhere: the
-- ability's magnitude, added on top of a base.
local function applyScaling(stats, scaling, power)
    if not (scaling and power) then return end
    for key, factor in pairs(scaling) do
        addStat(stats, key, math.floor(power * factor + 0.5))
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

-- Summon the character blueprint `charId` onto (x, y), sustained by `summoner`.
-- opts = {
--   stats   = { health = 60 },        -- flat overrides of the blueprint's stats
--   items   = { "fangs" },            -- replaces the blueprint's startingItems entirely
--   scaling = { health = 2 },         -- per-stat multipliers of `power`, added on top
--   power   = 10,                     -- the ability's Power (fx.power)
--   control = "player"|"ai"|"none"|"inherit",
--   fragile = true, side = "party",
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
    applyOverrides(char.stats, opts.stats)
    applyScaling(char.stats, opts.scaling, opts.power)

    local unit = Combat.addUnit(combat, char, opts.side or summoner.side, x, y, {
        control = resolveControl(opts.control, summoner),
        summoner = summoner,
        fragile = opts.fragile,
        summoned = true,
    })
    Combat.logEvent(combat, "system",
        string.format("%s summons %s.", summoner.char.name or "Unit", char.name or "a creature"))
    return unit
end

-- Summon a duplicate of `summoner` itself -- same stats, same kit (a doppelganger), or a mute
-- double that only has to look right (a decoy). The copy is built by hand rather than from a
-- blueprint so it carries the caster's CURRENT stats, wounds and all.
--
-- Items are re-instantiated by id, skipping any the blueprint marks `noCopy`: without that a
-- doppelganger would carry the doppelganger ability and summon itself, and a decoy would carry
-- another decoy. Reservations are never copied -- they belong to the caster who committed them.
--
-- `opts.decoy` tags the copy as the caster's decoy, so destroying it reveals them (see Combat's
-- death path).
function Summon.copy(combat, summoner, x, y, opts)
    local Combat = require("models.combat")
    opts = opts or {}
    local src = summoner.char

    local char = {
        id = src.id,
        name = src.name,
        sprite = src.sprite,
        stats = copyStats(src.stats),
        inventory = {},
        unarmed = Item.instantiate((src.unarmed and src.unarmed.id) or Character.DEFAULT_UNARMED),
    }
    for i = 1, Character.MAX_INVENTORY do
        local item = src.inventory[i]
        if item and not item.noCopy then
            char.inventory[i] = Item.instantiate(item.id, item.quantity)
        end
    end

    local unit = Combat.addUnit(combat, char, summoner.side, x, y, {
        control = resolveControl(opts.control, summoner),
        summoner = summoner,
        fragile = opts.fragile,
        summoned = true,
    })
    if opts.decoy then unit.decoyOf = summoner end
    -- A decoy must be indistinguishable from the real thing, so it announces nothing; the ability
    -- fakes a move line of its own (data/items/utility/decoy.lua).
    if not opts.decoy then
        Combat.logEvent(combat, "system",
            string.format("%s conjures a double.", summoner.char.name or "Unit"))
    end
    return unit
end

return Summon
