-- Tests for line of sight on the overworld (models/vision.lua, Overworld:inVision).
--
-- The rule these hold to: the fog lifts off what the party can DRAW A LINE TO, out to the vision
-- radius. Distance is half the question -- Overworld:inRange is the other half, and the two are
-- deliberately separate so a spec can say "close enough, and still not visible".

local Overworld = require("models.overworld")

-- An authored board (vision radius 2) from an ASCII map: '.' is trail, '#' is solid fill.
local function board(map)
    return Overworld.fromLayout({
        biome = "forest", objective = { name = "X" },
        layoutDef = { biome = "forest", map = map },
    })
end

-- A room the party stands in, with a wall across the middle of it:
--
--   #######
--   #S....#     the party at (2,2), an open row in front of it
--   ###.#.#     solid across the row below, with two ways down out of it
--   #....X#
--   #######
local function walledRoom()
    return board({
        "#######",
        "#S....#",
        "###.#.#",
        "#....X#",
        "#######",
    })
end

local function sees(grid, x, y)
    return grid:inVision(grid.start.x, grid.start.y, x, y, grid.visionRadius)
end

local function inRange(grid, x, y)
    return grid:inRange(grid.start.x, grid.start.y, x, y, grid.visionRadius)
end

return {
    {
        name = "a wall stops the light, and is lit itself",
        fn = function()
            local grid = walledRoom()
            assert(inRange(grid, 2, 4), "the tile two below the party is inside the radius")
            assert(not sees(grid, 2, 4), "...and still not visible, with a wall standing between")
            assert(sees(grid, 2, 3), "the wall face itself is seen -- a wall you cannot see is a hole")
            assert(sees(grid, 4, 3), "the gap in that same wall, on a clear line, IS visible")
        end,
    },
    {
        name = "sight carries down an open row",
        fn = function()
            local grid = walledRoom()
            assert(sees(grid, 3, 2) and sees(grid, 4, 2),
                "nothing stands between the party and the far end of its own row")
        end,
    },
    {
        name = "reveal lifts the fog off what is visible and leaves the rest dark",
        fn = function()
            local grid = walledRoom()
            grid:reveal(grid.start.x, grid.start.y, grid.visionRadius)
            assert(grid:get(2, 3).seen == true, "the wall in front of the party is mapped")
            assert(grid:get(2, 4).seen == nil, "the ground behind it is not")
            assert(grid:get(4, 3).seen == true, "the gap in it, which the party can see through, is")
        end,
    },
    {
        name = "walking around the wall maps what standing still could not",
        fn = function()
            -- The whole point of the rule: ground you cannot see is ground you have to go and look at,
            -- and once you have, the map keeps it (discovery is permanent for the run).
            local grid = walledRoom()
            grid:reveal(grid.start.x, grid.start.y, grid.visionRadius)
            assert(grid:get(2, 4).seen == nil, "the far side of the wall starts dark")
            grid:reveal(4, 4, grid.visionRadius) -- down through the gap and round the corner
            assert(grid:get(2, 4).seen == true, "and lights up from the corridor it stands in")
        end,
    },
    {
        name = "open ground still lights the whole disc",
        fn = function()
            -- Line of sight subtracts from the radius; it never changes its shape. On a board with
            -- nothing in the way, visible and in-range are the same set -- which is what keeps the
            -- flight leg's spacing rule (tests/flight_board_spec.lua) reading off the same geometry.
            local grid = board({
                ".......",
                ".......",
                "..S.X..",
                ".......",
                ".......",
            })
            local cx, cy, r = grid.start.x, grid.start.y, grid.visionRadius
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    assert(grid:inVision(cx, cy, x, y, r) == grid:inRange(cx, cy, x, y, r),
                        "open ground: " .. x .. "," .. y .. " should be lit exactly when it is in range")
                end
            end
        end,
    },
    {
        name = "the field is memoized per stance, not recast per tile",
        fn = function()
            -- The renderer asks inVision of every tile on the board every frame; the cast is per
            -- STANCE. Asked here because a per-tile cast is invisible until the board is big and the
            -- frame is late.
            local grid = walledRoom()
            local cast = 0
            local real = require("models.vision").field
            require("models.vision").field = function(...) cast = cast + 1; return real(...) end
            for y = 1, grid.rows do
                for x = 1, grid.cols do grid:inVision(2, 2, x, y, 2) end
            end
            require("models.vision").field = real
            assert(cast == 1, "one cast for the whole board, got " .. cast)
        end,
    },
}
