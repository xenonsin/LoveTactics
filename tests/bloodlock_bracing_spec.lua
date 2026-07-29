-- Tests for Bloodlock Bracing (data/items/utility/utility_bloodlock_bracing.lua): a fighter charm that
-- reserves health at setup (Combat.applyReservations) and pays it back in Defense + Magic Defense. Pure
-- logic, runs headless. The reservation half of the contract is pinned harder in tests/reservation_spec.lua;
-- here we prove the ITEM drives it and that the armor lands with it.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

-- A fighter carrying a Bloodlock Bracing at `level`, with any bound signature relic stripped so the
-- bonus and reservation fixtures assert against the item alone (mirrors tests/reservation_spec.lua).
local function guardedFighter(level)
    local char = Character.instantiate("character_fighter")
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] and char.inventory[i].bound then char.inventory[i] = nil end
    end
    Character.addItem(char, Item.instantiate("utility_bloodlock_bracing", 1, level or 0))
    return char
end

local function battleWith(char, x, y)
    local c = Combat.new(arena(8, 8),
        { { char = char, x = x or 1, y = y or 1 } },
        { { char = Character.instantiate("character_bandit"), x = 8, y = 8 } })
    return c, c.units[1]
end

-- The fighter's folded Defense / Magic Defense with NO charm on the grid -- its own leather still
-- contributes, so Bloodlock Bracing's share is a delta, not the raw total.
local function baselineArmor()
    local char = Character.instantiate("character_fighter")
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] and char.inventory[i].bound then char.inventory[i] = nil end
    end
    local _, unit = battleWith(char)
    return unit.bonus.defense or 0, unit.bonus.magicDefense or 0
end

return {
    {
        name = "at setup Bloodlock Bracing reserves its health and grants Defense + Magic Defense",
        fn = function()
            local char = guardedFighter(0)
            local baseMax = char.stats.health.max
            local reserve = math.floor(baseMax * 0.20) -- the charm's 20%-of-max toll
            local c, unit = battleWith(char)
            local hp = unit.char.stats.health

            assert(Combat.reservedAmount(unit.char, "health") == reserve, "the charm reserves 20% of max health")
            assert(Combat.unreservedMax(unit.char, "health") == baseMax - reserve, "the ceiling drops by the reserve")
            assert(hp.current == baseMax - reserve, "and that share is spent out of current at the bell")
            assert(hp.max == baseMax, "but max itself is never touched (%-of-max math stays honest)")

            local baseDef, baseMDef = baselineArmor()
            assert(unit.bonus.defense == baseDef + 3, "level-0 Defense bonus is folded in")
            assert(unit.bonus.magicDefense == baseMDef + 3, "and Magic Defense with it")
        end,
    },
    {
        name = "reserved health cannot be healed back -- the ceiling holds",
        fn = function()
            local char = guardedFighter(0)
            local baseMax = char.stats.health.max
            local reserve = math.floor(baseMax * 0.20)
            local c, unit = battleWith(char)
            local hp = unit.char.stats.health
            hp.current = hp.current - 10 -- take a wound below the reserved ceiling

            local healed = Combat.applyHeal(c, unit, 999)
            assert(healed == 10, "a heal fills back only to the reserved ceiling")
            assert(hp.current == baseMax - reserve, "and never climbs past it")
        end,
    },
    {
        name = "a fighter that walks in wounded reserves only down to its last life, never lethal",
        fn = function()
            local char = guardedFighter(0)
            char.stats.health.current = 8 -- fewer than the 20%-of-max (14) the charm wants to lock
            local c, unit = battleWith(char)
            local hp = unit.char.stats.health

            assert(hp.current == 1, "the reserve stops one point short of death")
            assert(Combat.reservedAmount(unit.char, "health") == 7, "and only the 7 it could spare was locked")
            local baseDef, baseMDef = baselineArmor()
            assert(unit.bonus.defense == baseDef + 3 and unit.bonus.magicDefense == baseMDef + 3,
                "the armor still lands in full")
        end,
    },
    {
        name = "forging deepens the armor but never the toll",
        fn = function()
            local char = guardedFighter(10)
            local baseMax = char.stats.health.max
            local reserve = math.floor(baseMax * 0.20)
            local c, unit = battleWith(char)

            local baseDef, baseMDef = baselineArmor()
            assert(unit.bonus.defense == baseDef + 8, "a forged charm braces harder (level-10 Defense)")
            assert(unit.bonus.magicDefense == baseMDef + 8, "and warier (level-10 Magic Defense)")
            assert(Combat.reservedAmount(unit.char, "health") == reserve, "yet the health it costs is unchanged")
            assert(Combat.unreservedMax(unit.char, "health") == baseMax - reserve, "the ceiling drops by the same 20% toll")
        end,
    },
}
