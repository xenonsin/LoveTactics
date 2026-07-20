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
local Character = require("models.character")
local Item = require("models.item")
local AI = require("models.ai")

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

-- A { char, x, y } spawn entry, stripped of the innate signature relic and its trait the way
-- ai_spec's fixture is: a companion summon would add units these cases never asked for.
local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    char.traits = {}
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] and char.inventory[i].bound then char.inventory[i] = nil end
    end
    return { char = char, x = x, y = y }
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

    -- -----------------------------------------------------------------------
    -- Iteration order
    --
    -- The reachable set is keyed "x,y", and several scans over it keep the first candidate on a tie.
    -- pairs() would make those ties depend on string hash order -- stable within one build, promised
    -- by nothing across two machines. Combat.reachableList fixes the order to the board's.
    -- -----------------------------------------------------------------------
    {
        name = "reachableList walks the board top-left to bottom-right, and loses nobody on the way",
        fn = function()
            local c = Combat.new(arena(8, 8, 1), { unit("character_knight", 4, 4) }, {})
            local u = c.units[1]
            local map = Combat.reachable(c, u)
            local list = Combat.reachableList(c, u, map)

            local count = 0
            for _ in pairs(map) do count = count + 1 end
            assert(#list == count, "the list should hold every reachable tile (" .. #list .. " vs " .. count .. ")")
            assert(#list > 4, "a knight in the open should reach a good few tiles")

            for i = 2, #list do
                local a, b = list[i - 1], list[i]
                assert(a.y < b.y or (a.y == b.y and a.x < b.x),
                    "tiles should ascend by row then column, but " .. a.x .. "," .. a.y
                        .. " preceded " .. b.x .. "," .. b.y)
            end
        end,
    },
    {
        -- Same kind of check, same limits: it pins that the answer holds still, not that it is
        -- pinned to the BOARD's order. fromX/fromY says which tile the blow is thrown from, which
        -- decides field bonuses, traps and overwatch, so drift here moves the fight.
        name = "an equal-cost tie over where to strike from is settled the same way every time",
        fn = function()
            local answers = {}
            for i = 1, 12 do
                local c = Combat.new(arena(8, 8, 1), { unit("character_knight", 4, 4) }, {})
                local reach = Combat.attackReach(c, c.units[1], 1)
                local cell = reach["4,6"] -- the reachable/threat sets are keyed "x,y"
                assert(cell, "a knight should be able to threaten 4,6 after moving")
                answers[i] = cell.fromX .. "," .. cell.fromY
            end
            for i = 2, #answers do
                assert(answers[i] == answers[1],
                    "the striking tile drifted between runs: " .. answers[1] .. " then " .. answers[i])
            end
        end,
    },
    {
        -- A stability check, not an order check -- see the structural case below for why. Repeating
        -- in one process cannot expose key-order dependence (a build hashes the same strings the
        -- same way every time), but it does catch nondeterminism that varies run to run: a stray
        -- math.random, a clock read, anything reaching outside the seed.
        name = "an approach with nothing to separate the candidate tiles still lands somewhere fixed",
        fn = function()
            local plans = {}
            for i = 1, 12 do
                local knight = Character.instantiate("character_knight")
                knight.traits = {}
                knight.inventory[1] = Item.instantiate("weapon_iron_sword")
                local bandit = Character.instantiate("character_bandit")
                bandit.traits = {}

                local c = Combat.new(arena(8, 8, 1),
                    { { char = knight, x = 4, y = 8 } }, { { char = bandit, x = 4, y = 1 } })
                local plan = AI.plan(c, c.units[2])
                plans[i] = plan.move and (plan.move.x .. "," .. plan.move.y) or "stay"
            end
            for i = 2, #plans do
                assert(plans[i] == plans[1],
                    "the same board planned two different approaches: " .. plans[1] .. " then " .. plans[i])
            end
        end,
    },
    {
        -- The real guard, and the reason it is written against the source rather than the behaviour:
        -- key-order dependence CANNOT be observed from inside one process. A build hashes "4,6" to
        -- the same bucket every time, so a scan that reads pairs(Combat.reachable(...)) answers
        -- identically all day here and can still disagree with the same code on another machine --
        -- which is exactly the bug that would surface as a mid-duel desync and nothing earlier.
        --
        -- So the invariant is stated where it can be checked: nobody iterates the reachable set with
        -- pairs. Use Combat.reachableList when the order can decide anything; index the map when you
        -- only want a lookup.
        name = "nothing scans the reachable set in key order",
        fn = function()
            local offenders = {}
            for _, path in ipairs({ "models/combat.lua", "models/ai.lua", "states/battle.lua" }) do
                local src = assert(love.filesystem.read(path), "should be able to read " .. path)
                local line = 0
                for text in (src .. "\n"):gmatch("(.-)\r?\n") do
                    line = line + 1
                    if text:find("pairs%s*%(%s*Combat%.reachable%s*%(")
                        or text:find("pairs%s*%(%s*reachable%s*%)") then
                        offenders[#offenders + 1] = path .. ":" .. line .. " -> " .. text:gsub("^%s+", "")
                    end
                end
            end
            assert(#offenders == 0,
                "reachable sets must be walked through Combat.reachableList:\n  "
                    .. table.concat(offenders, "\n  "))
        end,
    },

    -- -----------------------------------------------------------------------
    -- The model finishes before the view starts
    --
    -- A move used to be pushed forward one tile per frame by the battle state's clock, which made
    -- the model's progress a function of the frame rate. Combat.runMove resolves the whole walk at
    -- once and hands back the route for a view to replay at whatever pace it likes.
    -- -----------------------------------------------------------------------
    {
        name = "runMove and moveUnit leave the board in the same place",
        fn = function()
            local function board()
                local c = Combat.new(arena(8, 8, 3), { unit("character_knight", 4, 8) }, {})
                c.turn = { unit = c.units[1], moved = false, moveCost = 0 }
                return c, c.units[1]
            end

            local flat, flatUnit = board()
            local okFlat, costFlat = Combat.moveUnit(flat, flatUnit, 4, 6)
            assert(okFlat, "the flat-out move should be legal")

            local watched, watchedUnit = board()
            local plan = Combat.planMove(watched, watchedUnit, 4, 6)
            assert(plan, "the same move should plan")
            local steps, costWatched = Combat.runMove(watched, plan)

            assert(watchedUnit.x == flatUnit.x and watchedUnit.y == flatUnit.y,
                "both routes should end on the same tile")
            assert(costWatched == costFlat, "and cost the same initiative")
            assert(watchedUnit.char.stats.health.current == flatUnit.char.stats.health.current,
                "and arrive in the same condition")
        end,
    },
    {
        name = "the captured route is the tiles walked, in the order the feet took them",
        fn = function()
            local c = Combat.new(arena(8, 8, 3), { unit("character_knight", 4, 8) }, {})
            local u = c.units[1]
            c.turn = { unit = u, moved = false, moveCost = 0 }

            local plan = Combat.planMove(c, u, 4, 6)
            local startX, startY = u.x, u.y
            local steps = Combat.runMove(c, plan)

            assert(#steps == #plan.path - 1,
                "one step per tile entered, the origin not being one (" .. #steps .. ")")
            assert(steps[1].fromX == startX and steps[1].fromY == startY,
                "the first step leaves the tile the unit was standing on")
            assert(steps[#steps].x == u.x and steps[#steps].y == u.y,
                "the last step lands where the unit ended")

            -- Each step continues from the one before it, one tile at a time.
            for i = 2, #steps do
                local prev, this = steps[i - 1], steps[i]
                assert(this.fromX == prev.x and this.fromY == prev.y,
                    "step " .. i .. " should start where step " .. (i - 1) .. " finished")
                assert(math.abs(this.x - this.fromX) + math.abs(this.y - this.fromY) == 1,
                    "every step crosses exactly one tile")
            end
        end,
    },
    {
        -- The reason the cues are captured per step rather than in one heap: a view replaying the
        -- route has to be able to set each tile's trap off ON that tile.
        name = "the walk drains its cues into the steps, not into the queue behind it",
        fn = function()
            local c = Combat.new(arena(8, 8, 3), { unit("character_knight", 4, 8) }, {})
            local u = c.units[1]
            c.turn = { unit = u, moved = false, moveCost = 0 }
            Combat.runMove(c, Combat.planMove(c, u, 4, 6))
            assert(Combat.drainFx(c) == nil,
                "runMove should leave nothing behind in the cue queue")
        end,
    },
}
