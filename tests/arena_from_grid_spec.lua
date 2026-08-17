-- The board carved out of the map (Arena.fromGrid). A fight is taken on the tiles the company walked
-- over, so these pin the three claims that makes: the ground is the SAME ground, the window is the one
-- the lock would close around, and the side you deploy on is the side you arrived from.

local Arena = require("models.arena")
local Overworld = require("models.overworld")
local Terrain = require("models.terrain")

local function board(seed)
    return Overworld.generate({
        biome = "forest", seed = seed or 4242,
        encounterCount = 6, keyCount = 1,
        objective = { name = "Boss" },
        houseMaterial = "material_iron",
    })
end

-- A walkable tile somewhere in the middle of the board, to start a fight on.
local function someTrail(grid)
    local best
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            if grid:typeWalkable(grid.cells[y][x].tile) then
                local d = math.abs(x - grid.cols / 2) + math.abs(y - grid.rows / 2)
                if not best or d < best.d then best = { x = x, y = y, d = d } end
            end
        end
    end
    return best
end

return {
    {
        name = "one map: the arena box is exactly the battle board",
        fn = function()
            -- The whole design rests on these two numbers being the same number. If either moves, a
            -- locked board stops being a window on the map and starts being a crop of one.
            assert(Overworld.BOX == Arena.COLS, string.format(
                "Overworld.BOX (%d) must equal Arena.COLS (%d)", Overworld.BOX, Arena.COLS))
            assert(Overworld.BOX == Arena.ROWS, string.format(
                "Overworld.BOX (%d) must equal Arena.ROWS (%d)", Overworld.BOX, Arena.ROWS))
        end,
    },
    {
        name = "the ground you fight on is the ground you walked on, tile for tile",
        fn = function()
            local grid = board()
            local at = someTrail(grid)
            local layout = Arena.fromGrid(grid, { x = at.x, y = at.y, party = 4, enemies = 3 })
            local ox, oy = layout.box.x, layout.box.y
            -- The one licensed difference: ground the ring cut off from the fight is walled rather than
            -- drawn as floor nobody can get to (Arena.fromGrid). Everything the fight can actually reach
            -- is the map's own tile, unchanged.
            local reachable = {}
            grid:boxReach(ox, oy, at.x, at.y, reachable)
            for j = 1, layout.rows do
                for i = 1, layout.cols do
                    local c = grid:get(ox + i - 1, oy + j - 1)
                    local want = c and c.tile or "obstacle"
                    if c and grid:typeWalkable(c.tile)
                        and not reachable[(oy + j - 1) * 100000 + (ox + i - 1)] then
                        want = "obstacle"
                    end
                    assert(layout.tiles[j][i] == want, string.format(
                        "board tile (%d,%d) is %s, map says %s", i, j, layout.tiles[j][i], want))
                end
            end
            -- ...and every one of them is a terrain the battle layer knows how to stand on or not.
            for j = 1, layout.rows do
                for i = 1, layout.cols do
                    assert(Terrain.TYPES[layout.tiles[j][i]],
                        "carved an unknown terrain: " .. tostring(layout.tiles[j][i]))
                end
            end
        end,
    },
    {
        name = "a cut board is ONE piece of ground -- nothing is ever fought across a wall",
        fn = function()
            -- The board's ring is a wall, so a window laid across a ridge or a river bend used to open a
            -- fight with the company on one side of it and half the opposition on the other: nobody could
            -- reach anybody, and a killAll could not be finished. Walked over every fight-bearing tile of
            -- several boards on every ground, because the fault is a property of SHAPE and one biome's
            -- carve is not another's.
            local seen = 0
            for _, biome in ipairs({ "forest", "swamp", "desert", "tundra", "volcanic", "underworld" }) do
                for seed = 1, 3 do
                    local grid = Overworld.generate({
                        biome = biome, seed = seed * 101, encounterCount = 8, keyCount = 1,
                        objective = { name = "Boss" }, houseMaterial = "material_iron",
                    })
                    for y = 1, grid.rows do
                        for x = 1, grid.cols do
                            if grid:typeWalkable(grid.cells[y][x].tile) and (x + y) % 5 == 0 then
                                local l = Arena.fromGrid(grid, { x = x, y = y, from = { x = x, y = y + 1 },
                                    party = 4, enemies = 4, biome = biome })
                                -- Flood the board from the first walkable tile there is; every other one
                                -- has to turn up in the same flood.
                                local function walkable(i, j)
                                    if i < 1 or j < 1 or i > l.cols or j > l.rows then return false end
                                    return Terrain.walkable(l.tiles[j][i])
                                end
                                local start
                                for j = 1, l.rows do
                                    for i = 1, l.cols do
                                        if not start and walkable(i, j) then start = { i, j } end
                                    end
                                end
                                assert(start, string.format("%s seed %d (%d,%d): a board with no floor",
                                    biome, seed, x, y))
                                local mark = { [start[2] * 100 + start[1]] = true }
                                local q, qi, n = { start }, 1, 0
                                while qi <= #q do
                                    local c = q[qi]; qi = qi + 1
                                    n = n + 1
                                    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                                        local ni, nj = c[1] + d[1], c[2] + d[2]
                                        local k = nj * 100 + ni
                                        if walkable(ni, nj) and not mark[k] then
                                            mark[k] = true
                                            q[#q + 1] = { ni, nj }
                                        end
                                    end
                                end
                                local floor = 0
                                for j = 1, l.rows do
                                    for i = 1, l.cols do
                                        if walkable(i, j) then floor = floor + 1 end
                                    end
                                end
                                assert(n == floor, string.format(
                                    "%s seed %d: the fight at (%d,%d) opens on %d tiles of floor in one"
                                    .. " piece and %d in another", biome, seed, x, y, n, floor - n))
                                seen = seen + 1
                            end
                        end
                    end
                end
            end
            assert(seen > 200, "expected a real sweep of boards, cut " .. seen)
        end,
    },
    {
        name = "the window contains the tile the fight began on",
        fn = function()
            local grid = board(77)
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    if grid:typeWalkable(grid.cells[y][x].tile) then
                        local l = Arena.fromGrid(grid, { x = x, y = y, party = 4, enemies = 3 })
                        assert(x >= l.box.x and x < l.box.x + l.cols
                            and y >= l.box.y and y < l.box.y + l.rows,
                            string.format("fight at (%d,%d) fell outside its own board", x, y))
                    end
                end
            end
        end,
    },
    {
        name = "you deploy on the edge you arrived from, and meet what you met on the far one",
        fn = function()
            local grid = board(31)
            local at = someTrail(grid)
            -- Four approaches onto the same tile. `from` is the tile stepped off, so the edge nearest it
            -- is the company's -- which is the whole of U5: a rolled board has no outside and therefore
            -- no "your side", and a carved one does.
            local cases = {
                { from = { x = at.x, y = at.y + 6 }, side = "bottom" },
                { from = { x = at.x, y = at.y - 6 }, side = "top" },
                { from = { x = at.x - 6, y = at.y }, side = "left" },
                { from = { x = at.x + 6, y = at.y }, side = "right" },
            }
            local opposite = { bottom = "top", top = "bottom", left = "right", right = "left" }
            for _, case in ipairs(cases) do
                local l = Arena.fromGrid(grid, {
                    x = at.x, y = at.y, from = case.from, party = 4, enemies = 3,
                })
                assert(l.box.entry == case.side, string.format(
                    "approached from the %s, deployed on the %s", case.side, tostring(l.box.entry)))

                -- The party's own spawns sit on that edge's half of the board, and the enemy's on the
                -- other. Checked as a comparison of means rather than tile by tile, because a cramped
                -- board is allowed to spill (a fight with nowhere to stand still has to be fielded).
                local function meanAlong(list)
                    local sum = 0
                    for _, s in ipairs(list) do
                        sum = sum + ((case.side == "left" or case.side == "right") and s.x or s.y)
                    end
                    return sum / math.max(1, #list)
                end
                local ours, theirs = meanAlong(l.partySpawns), meanAlong(l.enemySpawns)
                if #l.partySpawns > 0 and #l.enemySpawns > 0 then
                    if case.side == "bottom" or case.side == "right" then
                        assert(ours > theirs, case.side .. ": the company should be the far side of the enemy")
                    else
                        assert(ours < theirs, case.side .. ": the company should be the near side of the enemy")
                    end
                end
                assert(opposite[l.box.entry], "every entry edge has an opposite")
            end
        end,
    },
    {
        name = "caught from behind, the enemy is between you and the way out",
        fn = function()
            -- P10, and the reason the patrol layer is tactical rather than decorative. A fight the
            -- company WALKED INTO opens as two lines facing each other; one that caught them opens with
            -- the enemy on the side it actually came from -- which, if you were deep in a spur walking
            -- back out, is the side you were walking toward.
            local grid = board(21)
            local at = someTrail(grid)

            -- Walked into, head-on: the company came from below, so the enemy is above.
            local head = Arena.fromGrid(grid, {
                x = at.x, y = at.y, from = { x = at.x, y = at.y + 1 },
                party = 4, enemies = 3,
            })
            assert(head.box.entry == "bottom", "the company should hold the edge it walked in from")

            -- Caught from behind: the company was still walking up (from below), and the patrol arrived
            -- from below too -- so the enemy takes the company's own side rather than the far one.
            local ambush = Arena.fromGrid(grid, {
                x = at.x, y = at.y, from = { x = at.x, y = at.y + 1 },
                foeFrom = { x = at.x, y = at.y + 1 },
                party = 4, enemies = 3,
            })
            -- Same edge for both is the one case that cannot be honoured -- two lines would open the
            -- fight standing on each other -- so it falls back to opposite rather than overlapping.
            assert(ambush.box.entry == "bottom", "the company's own side does not move")
            assert(#ambush.enemySpawns > 0, "an ambush still fields its enemies")

            -- Caught from the flank: the enemy takes that flank, not the far edge.
            local flank = Arena.fromGrid(grid, {
                x = at.x, y = at.y, from = { x = at.x, y = at.y + 1 },
                foeFrom = { x = at.x - 1, y = at.y },
                party = 4, enemies = 3,
            })
            local function meanX(list)
                local s = 0
                for _, u in ipairs(list) do s = s + u.x end
                return s / math.max(1, #list)
            end
            if #flank.enemySpawns > 0 and #head.enemySpawns > 0 then
                assert(meanX(flank.enemySpawns) < meanX(head.enemySpawns) + 0.001
                    or flank.box.entry ~= head.box.entry,
                    "an enemy arriving from the left should come in on the left")
            end
        end,
    },
    {
        name = "nobody is ever seated inside a wall",
        fn = function()
            for seed = 1, 8 do
                local grid = board(seed * 13)
                local at = someTrail(grid)
                local l = Arena.fromGrid(grid, { x = at.x, y = at.y, party = 4, enemies = 4 })
                for _, list in ipairs({ l.partySpawns, l.enemySpawns, l.deployZone }) do
                    for _, s in ipairs(list) do
                        local t = l.tiles[s.y][s.x]
                        assert(Terrain.walkable(t), string.format(
                            "seed %d: a body was seated on %s at (%d,%d)", seed, t, s.x, s.y))
                    end
                end
                assert(#l.deployZone > 0, "seed " .. seed .. ": nowhere to deploy")
            end
        end,
    },
    {
        -- The other half of "nobody is seated inside a wall": nobody is seated inside a BODY. A carved
        -- window packs its two bands tighter than a rolled board does -- the spawn points of one line are
        -- a contiguous run of tiles -- so a 2x2 Ogre anchored on one of them covers the points its own
        -- escort was handed, and the fight opened with bandits standing inside the brute. Walked through
        -- Arena.build (not fromGrid) because seating is its business, on the real encounter blueprint.
        name = "on a carved board, no body opens the fight standing inside another",
        fn = function()
            local Character = require("models.character")
            local ogre = require("data.encounters.encounter_ogre")

            for seed = 1, 10 do
                local grid = board(seed * 7)
                local at = someTrail(grid)
                local a = Arena.build({ prestige = 3, day = 8 }, {
                    biome = "forest", seed = seed, party = { "character_rowan", "character_mage" },
                    composition = ogre.composition,
                    grid = grid, at = at, from = { x = at.x, y = at.y + 1 },
                })
                local held = {}
                for _, u in ipairs(a.enemies) do
                    local fp = Character.normalizeFootprint((Character.defs[u.id] or {}).footprint)
                    for j = 0, fp.h - 1 do
                        for i = 0, fp.w - 1 do
                            local k = (u.x + i) .. "," .. (u.y + j)
                            assert(not held[k], string.format(
                                "seed %d: %s stands on %d,%d, already held by %s",
                                seed, u.id, u.x + i, u.y + j, held[k]))
                            assert(a.tiles[u.y + j][u.x + i].walkable, string.format(
                                "seed %d: %s stands in a wall at %d,%d", seed, u.id, u.x + i, u.y + j))
                            held[k] = u.id
                        end
                    end
                end
                -- ...and the brute is actually there: a fix that seated it by dropping it would pass
                -- every assertion above.
                local hasOgre = false
                for _, u in ipairs(a.enemies) do hasOgre = hasOgre or u.id == "character_ogre" end
                assert(hasOgre, "seed " .. seed .. ": the Ogre was not fielded at all")
            end
        end,
    },
    {
        name = "the enemy cap reads the board, and only when there is a board",
        fn = function()
            -- No map under the fight: exactly the cap it has always been. Every boardless caller --
            -- draft, duel, the menu's mock, the debug harness -- takes this path.
            local base = Arena.enemyCap({})
            assert(Arena.enemyCap({}, nil) == base, "a boardless fight must keep its old cap")
            -- A hall fields what it always did; a defile fields fewer.
            assert(Arena.enemyCap({}, 64) == base, "a full board should not lower the cap")
            local thin = Arena.enemyCap({}, 24)
            assert(thin < base, "a cramped board should field fewer bodies, got " .. thin)
            assert(thin >= 2, "an encounter must never resolve to a single body, got " .. thin)
            -- ...and it can only ever lower it. A big box does not license a bigger fight than the
            -- quest's own difficulty allows.
            assert(Arena.enemyCap({}, 999) <= base, "the box may cap a fight, never inflate one")
        end,
    },
}
