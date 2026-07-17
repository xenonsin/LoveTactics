-- Tests for tile tags (Combat.tileHasTag) and lightning conduction (Combat.conductLightning): the
-- water+electric combo's electric half. A tile's tags come from three sources at once -- terrain,
-- any hazard on it, and the statuses of whoever stands there -- and a lightning cast arcs out of its
-- footprint into every adjacent "conductable" tile, whichever source made it so. Pure logic, headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Hazard = require("models.hazard")
local Status = require("models.status")

-- A flat, all-walkable ground arena (mirrors tests/hazard_spec.lua's fixture).
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

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

-- Give `char` an ability item, clearing a grid cell first so a full loadout can't refuse it.
-- Returns the item instance.
local function grant(char, id, slot)
    local item = Item.instantiate(id)
    char.inventory[slot] = item
    return item
end

return {
    {
        name = "tileHasTag reads terrain, hazards and the occupant's statuses alike",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 5, 5) }, {})
            local knight = c.units[1]

            assert(not Combat.tileHasTag(c, 2, 2, "conductable"), "plain ground conducts nothing")
            assert(not Combat.tileHasTag(c, 99, 99, "conductable"), "a tile off the map conducts nothing")

            -- 1. Terrain: a river carries a charge on its own.
            c.arena.tiles[2][2].tags = { "conductable" }
            assert(Combat.tileHasTag(c, 2, 2, "conductable"), "water terrain conducts")

            -- 2. A hazard on the tile lends the tile its tags.
            assert(not Combat.tileHasTag(c, 3, 3, "conductable"), "dry before the cloud")
            Hazard.place(c, 3, 3, "hazard_rain")
            assert(Combat.tileHasTag(c, 3, 3, "conductable"), "a rain cloud makes its tile conduct")

            -- 3. The occupant's status: Wet declares tileTags = { "conductable" }.
            assert(not Combat.tileHasTag(c, 5, 5, "conductable"), "a dry unit's tile does not conduct")
            Status.apply(c, knight, "status_wet")
            assert(Combat.tileHasTag(c, 5, 5, "conductable"), "a Wet unit's tile conducts")
            Status.remove(c, knight, "status_wet")
            assert(not Combat.tileHasTag(c, 5, 5, "conductable"), "and stops once it dries off")
        end,
    },
    {
        name = "taggedCellsAround returns adjacent tagged tiles, deduped and excluding the footprint",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, {})
            -- Water at (4,4) and (5,4); the cast footprint is (4,5) and (5,5), directly below them.
            c.arena.tiles[4][4].tags = { "conductable" }
            c.arena.tiles[4][5].tags = { "conductable" }
            c.arena.tiles[5][5].tags = { "conductable" } -- inside the footprint: already hit, so skipped

            local cells = Combat.taggedCellsAround(c, { { x = 4, y = 5 }, { x = 5, y = 5 } }, "conductable")
            local got = {}
            for _, cell in ipairs(cells) do got[cell.x .. "," .. cell.y] = true end

            assert(got["4,4"], "the water above the first blasted cell is found")
            assert(got["5,4"], "and the water above the second")
            assert(not got["5,5"], "a footprint cell is never returned -- it already took the direct hit")
            assert(#cells == 2, "diagonals don't conduct and each tile is returned once, got " .. #cells)
        end,
    },
    {
        name = "a lightning cast arcs into an adjacent Wet foe standing beside its target",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 4) },
                { unit("character_bandit", 4, 4), unit("character_bandit", 5, 4) })
            local mage, direct, splash = c.units[1], c.units[2], c.units[3]

            Status.apply(c, splash, "status_wet")
            local before = splash.char.stats.health.current
            local untouched = direct.char.stats.health.current

            local jolt = grant(mage.char, "ability_jolt", 1)
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, jolt, direct.x, direct.y), "the Jolt lands on its target")

            assert(direct.char.stats.health.current < untouched, "the Jolt hit what it was aimed at")
            assert(splash.char.stats.health.current < before,
                "and arced through the soaked bystander's puddle")
        end,
    },
    {
        name = "the arc lands at CONDUCT_FACTOR of the cast's magnitude, not the full hit",
        fn = function()
            -- Two identical soaked bandits: one is Jolted directly, the other only conducts. The
            -- direct hit must be the harder of the two.
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 4) },
                { unit("character_bandit", 4, 4), unit("character_bandit", 5, 4) })
            local mage, direct, splash = c.units[1], c.units[2], c.units[3]

            Status.apply(c, direct, "status_wet")
            Status.apply(c, splash, "status_wet")
            local hp0, hp1 = direct.char.stats.health.current, splash.char.stats.health.current

            local jolt = grant(mage.char, "ability_jolt", 1)
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, jolt, direct.x, direct.y), "the Jolt lands")

            local directDmg = hp0 - direct.char.stats.health.current
            local arcDmg = hp1 - splash.char.stats.health.current
            assert(arcDmg > 0, "the arc dealt damage")
            assert(arcDmg < directDmg,
                string.format("an arc (%d) is weaker than the bolt itself (%d)", arcDmg, directDmg))
        end,
    },
    {
        name = "a lightning cast does not arc onto dry ground",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 4) },
                { unit("character_bandit", 4, 4), unit("character_bandit", 5, 4) })
            local mage, direct, dry = c.units[1], c.units[2], c.units[3]

            local before = dry.char.stats.health.current
            local jolt = grant(mage.char, "ability_jolt", 1)
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, jolt, direct.x, direct.y), "the Jolt lands")

            assert(dry.char.stats.health.current == before, "a dry bystander is untouched by the bolt")
        end,
    },
    {
        name = "the arc is side-agnostic: a charge in a puddle takes friend and foe alike",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 4), unit("character_knight", 5, 4) },
                { unit("character_bandit", 4, 4) })
            local mage, ally, foe = c.units[1], c.units[2], c.units[3]

            Status.apply(c, ally, "status_wet")
            local before = ally.char.stats.health.current

            local jolt = grant(mage.char, "ability_jolt", 1)
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, jolt, foe.x, foe.y), "the Jolt lands on the foe")

            assert(ally.char.stats.health.current < before,
                "the arc struck the party's own soaked knight too")
        end,
    },
    {
        name = "a non-lightning cast never arcs, however wet the ground is",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 4) },
                { unit("character_bandit", 4, 4), unit("character_bandit", 5, 4) })
            local mage, foe, splash = c.units[1], c.units[2], c.units[3]

            Status.apply(c, splash, "status_wet")
            local before = splash.char.stats.health.current

            local bolt = grant(mage.char, "ability_fire_bolt", 1)
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, bolt, foe.x, foe.y), "the bolt lands")

            assert(splash.char.stats.health.current == before,
                "a fire cast does not conduct through water")
        end,
    },
}
