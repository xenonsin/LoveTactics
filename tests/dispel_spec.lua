-- Tests for Dispel Illusions (data/items/ability/ability_dispel_illusions.lua) and Combat.dispel:
-- it reveals invisible units and tears down illusion-tagged walls across its 3x3 footprint. Headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")
local Wall = require("models.wall")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

return {
    {
        name = "Combat.dispel reveals an invisible unit and destroys an illusion wall in the area",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("priest", 1, 1) }, { unit("bandit", 4, 4) })
            local bandit = c.units[2]
            Status.apply(c, bandit, "invisible")
            local wall = Wall.place(c, 4, 5, "illusory_wall")

            local cells = { { x = 4, y = 4 }, { x = 4, y = 5 } }
            local result = Combat.dispel(c, cells)
            assert(result.revealed == 1, "the invisible unit is revealed")
            assert(not Status.has(bandit, "invisible"), "and its Invisible is stripped")
            assert(result.wallsDestroyed == 1 and not wall.alive, "the illusion wall is shattered")
        end,
    },
    {
        name = "the Dispel Illusions ability sweeps its own 3x3 footprint",
        fn = function()
            local char = Character.instantiate("priest")
            char.inventory = {}
            Character.addItem(char, Item.instantiate("ability_dispel_illusions"))
            local c = Combat.new(arena(8, 8),
                { { char = char, x = 1, y = 1 } },
                { unit("bandit", 3, 3) })
            local u, bandit = c.units[1], c.units[2]
            Status.apply(c, bandit, "invisible")
            -- Two illusion walls: one inside the 3x3 centred on (3,3), one outside it.
            local inWall = Wall.place(c, 4, 3, "illusory_wall")
            local outWall = Wall.place(c, 6, 6, "illusory_wall")

            assert(Combat.useItem(c, u, char.inventory[1], 3, 3), "the dispel resolves")
            assert(not Status.has(bandit, "invisible"), "the hidden bandit is revealed")
            assert(not inWall.alive, "the wall inside the sweep is shattered")
            assert(outWall.alive, "a wall outside the footprint is untouched")
        end,
    },
    {
        name = "a non-illusion wall is not dispelled (only tagged illusions are)",
        fn = function()
            -- Register a plain structural wall with no illusion tag, then dispel over it.
            Wall.defs.test_stone = { name = "Stone Wall", health = 30, sightCost = 2,
                tags = { "structure" } }
            local c = Combat.new(arena(6, 6), { unit("priest", 1, 1) }, {})
            local wall = Wall.place(c, 3, 3, "test_stone")

            local result = Combat.dispel(c, { { x = 3, y = 3 } })
            assert(result.wallsDestroyed == 0, "dispel does not touch a non-illusion wall")
            assert(wall.alive, "the stone wall still stands")

            Wall.defs.test_stone = nil -- don't leak the fixture to other specs
        end,
    },
}
