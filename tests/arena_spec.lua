-- Tests for the battle arena model (models/arena.lua): seeded determinism, grid
-- shape + spawn walkability, prestige-driven composition scaling, and the debug
-- serialize round-trip. Pure logic only (no rendering), so it runs headless.

local Arena = require("models.arena")

-- A spec that always generates procedurally (unknown biome -> no curated match),
-- so structural checks aren't captured by data/arenas/forest_01.lua.
local function proceduralSpec(overrides)
    local spec = {
        biome = "__test_void", -- no curated arena tagged for this biome
        party = { "character_rowan", "character_mage", "character_archer" },
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

    -- ----------------------------------------------------------------- the enemy ceiling
    {
        name = "the clamp keeps the named cast and cuts only the filler",
        fn = function()
            local ids = { "character_bandit_chief" }
            for _ = 1, 40 do ids[#ids + 1] = "character_bandit" end
            local cut = Arena.clampComposition(ids, 6)
            assert(#cut == 6, "cut to the cap, got " .. #cut)
            assert(cut[1] == "character_bandit_chief", "the named unit survives")

            -- ...and it survives from ANY position, not just the head. Every composition in the game
            -- lists its named unit first today, so a tail-truncation would pass by luck; this is the
            -- case that proves the rule is structural. Dropping an assassinate target is a softlock.
            local buried = {}
            for _ = 1, 40 do buried[#buried + 1] = "character_bandit" end
            buried[#buried + 1] = "character_bandit_chief"
            local cutB = Arena.clampComposition(buried, 6)
            assert(#cutB == 6, "still cut to the cap")
            local found = false
            for _, id in ipairs(cutB) do if id == "character_bandit_chief" then found = true end end
            assert(found, "a named unit at the TAIL survives the cut too")

            -- A short list is returned untouched, and a hand-authored cast of distinct names outranks
            -- the cap rather than being silently decimated.
            local short = { "a", "b" }
            assert(Arena.clampComposition(short, 6) == short, "under the cap, nothing is copied")
            local allNamed = { "a", "b", "c", "d", "e", "f", "g", "h" }
            assert(#Arena.clampComposition(allNamed, 3) == 8, "distinct names outrank the ceiling")
        end,
    },
    {
        -- THE REGRESSION THIS EXISTS FOR: every objective sizes its enemies off prestige, prestige is a
        -- lifetime total that New Game+ carries forward, and nothing used to bound the result -- the
        -- `/2` quests reached 71 bodies by the campaign's ~138 prestige and 140 in a second run. The
        -- ceiling has to hold at every prestige the game can actually reach, not just at the ones a
        -- fixture happens to pick.
        name = "no quest's objective can field more than its difficulty allows, at any prestige",
        fn = function()
            local Quest = require("models.quest")
            local checked = 0
            for id, def in pairs(Quest.defs) do
                local objective = def.map and def.map.objective
                if objective and objective.composition then
                    local ctx = { quest = def, biome = def.map.biome }
                    local cap = Arena.enemyCap(ctx)
                    -- 1 (a fresh company) through 276 (a full New Game+ carry), stepped to keep the
                    -- sweep cheap while still crossing every threshold a floor division can trip.
                    for prestige = 1, 276, 5 do
                        ctx.prestige = prestige
                        local raw = Arena.resolveComposition(objective.composition, ctx)
                        local cut = Arena.clampComposition(raw, cap)
                        -- Distinct ids outrank the cap by design, so the bound is whichever is larger.
                        local distinct, seen = 0, {}
                        for _, cid in ipairs(raw) do
                            if not seen[cid] then seen[cid] = true; distinct = distinct + 1 end
                        end
                        assert(#cut <= math.max(cap, distinct), string.format(
                            "%s fields %d at prestige %d (cap %d)", id, #cut, prestige, cap))

                        -- An assassinate target must still be standing on the board to be killed.
                        local win = objective.win
                        if win and win.type == "assassinate" and win.target then
                            local present = false
                            for _, cid in ipairs(cut) do
                                if cid == win.target then present = true end
                            end
                            local authored = false
                            for _, cid in ipairs(raw) do
                                if cid == win.target then authored = true end
                            end
                            assert(present or not authored, string.format(
                                "%s clamped away its assassinate target at prestige %d", id, prestige))
                        end
                    end
                    checked = checked + 1
                end
            end
            assert(checked > 50, "the sweep should cover the whole quest line, saw " .. checked)
        end,
    },
}
