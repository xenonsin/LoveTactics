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
    {
        name = "arena box: openSums counts OPEN ground, and roomAt reports the window's own two numbers",
        fn = function()
            local grid = board({ seed = 1234 })
            local B = Overworld.BOX
            local sums, opens = grid:walkableSums(), grid:openSums()
            -- The shape table is the space table's predicate hook doing its job, and the two have to
            -- describe the same windows or every floor read off them is measuring different boards.
            for _, at in ipairs({ { 2, 2 }, { 5, 6 }, { grid.cols - B + 1, grid.rows - B + 1 } }) do
                local ox, oy = at[1], at[2]
                local open = 0
                for j = oy, oy + B - 1 do
                    for i = ox, ox + B - 1 do
                        if grid:isOpen(i, j) then open = open + 1 end
                    end
                end
                assert(opens(ox, oy) == open,
                    string.format("window (%d,%d): openSums %d, count %d", ox, oy, opens(ox, oy), open))
                assert(opens(ox, oy) <= sums(ox, oy), "open ground is a subset of walkable ground")
            end
            -- roomAt hands back the pair for the window bestBox chose, and seatsFight is exactly the two
            -- floors applied to that pair -- so a caller reading one number cannot disagree with a
            -- caller reading the other.
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    if grid:typeWalkable(grid.cells[y][x].tile) then
                        local cross, open, ox, oy = grid:roomAt(x, y, sums, opens)
                        local bx, by, bs = grid:bestBox(x, y, sums)
                        assert(ox == bx and oy == by and cross == bs, "roomAt disagrees with bestBox")
                        assert(open == opens(ox, oy), "roomAt disagrees with openSums")
                        assert(grid:seatsFight(x, y, sums, opens)
                            == (cross >= Overworld.BOX_OK and open >= Overworld.BOX_OPEN),
                            "seatsFight disagrees with its own floors")
                    end
                end
            end
        end,
    },
    {
        name = "arena box: the objective takes a dead end a fight can happen on, whenever one exists",
        fn = function()
            -- THE FIGHT NOBODY MAY SKIP. Every other rule about the objective is about GATEABILITY -- a
            -- strict dead end is what makes an end lockable -- and for a long time that was the only
            -- question asked, which seated a floor's guardian on the least arena-shaped tile a board
            -- has. Measured before this rule: the objectives of a forest board stood on 3.5 tiles of
            -- open ground out of 64, against a floor of 16.
            --
            -- ASSERTED AS A SHARE, and the exact form was tried first and is not available: the filter
            -- runs while placeObjectiveAndGates does, and pruneDeadStubs then rewrites the board under
            -- it. That pass TRIMS barren spurs back to their junctions, which turns through-tiles into
            -- leaves -- so a finished board carries dead ends that did not exist when the end was
            -- seated, several of them in clearings, and a spec reading the finished board cannot tell
            -- those from the ones the rule really declined. What it CAN say is what the share does: the
            -- filter takes it to roughly nine boards in ten, and dropping the filter puts it back near
            -- one in ten, which is a gap no sampling noise crosses.
            --
            -- The colosseum is left out on purpose: models/layouts/sands.lua names both ends itself
            -- (Layout `anchors`), and an authored end outranks every rule here by design.
            local grounds = { "forest", "swamp", "tundra", "desert", "volcanic", "underworld", "castle" }
            local seated, boards, openSum = 0, 0, 0
            for _, biome in ipairs(grounds) do
                for seed = 1, 6 do
                    local grid = board({ biome = biome, seed = seed * 71 })
                    local sums, opens = grid:walkableSums(), grid:openSums()
                    local o = grid.objective
                    local _, open = grid:roomAt(o.x, o.y, sums, opens)
                    boards, openSum = boards + 1, openSum + open
                    if grid:seatsFight(o.x, o.y, sums, opens) then seated = seated + 1 end
                end
            end
            assert(seated / boards > 0.8, string.format(
                "only %d of %d objectives stand on ground a fight can happen on -- the room filter in " ..
                "placeObjectiveAndGates is being skipped", seated, boards))
            -- ...and the mean is the figure `. board-report` reads as the `ends` column, which sat at 3.5
            -- on forest before the filter existed.
            assert(openSum / boards > Overworld.BOX_OPEN, string.format(
                "the mean end holds %.1f open tiles, under the floor of %d",
                openSum / boards, Overworld.BOX_OPEN))
        end,
    },
    {
        name = "arena box: a guard is a fight, so it never stands where a fight cannot happen",
        fn = function()
            -- guardBoons was where nearly all of a board's corridor fights came from: a spur mouth is
            -- the likeliest tile on the map to be a hallway, and the pass lifted fights out of the
            -- clearings placeEncounters had chosen for them and stood them in doorways. Measured, a
            -- forest board put 92% of its fights on guard and 3.9 of 4.5 of them under the shape floor.
            --
            -- Refusing costs nothing here, which is why this one is absolute: the fight is not created
            -- by that pass. Declining to move it leaves it where it already was.
            local seen = 0
            for _, biome in ipairs({ "forest", "swamp", "castle", "underworld" }) do
                for seed = 1, 5 do
                    local grid = board({ biome = biome, seed = seed * 137, encounterCount = 10 })
                    local sums, opens = grid:walkableSums(), grid:openSums()
                    local function check(x, y, what)
                        assert(grid:seatsFight(x, y, sums, opens), string.format(
                            "%s seed %d: %s at (%d,%d) stands on ground no fight can happen on",
                            biome, seed, what, x, y))
                        seen = seen + 1
                    end
                    for y = 1, grid.rows do
                        for x = 1, grid.cols do
                            if grid.cells[y][x].guards then check(x, y, "a guard") end
                        end
                    end
                    -- ...including the ones that walked off their cell onto a beat. A patrol keeps its
                    -- guard, and the tile it was seated on is where the report and the player both find
                    -- it on a freshly rolled board.
                    for _, p in ipairs(grid.patrols or {}) do
                        if p.guards then check(p.x, p.y, "a patrolling guard") end
                    end
                end
            end
            assert(seen > 10, "expected the boards to seat some guards at all, got " .. seen)
        end,
    },
}
