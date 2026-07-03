-- Tests for the procedural overworld generator (models/overworld.lua): seeded
-- determinism, trail connectivity, and the objective/lock-key solvability
-- guarantee, plus the quest -> map param plumbing.

local Overworld = require("models.overworld")
local Quest = require("models.quest")
local Tileset = require("models.tileset")

local function typeWalkable(tile)
    local def = Tileset.get().tiles[tile]
    return def ~= nil and def.walkable == true
end

-- Deterministic small map for structural checks.
local function gen(overrides)
    local params = {
        cols = 31, rows = 21, seed = 1234, riverCount = 2,
        encounterCount = 5, keyCount = 1, objective = { name = "Boss" },
        encounters = { { kind = "combat", weight = 3 }, { kind = "elite", weight = 1 } },
    }
    if overrides then
        for k, v in pairs(overrides) do params[k] = v end
    end
    return Overworld.generate(params)
end

-- Flatten a grid to a comparable string signature.
local function signature(grid)
    local parts = {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid:get(x, y)
            parts[#parts + 1] = table.concat({
                c.tile,
                c.gate and c.gate.keyId or "-",
                c.key and c.key.keyId or "-",
                c.encounter and c.encounter.kind or "-",
            }, ":")
        end
    end
    return table.concat(parts, "|")
end

local function countWalkable(grid)
    local n = 0
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            if typeWalkable(grid:get(x, y).tile) then n = n + 1 end
        end
    end
    return n
end

