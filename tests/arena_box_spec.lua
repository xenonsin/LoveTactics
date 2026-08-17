-- The arena box: the window of THIS MAP a fight locks (see models/overworld.lua's Overworld.BOX and
-- docs/overworld.md's one-map section). These pin the rule itself -- contains, maximal, deterministic --
-- rather than any particular board's numbers, which belong to `. board-report`.

local Overworld = require("models.overworld")

local function board(opts)
    opts = opts or {}
    return Overworld.generate({
        biome = opts.biome or "forest",
        encounterCount = opts.encounterCount or 8,
        keyCount = 1,
        objective = { name = "Boss" },
        houseMaterial = "material_iron",
        seed = opts.seed or 4242,
    })
end

return {
    {
        name = "arena box: the chosen window always contains the tile it was asked about",
        fn = function()
            local grid = board()
            local B = Overworld.BOX
            local sums = grid:walkableSums()
            local checked = 0
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    if grid:typeWalkable(grid.cells[y][x].tile) then
                        local ox, oy = grid:bestBox(x, y, sums)
                        assert(x >= ox and x < ox + B and y >= oy and y < oy + B,
                            string.format("box (%d,%d) does not contain tile (%d,%d)", ox, oy, x, y))
                        -- ...and never hangs off the edge of the map.
                        assert(ox >= 1 and oy >= 1 and ox + B - 1 <= grid.cols and oy + B - 1 <= grid.rows,
                            "box runs off the board")
                        checked = checked + 1
                    end
                end
            end
            assert(checked > 40, "expected a board with some trail on it, got " .. checked .. " tiles")
        end,
    },
    {
        name = "arena box: no containing window holds more CROSSABLE ground than the one chosen",
        fn = function()
            local grid = board({ seed = 99 })
            local B = Overworld.BOX
            local sums = grid:walkableSums()
            -- Walk a sample of trail tiles and brute-force every window that contains each, so the
            -- branch-and-bound (which uses the integral image only as an upper bound, and floods for the
            -- real answer) is checked against the definition it is an optimisation of.
            --
            -- The measure is what you can reach from the tile you are standing on WITHOUT LEAVING THE
            -- WINDOW, because the window's ring is the wall once the lock closes. A plain walkable count
            -- would happily choose a box straddling a ridge for the far side of it.
            local n = 0
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    if grid:typeWalkable(grid.cells[y][x].tile) and (x + y) % 3 == 0 then
                        local _, _, score = grid:bestBox(x, y, sums)
                        local brute = 0
                        for oy = math.max(1, y - B + 1), math.min(grid.rows - B + 1, y) do
                            for ox = math.max(1, x - B + 1), math.min(grid.cols - B + 1, x) do
                                local count = grid:boxReach(ox, oy, x, y)
                                if count > brute then brute = count end
                            end
                        end
                        assert(score == brute, string.format(
                            "tile (%d,%d): bestBox says %d, brute force says %d", x, y, score, brute))
                        n = n + 1
                    end
                end
            end
            assert(n > 10, "expected to have checked a real sample, checked " .. n)
        end,
    },
    {
        name = "arena box: reach counts one piece of ground, and never counts round the outside",
        fn = function()
            -- The measure itself, against a board with a known shape rather than a rolled one: a window
            -- split down the middle by a wall, joined only by a corridor running OUTSIDE it.
            local grid = board({ seed = 5 })
            local B = Overworld.BOX
            assert(grid.rows >= 12 and grid.cols >= 8, "the fixture needs room for the shape it draws")
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    grid.cells[y][x].tile = "thicket"
                end
            end
            -- Two 8-tall columns of trail inside one window, walled from each other, meeting on a row
            -- below it. Standing in the left column you can walk the right one only by leaving the box.
            for y = 1, 10 do
                grid.cells[y][2].tile = "path"
                grid.cells[y][7].tile = "path"
            end
            for x = 2, 7 do grid.cells[10][x].tile = "path" end

            local left = grid:boxReach(1, 1, 2, 1)
            assert(left == B, "the left column alone is " .. B .. " tiles, reach says " .. left)
            -- ...and the map itself does join them, which is exactly what the box is not allowed to use.
            local joined = grid:boxReach(1, 3, 2, 3)
            assert(joined > B, "a window holding the joining row should reach both columns, got " .. joined)

            -- A tile nothing can stand on has nothing to reach.
            assert(grid:boxReach(1, 1, 1, 1) == 0, "a wall reaches nothing")
            -- ...and neither does a window that does not contain the tile asked about.
            assert(grid:boxReach(20, 20, 2, 1) == 0, "a window that excludes the tile reaches nothing")
        end,
    },
    {
        name = "arena box: the same seed locks the same window",
        fn = function()
            local a, b = board({ seed = 7 }), board({ seed = 7 })
            local sa, sb = a:walkableSums(), b:walkableSums()
            for y = 1, a.rows do
                for x = 1, a.cols do
                    if a:typeWalkable(a.cells[y][x].tile) then
                        local ax, ay, as = a:bestBox(x, y, sa)
                        local bx, by, bs = b:bestBox(x, y, sb)
                        assert(ax == bx and ay == by and as == bs,
                            "two boards from one seed disagree about the box at " .. x .. "," .. y)
                    end
                end
            end
        end,
    },
    {
        name = "arena box: walkableSums agrees with a direct count",
        fn = function()
            local grid = board({ seed = 1234 })
            local B = Overworld.BOX
            local sums = grid:walkableSums()
            for _, at in ipairs({ { 1, 1 }, { 3, 4 }, { grid.cols - B + 1, grid.rows - B + 1 } }) do
                local ox, oy = at[1], at[2]
                local count = 0
                for j = oy, oy + B - 1 do
                    for i = ox, ox + B - 1 do
                        if grid:typeWalkable(grid.cells[j][i].tile) then count = count + 1 end
                    end
                end
                assert(sums(ox, oy) == count,
                    string.format("window (%d,%d): sums %d, count %d", ox, oy, sums(ox, oy), count))
            end
            -- A window running off the board answers 0 rather than indexing nil.
            assert(sums(0, 1) == 0 and sums(1, 0) == 0, "off-board window should be 0")
            assert(sums(grid.cols, 1) == 0, "window overhanging the right edge should be 0")
        end,
    },
}
