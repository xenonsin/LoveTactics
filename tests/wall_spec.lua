-- Tests for the wall subsystem (models/wall.lua) and its combat integration: a wall bars movement,
-- screens line of sight, can be struck down like a trap, and fades on its timer. Headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
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
        name = "a wall bars movement onto its tile (reachable routes around it)",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("knight", 1, 1) }, {})
            local knight = c.units[1]
            -- Wall the tile directly to the knight's right.
            assert(Wall.place(c, 2, 1, "illusory_wall"), "the wall is placed")

            local reach = Combat.reachable(c, knight)
            assert(reach["2,1"] == nil, "the walled tile is not reachable")
            -- The knight can still get below it (open ground), so it is not simply stuck.
            assert(reach["1,2"] ~= nil, "an open neighbour is still reachable")
        end,
    },
    {
        name = "a wall screens line of sight through its tile",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("archer", 1, 1) }, { unit("bandit", 1, 3) })
            assert(Combat.hasLineOfSight(c, 1, 1, 1, 3), "the lane is clear before the wall")
            Wall.place(c, 1, 2, "illusory_wall") -- sightCost 2, a full block
            assert(not Combat.hasLineOfSight(c, 1, 1, 1, 3), "the wall blocks the line between them")
        end,
    },
    {
        name = "a wall can be struck down, and reopens the tile once it falls",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("knight", 1, 1) }, {})
            local knight = c.units[1]
            local wall = Wall.place(c, 2, 1, "illusory_wall")

            Wall.damage(c, wall, wall.health) -- one big blow tears it down
            assert(not wall.alive, "the wall is destroyed at 0 HP")
            assert(Wall.at(c, 2, 1) == nil, "no living wall remains on the tile")
            assert(Combat.reachable(c, knight)["2,1"] ~= nil, "the tile is reachable again")
        end,
    },
    {
        name = "a forced shove is stopped by a wall (knockback halts and hurts)",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("knight", 3, 3) }, { unit("bandit", 4, 3) })
            local knight, bandit = c.units[1], c.units[2]
            Wall.place(c, 5, 3, "illusory_wall") -- directly behind the bandit's shove path
            local hp0 = bandit.char.stats.health.current

            local moved, collided = Combat.knockback(c, knight, bandit, 3)
            assert(moved == 0, "the bandit cannot be shoved into the wall")
            assert(collided, "the shove registers a collision")
            assert(bandit.char.stats.health.current < hp0, "and the impact hurts it")
        end,
    },
    {
        name = "a timed wall fades once its duration runs out",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("knight", 1, 1) }, {})
            local wall = Wall.place(c, 2, 1, "illusory_wall") -- duration 18
            assert(wall.remaining == 18, "the wall starts at its full duration")

            Wall.tick(c, 18)
            assert(not wall.alive, "the wall fades when its time is up")
        end,
    },
    {
        name = "Summon Wall raises a 3-tile line perpendicular to the caster's aim",
        fn = function()
            -- Priest at (1,3) aims straight ahead to (4,3): a horizontal approach, so the wall runs
            -- vertically through the aimed cell.
            local char = Character.instantiate("priest")
            char.inventory = {}
            Character.addItem(char, Item.instantiate("ability_summon_wall"))
            local c = Combat.new(arena(8, 8), { { char = char, x = 1, y = 3 } }, {})
            local u = c.units[1]
            local ok = Combat.useItem(c, u, char.inventory[1], 4, 3)
            assert(ok, "the wall is summoned")
            assert(Wall.at(c, 4, 2) and Wall.at(c, 4, 3) and Wall.at(c, 4, 4),
                "three segments stand in a vertical line through the aimed cell")
        end,
    },
}
