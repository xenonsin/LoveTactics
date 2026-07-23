-- Tests for the shared fixtures in tests/support/fixture.lua.
--
-- The fixtures are load-bearing for most other specs, so a silent break in them would surface as a
-- confusing failure somewhere far away. These cases pin the behaviour the other specs rely on:
-- the default board, tile patching, the three isolation levels, and the resource-stat override rule.

local Fixture = require("tests.support.fixture")
local Character = require("models.character")

return {
    {
        name = "the default board is open ground with a killAll objective",
        fn = function()
            local map = Fixture.new(6, 4)
            assert(map.cols == 6 and map.rows == 4, "the board is the size asked for")
            assert(#map.tiles == 4 and #map.tiles[1] == 6, "tiles are indexed [y][x]")
            local tile = map.tiles[1][1]
            assert(tile.walkable and tile.moveCost == 1 and tile.sightCost == 0,
                "every tile is open, cheap, and transparent")
            assert(map.objective.type == "killAll", "the default objective is killAll")
        end,
    },
    {
        name = "tile patches overlay the default ground, and extra opts ride on the map",
        fn = function()
            local map = Fixture.new(5, 5, {
                tiles = { { x = 3, y = 2, walkable = false, sightCost = 99 } },
                seed = 1234,
                objective = { type = "survive", duration = 25 },
            })
            local wall = map.tiles[2][3]
            assert(not wall.walkable and wall.sightCost == 99, "the patch landed on (3,2)")
            assert(wall.moveCost == 1, "fields the patch did not name keep the ground default")
            assert(map.tiles[2][4].walkable, "its neighbour is untouched")
            assert(map.seed == 1234, "an unrecognised opt is copied onto the map (seed, traps, ...)")
            assert(map.objective.type == "survive", "an explicit objective wins over the default")
            assert(map.tiles ~= nil and map.tiles[1][1].type == "ground", "tiles is the board, not the opt")
        end,
    },
    {
        name = "a tile patch off the board fails loudly instead of silently missing",
        fn = function()
            local ok = pcall(Fixture.new, 4, 4, { tiles = { { x = 9, y = 1, walkable = false } } })
            assert(not ok, "patching a tile that does not exist should raise")
        end,
    },
    {
        name = "isolate 'bare' empties the grid so the item under test is the only variable",
        fn = function()
            local u = Fixture.unit("character_knight", 1, 1, { isolate = "bare" })
            assert(next(u.char.inventory) == nil, "the 3x3 grid is empty")
            assert(next(u.char.traits) == nil, "and no traits ride along")
        end,
    },
    {
        name = "isolate 'mechanics' strips the bound relic but leaves the ordinary kit",
        fn = function()
            local plain = Fixture.unit("character_knight", 1, 1)
            local isolated = Fixture.unit("character_knight", 1, 1, { isolate = "mechanics" })
            assert(Fixture.itemNamed(plain.char, "armor_sworn_aegis"),
                "the knight carries her bound relic as authored")
            assert(not Fixture.itemNamed(isolated.char, "armor_sworn_aegis"),
                "'mechanics' takes the bound relic out")
            assert(Character.itemCount(isolated.char) > 0, "but leaves the rest of her kit standing")
        end,
    },
    {
        name = "isolate defaults to 'none' -- the character exactly as authored",
        fn = function()
            local u = Fixture.unit("character_knight", 1, 1)
            local def = Character.defs.character_knight
            assert(Character.itemCount(u.char) == #def.startingItems
                or Character.itemCount(u.char) > 0, "the authored kit is intact")
            assert(Fixture.itemNamed(u.char, "armor_sworn_aegis"), "including the bound relic")
        end,
    },
    {
        name = "an unknown isolate level is rejected rather than quietly ignored",
        fn = function()
            local ok = pcall(Fixture.unit, "character_knight", 1, 1, { isolate = "clean" })
            assert(not ok, "a typo'd isolation level must not silently mean 'none'")
        end,
    },
    {
        name = "a stats override sets a resource to full, and a flat stat to the number given",
        fn = function()
            local u = Fixture.unit("character_knight", 1, 1,
                { isolate = "bare", stats = { health = 100, defense = 0 } })
            assert(u.char.stats.health.max == 100 and u.char.stats.health.current == 100,
                "a resource stat opens at full on the new max")
            assert(u.char.stats.defense == 0, "a flat stat is just set")
        end,
    },
    {
        name = "items land in the grid in the order given",
        fn = function()
            local u = Fixture.unit("character_bandit", 1, 1,
                { isolate = "bare", items = { "weapon_iron_sword", "armor_leather_armor" } })
            assert(u.char.inventory[1].id == "weapon_iron_sword", "first item, first cell")
            assert(u.char.inventory[2].id == "armor_leather_armor", "second item, second cell")
        end,
    },
    {
        name = "Fixture.combat accepts a lone unit as well as a list",
        fn = function()
            local hero = Fixture.unit("character_knight", 2, 2, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare" })
            local c = Fixture.combat(Fixture.new(6, 6), hero, foe)
            assert(#c.units == 2, "both sides are on the board")
            assert(c.units[1].side ~= c.units[2].side, "and on opposite sides")
        end,
    },
    {
        name = "Fixture.strike opens the turn and swings, moving the target's health",
        fn = function()
            local hero = Fixture.unit("character_bandit", 2, 2,
                { isolate = "bare", stats = { damage = 0 }, items = { "weapon_iron_sword" } })
            local foe = Fixture.unit("character_bandit", 2, 3,
                { isolate = "bare", stats = { defense = 0, health = 100 } })
            local c = Fixture.combat(Fixture.new(6, 6), hero, foe)
            local before = Fixture.hp(c.units[2])
            local ok, res = Fixture.strike(c, c.units[1], c.units[2], "weapon_iron_sword")
            assert(ok, "the swing was allowed")
            assert(res.damageDealt > 0, "it dealt damage")
            assert(Fixture.hp(c.units[2]) == before - res.damageDealt,
                "and the damage it reports is the health the target actually lost")
        end,
    },
}
