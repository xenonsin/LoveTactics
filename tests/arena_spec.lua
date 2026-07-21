-- Tests for the battle arena model (models/arena.lua): seeded determinism, grid
-- shape + spawn walkability, prestige-driven composition scaling, and the debug
-- serialize round-trip. Pure logic only (no rendering), so it runs headless.

local Arena = require("models.arena")

-- A spec that always generates procedurally (unknown biome -> no curated match),
-- so structural checks aren't captured by data/arenas/forest_01.lua.
local function proceduralSpec(overrides)
    local spec = {
        biome = "__test_void", -- no curated arena tagged for this biome
        party = { "character_knight", "character_mage", "character_archer" },
        composition = function(ctx)
            local list = {}
            for i = 1, 2 + (ctx.prestige or 1) do list[i] = "character_bandit" end
            return list
        end,
        seed = 4242,
    }
    if overrides then
        for k, v in pairs(overrides) do spec[k] = v end
    end
    return spec
end

-- A comparable signature of an arena's tiles + spawn positions.
local function signature(arena)
    local parts = {}
    for y = 1, arena.rows do
        for x = 1, arena.cols do
            parts[#parts + 1] = arena.tiles[y][x].type
        end
    end
    for _, u in ipairs(arena.party) do parts[#parts + 1] = "P" .. u.x .. "," .. u.y end
    for _, u in ipairs(arena.enemies) do parts[#parts + 1] = "E" .. u.x .. "," .. u.y end
    return table.concat(parts, "|")
end

return {
    {
        name = "same seed produces an identical arena (determinism)",
        fn = function()
            local a = Arena.build({ prestige = 2 }, proceduralSpec())
            local b = Arena.build({ prestige = 2 }, proceduralSpec())
            assert(signature(a) == signature(b), "same seed should yield identical arenas")
        end,
    },
    {
        name = "arena is 8x8 and every spawn tile is walkable",
        fn = function()
            local a = Arena.build({ prestige = 3 }, proceduralSpec())
            assert(a.cols == 8 and a.rows == 8, "arena should be 8x8")
            for _, u in ipairs(a.party) do
                assert(a.tiles[u.y][u.x].walkable, "party spawn must be walkable")
            end
            for _, u in ipairs(a.enemies) do
                assert(a.tiles[u.y][u.x].walkable, "enemy spawn must be walkable")
            end
        end,
    },
    {
        name = "party spawns near, enemies spawn far",
        fn = function()
            local a = Arena.build({ prestige = 1 }, proceduralSpec())
            for _, u in ipairs(a.party) do
                assert(u.y >= a.rows - 1, "party should spawn on the near rows")
            end
            for _, u in ipairs(a.enemies) do
                assert(u.y <= 2, "enemies should spawn on the far rows")
            end
        end,
    },
    {
        name = "composition scales the enemy count with prestige",
        fn = function()
            local low = Arena.build({ prestige = 1 }, proceduralSpec())
            local high = Arena.build({ prestige = 5 }, proceduralSpec())
            assert(#high.enemies > #low.enemies,
                "higher prestige should field more enemies (" .. #high.enemies
                    .. " vs " .. #low.enemies .. ")")
        end,
    },
    {
        name = "objective defaults to killAll, or honours an explicit win condition",
        fn = function()
            local dflt = Arena.build({ prestige = 1 }, proceduralSpec())
            assert(dflt.objective.type == "killAll", "missing objective should default to killAll")
            local surv = Arena.build({ prestige = 1 },
                proceduralSpec({ objective = { type = "survive", duration = 25 } }))
            assert(surv.objective.type == "survive" and surv.objective.duration == 25,
                "explicit objective (tick duration) should pass through")
        end,
    },
    {
        name = "curated arenas join the random pool (not always picked, not never)",
        fn = function()
            -- forest_01.lua (data/arenas) is tagged biome = "forest" with a 2x2 obstacle
            -- block at rows 4-5, cols 4-5 -- a signature the procedural generator will
            -- not reproduce. Over many seeds we should see BOTH the curated layout and
            -- fresh procedural ones, confirming a mixed pool rather than "always curated".
            local function isCurated(a)
                return a.tiles[4][4].type == "obstacle" and a.tiles[4][5].type == "obstacle"
                    and a.tiles[5][4].type == "obstacle" and a.tiles[5][5].type == "obstacle"
            end
            local curatedHits, proceduralHits = 0, 0
            for seed = 1, 60 do
                local a = Arena.build({ prestige = 1 }, proceduralSpec({ biome = "forest", seed = seed }))
                if isCurated(a) then curatedHits = curatedHits + 1 else proceduralHits = proceduralHits + 1 end
            end
            assert(curatedHits > 0, "the curated forest arena should be picked sometimes")
            assert(proceduralHits > 0, "procedural generation should still happen sometimes")
        end,
    },
    {
        name = "serialize round-trips tiles and spawn positions",
        fn = function()
            local a = Arena.build({ prestige = 2 }, proceduralSpec())
            local src = Arena.serialize(a)
            local layout = assert(loadstring(src), "serialized arena should be valid Lua")()
            assert(layout.biome == a.biome, "biome should round-trip")
            for y = 1, a.rows do
                for x = 1, a.cols do
                    assert(layout.tiles[y][x] == a.tiles[y][x].type,
                        "tile type should round-trip at " .. x .. "," .. y)
                end
            end
            assert(#layout.partySpawns == #a.party, "party spawn count should round-trip")
            assert(#layout.enemySpawns == #a.enemies, "enemy spawn count should round-trip")
            assert(layout.enemySpawns[1].x == a.enemies[1].x
                and layout.enemySpawns[1].y == a.enemies[1].y, "spawn positions should round-trip")
        end,
    },
    {
        -- A board built off the clock cannot be produced again, so the bug it contains cannot be
        -- shown to anyone -- and two machines building the same fight would quietly disagree about
        -- the ground. Generating without a seed is a programming error and has to say so.
        name = "generating a board without a seed is an error, not a silent roll of the clock",
        fn = function()
            local ok, err = pcall(Arena.generateLayout, { biome = "__test_void", party = 2, enemies = 2 })
            assert(not ok, "an unseeded generateLayout should raise")
            assert(tostring(err):find("seed"), "the error should name the seed: " .. tostring(err))

            local pickOk, pickErr = pcall(Arena.pickLayout, { biome = "__test_void" }, 2, 2)
            assert(not pickOk, "an unseeded pickLayout should raise")
            assert(tostring(pickErr):find("seed"), "the error should name the seed: " .. tostring(pickErr))
        end,
    },
    {
        name = "Arena.randomSeed is the one deliberate way to ask for a board nobody has seen",
        fn = function()
            local seed = Arena.randomSeed()
            assert(type(seed) == "number", "randomSeed should produce a number")
            -- It has to satisfy the gate it exists to satisfy.
            local layout = Arena.generateLayout({ biome = "__test_void", seed = seed,
                party = 2, enemies = 2 })
            assert(layout and layout.tiles, "a randomSeed board should build")
        end,
    },
    {
        -- A forced layout is authored ground, so it needs no seed to reproduce -- the escape the
        -- tutorial's scripted board takes.
        name = "a forced layout needs no seed",
        fn = function()
            local ok = pcall(Arena.pickLayout, { biome = "forest", layout = "tutorial_village" }, 2, 3)
            assert(ok, "naming a layout outright should not require a seed")
        end,
    },
}
