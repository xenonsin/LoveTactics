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
        name = "arena box: no containing window holds more ground than the one chosen",
        fn = function()
            local grid = board({ seed = 99 })
            local B = Overworld.BOX
            local sums = grid:walkableSums()
            -- Walk a sample of trail tiles and brute-force every window that contains each, so the
            -- integral-image shortcut is checked against the definition it is an optimisation of.
            local n = 0
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    if grid:typeWalkable(grid.cells[y][x].tile) and (x + y) % 3 == 0 then
                        local _, _, score = grid:bestBox(x, y, sums)
                        local brute = 0
                        for oy = math.max(1, y - B + 1), math.min(grid.rows - B + 1, y) do
                            for ox = math.max(1, x - B + 1), math.min(grid.cols - B + 1, x) do
                                local count = 0
                                for j = oy, oy + B - 1 do
                                    for i = ox, ox + B - 1 do
                                        if grid:typeWalkable(grid.cells[j][i].tile) then count = count + 1 end
                                    end
                                end
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
