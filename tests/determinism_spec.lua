-- Tests for the battle's determinism guarantees: the seeded draw sequence behind Combat.roll, and
-- the two-layer contract between a battle's own generator and the module-level source a spec pins.
--
-- These exist because determinism here is load-bearing rather than nice: a seed is what lets a bug
-- report be replayed, and what will let two machines run one duel and stay in agreement. A stray
-- math.random anywhere in the model would break that silently, and the golden vector below is the
-- tripwire that makes it loud instead.
--
-- Pure logic, runs headless.

local Combat = require("models.combat")

local function arena(cols, rows, seed)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" }, seed = seed }
end

local function draws(fn, count, n)
    local out = {}
    for i = 1, count do out[i] = fn(n) end
    return out
end

local function sameList(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

return {
    {
        name = "the same seed replays the same sequence of draws",
        fn = function()
            local a = draws(Combat.newRandom(2024), 24, 20)
            local b = draws(Combat.newRandom(2024), 24, 20)
            assert(sameList(a, b), "one seed must produce one stream")
        end,
    },
    {
        name = "different seeds diverge",
        fn = function()
            local a = draws(Combat.newRandom(1), 24, 1000)
            local b = draws(Combat.newRandom(2), 24, 1000)
            assert(not sameList(a, b), "two seeds should not walk in step")
        end,
    },
    {
        name = "every draw lands inside 1..n, and n <= 1 is always 1",
        fn = function()
            local rng = Combat.newRandom(7)
            for _ = 1, 500 do
                local v = rng(6)
                assert(v >= 1 and v <= 6 and v == math.floor(v),
                    "a d6 draw must be a whole number in 1..6, got " .. tostring(v))
            end
            assert(rng(1) == 1, "a one-sided die is always 1")
            assert(rng(0) == 1, "an empty range collapses to 1 rather than erroring")
            assert(rng() == 1, "a missing n collapses to 1")
        end,
    },
    {
        -- The generator's exact output is a compatibility surface: two peers running one duel must
        -- draw identically, so changing the algorithm is a protocol break and has to be a deliberate
        -- act. If this fails and the change was intended, update the vector -- but know what it means.
        name = "the draw sequence is the documented Park-Miller stream (golden vector)",
        fn = function()
            -- Cross-checked against an independent Schrage implementation, not merely recorded from
            -- ours. Note the stream starts from seed+1: Park-Miller's state must be non-zero, so
            -- Combat.newRandom maps the seed into 1..2147483646 before the first step.
            local expected = { 23, 74, 43, 55, 62, 72 }
            local got = draws(Combat.newRandom(12345), #expected, 100)
            assert(sameList(got, expected),
                "seed 12345 should draw " .. table.concat(expected, ", ")
                    .. " but drew " .. table.concat(got, ", "))
        end,
    },
    {
        name = "a battle carries its own sequence, seeded off the arena that built it",
        fn = function()
            local a = Combat.new(arena(8, 8, 555), {}, {})
            local b = Combat.new(arena(8, 8, 555), {}, {})
            local c = Combat.new(arena(8, 8, 556), {}, {})
            assert(a.rng, "a seeded arena should install a generator on the combat")

            local ra = draws(function(n) return Combat.roll(a, n) end, 16, 50)
            local rb = draws(function(n) return Combat.roll(b, n) end, 16, 50)
            local rc = draws(function(n) return Combat.roll(c, n) end, 16, 50)
            assert(sameList(ra, rb), "two battles off one seed must roll alike")
            assert(not sameList(ra, rc), "a different seed must roll differently")
        end,
    },
    {
        name = "an unseeded battle has no sequence of its own and falls back to the module source",
        fn = function()
            local c = Combat.new(arena(8, 8, nil), {}, {})
            assert(c.rng == nil, "no seed means no per-battle generator")

            local saved = Combat.random
            Combat.random = function() return 3 end
            local ok, err = pcall(function()
                assert(Combat.roll(c, 10) == 3, "the fallback should answer for an unseeded battle")
            end)
            Combat.random = saved
            if not ok then error(err, 0) end
        end,
    },
    {
        -- The seam three specs already rely on: pinning the module source forces a specific draw
        -- from outside, before any combat exists to reach into. It has to outrank the battle's own
        -- generator or those specs would silently stop controlling anything.
        name = "pinning Combat.random outranks the battle's own generator",
        fn = function()
            local c = Combat.new(arena(8, 8, 999), {}, {})
            local saved = Combat.random
            Combat.random = function() return 2 end
            local ok, err = pcall(function()
                for _ = 1, 8 do
                    assert(Combat.roll(c, 10) == 2, "a pinned source should win over combat.rng")
                end
            end)
            Combat.random = saved
            if not ok then error(err, 0) end

            -- ...and releasing the pin hands the battle back to its own sequence.
            assert(Combat.roll(c, 10) ~= nil, "the battle keeps rolling once the pin is released")
        end,
    },
}