return {
    {
        name = "biome sets maze spacing (castle is tighter than forest)",
        fn = function()
            local forest = Overworld.generate({ cols = 41, rows = 29, seed = 5, biome = "forest" })
            local castle = Overworld.generate({ cols = 41, rows = 29, seed = 5, biome = "castle" })
            assert(forest.spacing == 4, "forest spacing should be 4, got " .. forest.spacing)
            assert(castle.spacing == 2, "castle spacing should be 2, got " .. castle.spacing)
            assert(castle.spacing < forest.spacing, "castle should be tighter than forest")
        end,
    },
    {
        name = "each biome resolves its own tileset (art differs, walkability shared)",
        fn = function()
            local forest = Overworld.generate({ cols = 41, rows = 29, seed = 7, biome = "forest" })
            local castle = Overworld.generate({ cols = 41, rows = 29, seed = 7, biome = "castle" })
            assert(forest.tilesetId == "forest", "forest should use the forest tileset")
            assert(castle.tilesetId == "castle", "castle should use the castle tileset")

            local ft, ct = Tileset.get(forest.tilesetId), Tileset.get(castle.tilesetId)
            assert(ft.image ~= ct.image, "biomes should point at different tileset images")
            -- Distinct art: at least the path colour should differ between biomes.
            assert(ft.tiles.path.color[1] ~= ct.tiles.path.color[1]
                or ft.tiles.path.color[3] ~= ct.tiles.path.color[3],
                "forest and castle path colours should differ")
            -- Walkability is universal, not per-biome.
            for tile in pairs(Tileset.TYPES) do
                assert(ft.tiles[tile].walkable == ct.tiles[tile].walkable,
                    "walkability of '" .. tile .. "' must match across biomes")
            end
            assert(ft.tiles.path.walkable and not ft.tiles.water.walkable,
                "path walkable, water blocked, in every tileset")
        end,
    },
    {
        name = "unknown/missing biome falls back without error, and is still solvable",
        fn = function()
            local grid = Overworld.generate({ cols = 41, rows = 29, seed = 9, keyCount = 1 })
            assert(grid.spacing == 4, "default spacing should be forest's 4")
            assert((grid:solve()), "default-biome map unsolvable")
        end,
    },
    {
        name = "castle (tight) maps stay solvable with keys across many seeds",
        fn = function()
            for seed = 1, 30 do
                local grid = Overworld.generate({
                    cols = 51, rows = 35, seed = seed, biome = "castle",
                    encounterCount = 12, keyCount = 2,
                    objective = { name = "Warlord" },
                })
                assert((grid:solve()), "castle seed " .. seed .. " unsolvable")
            end
        end,
    },
    {
        name = "biome dictates river count (castle has none, forest has some)",
        fn = function()
            local function riverTiles(grid)
                local n = 0
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        if grid:get(x, y).river then n = n + 1 end
                    end
                end
                return n
            end
            local castle = Overworld.generate({ cols = 41, rows = 29, seed = 3, biome = "castle" })
            assert(riverTiles(castle) == 0, "castle should have no rivers")
            local forest = Overworld.generate({ cols = 41, rows = 29, seed = 3, biome = "forest" })
            assert(riverTiles(forest) > 0, "forest should have at least one river")
        end,
    },
    {
        name = "encounter count honours the { min, max } range",
        fn = function()
            for seed = 1, 20 do
                local grid = Overworld.generate({
                    cols = 41, rows = 29, seed = seed, biome = "forest",
                    encounterCount = { min = 6, max = 9 },
                    encounters = { { kind = "combat", weight = 1 } },
                })
                local n = 0
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local c = grid:get(x, y)
                        if c.encounter and c.encounter.kind ~= "objective" then n = n + 1 end
                    end
                end
                assert(n >= 6 and n <= 9, "seed " .. seed .. " placed " .. n .. " (want 6..9)")
            end
        end,
    },
    {
        name = "always-encounters are force-placed",
        fn = function()
            local grid = Overworld.generate({
                cols = 41, rows = 29, seed = 4, biome = "forest",
                encounterCount = { min = 6, max = 9 },
                encounters = { { kind = "combat", weight = 1 } },
                alwaysEncounters = { { id = "elite", kind = "elite", name = "Phoenix" } },
            })
            local found = false
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local c = grid:get(x, y)
                    if c.encounter and c.encounter.id == "elite" then found = true end
                end
            end
            assert(found, "guaranteed elite was not placed")
        end,
    },
    {
        name = "same seed reproduces an identical map",
        fn = function()
            local a = gen({ seed = 777 })
            local b = gen({ seed = 777 })
            assert(signature(a) == signature(b), "identical seeds diverged")
        end,
    },
    {
        name = "different seeds produce different maps",
        fn = function()
            local a = gen({ seed = 1 })
            local b = gen({ seed = 2 })
            assert(signature(a) ~= signature(b), "different seeds gave same map")
        end,
    },
    {
        name = "every trail tile is reachable from the start",
        fn = function()
            local grid = gen()
            local seen = grid:reachable(grid:startCell())
            local reached = 0
            for _ in pairs(seen) do reached = reached + 1 end
            assert(reached == countWalkable(grid),
                "trail not fully connected: reached " .. reached .. " of " .. countWalkable(grid))
        end,
    },
    {
        name = "objective + lock/key maps are always solvable (many seeds)",
        fn = function()
            for seed = 1, 40 do
                local grid = Overworld.generate({
                    cols = 41, rows = 29, seed = seed, riverCount = 3,
                    encounterCount = 8, keyCount = 2, objective = { name = "Boss" },
                })
                local solved, info = grid:solve()
                assert(solved, "seed " .. seed .. " unsolvable: objectiveReached="
                    .. tostring(info.objectiveReached))
            end
        end,
    },
    {
        name = "keyless maps are solvable and gate-free",
        fn = function()
            local grid = gen({ keyCount = 0 })
            assert(#grid.keyIds == 0, "keyless map still has keyIds")
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    assert(grid:get(x, y).gate == nil, "keyless map has a gate")
                end
            end
            assert((grid:solve()), "keyless map unsolvable")
        end,
    },
    {
        name = "exactly one objective encounter, never on the start tile",
        fn = function()
            local grid = gen()
            local count = 0
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local c = grid:get(x, y)
                    if c.encounter and c.encounter.kind == "objective" then count = count + 1 end
                end
            end
            assert(count == 1, "expected 1 objective, found " .. count)
            assert(not (grid.objective.x == grid.start.x and grid.objective.y == grid.start.y),
                "objective placed on start tile")
        end,
    },
    {
        name = "no river tile is left as a plain path (crossings become bridges)",
        fn = function()
            local grid = gen()
            local bridges = 0
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local c = grid:get(x, y)
                    assert(not (c.river and c.tile == "path"),
                        "river over path was not converted to a bridge")
                    if c.tile == "bridge" then
                        bridges = bridges + 1
                        assert(typeWalkable("bridge"), "bridge should be walkable")
                    end
                end
            end
        end,
    },
    {
        name = "encounter count respects the cap and skips the start tile",
        fn = function()
            local grid = gen({ encounterCount = 5 })
            local nonObjective = 0
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local c = grid:get(x, y)
                    if c.encounter and c.encounter.kind ~= "objective" then
                        nonObjective = nonObjective + 1
                    end
                end
            end
            -- objective is placed separately, then up to `encounterCount` more.
            assert(nonObjective <= 5, "too many encounters: " .. nonObjective)
            assert(grid:startCell().encounter == nil, "encounter placed on start tile")
        end,
    },
    {
        name = "reveal lights a circular disc of cells (fog of war)",
        fn = function()
            local grid = gen()
            local cx, cy = 15, 11 -- an interior cell so the radius stays in bounds
            assert(grid:get(cx, cy).seen == nil, "cell starts undiscovered")
            grid:reveal(cx, cy, 2)
            -- Centre and the cardinal edges of the disc are discovered.
            assert(grid:get(cx, cy).seen == true, "centre should be seen")
            assert(grid:get(cx + 2, cy).seen == true, "east edge should be seen")
            assert(grid:get(cx - 2, cy).seen == true, "west edge should be seen")
            assert(grid:get(cx, cy + 2).seen == true, "south edge should be seen")
            assert(grid:get(cx, cy - 2).seen == true, "north edge should be seen")
            -- The far corners of the bounding square fall outside the disc (circular,
            -- not square), and anything past the radius stays hidden.
            assert(grid:get(cx + 2, cy + 2).seen == nil, "diagonal corner is outside the disc")
            assert(grid:get(cx + 3, cy).seen == nil, "cell past the radius stays hidden")
            assert(grid:get(cx, cy + 3).seen == nil, "cell past the radius stays hidden")
        end,
    },
    {
        name = "pixel <-> cell round-trips",
        fn = function()
            local grid = gen()
            for _, p in ipairs({ { 1, 1 }, { 10, 7 }, { grid.cols, grid.rows } }) do
                local px, py = grid:cellToPixel(p[1], p[2])
                local cx, cy = grid:pixelToCell(px, py)
                assert(cx == p[1] and cy == p[2], "top-left round-trip failed at " .. p[1] .. "," .. p[2])
                -- a point in the middle of the cell maps to the same cell
                local mx, my = grid:pixelToCell(px + grid.size / 2, py + grid.size / 2)
                assert(mx == p[1] and my == p[2], "mid-cell round-trip failed")
            end
        end,
    },
    {
        name = "quest map params flow through Quest.available without mutating blueprints",
        fn = function()
            local found
            for _, q in ipairs(Quest.available(3)) do
                if q.id == "warlord_keep" then found = q end
            end
            assert(found, "warlord_keep not available at prestige 3")
            assert(found.map and found.map.keyCount == 2, "warlord_keep map params not carried")
            -- blueprint still intact
            assert(Quest.defs.warlord_keep.id == nil, "quest blueprint mutated")
            assert(Quest.defs.warlord_keep.map.keyCount == 2, "quest map blueprint mutated")
        end,
    },
}
