-- Tests for models/seed.lua: the one number a playthrough is made of.
--
-- These exist because a seed is a PROMISE made to somebody outside the program -- a player who wants
-- the run they just had again, or who is trying to show somebody a floor with no way down. The promise
-- is only worth anything if it holds all the way to the ground the company walks on, so what is pinned
-- here is the whole chain: the save carries a number, a lap folds it, a descent folds that, and a floor
-- is dealt off the result. Break any link and the seed still LOOKS like it works.
--
-- Pure logic, runs headless.

local Seed = require("models.seed")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Overworld = require("models.overworld")
local Player = require("models.player")
local Save = require("models.save")

local function reserialize(data)
    return Save.decode("return " .. Save.encode(data, 0))
end

-- A board's identity, cheaply: the ground and what is standing on it. Enough to catch a re-roll, which
-- moves every corridor, and enough to catch a re-DEAL, which leaves the corridors and moves the stops.
local function fingerprint(grid)
    local out = {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            local e = c.encounter
            out[#out + 1] = (c.tile or "?") .. (e and (":" .. (e.id or e.kind or "")) or "")
        end
    end
    return table.concat(out, "|")
end

-- A descent floor's ground, dealt exactly as states/game.lua deals it: the floor's own map parameters,
-- seeded from (run, depth). The stop pool is pinned rather than the real one -- what this measures is
-- the carve, and the real pool has its own case below.
local function floorGround(run, depth, player)
    run.floor = depth
    local mp = Descent.floorQuest(run, player).map
    return Overworld.generate({
        biome = mp.biome, cols = mp.cols, rows = mp.rows, layout = mp.carve, spacing = mp.spacing,
        seed = Seed.mix(run.seed, depth), ascent = true, keyCount = 0,
        encounterCount = mp.encounters, cacheCount = mp.cacheCount,
        encounters = { { kind = "combat", weight = 3 }, { kind = "treasure", weight = 1 } },
    })
end

return {
    { name = "a new game is a number somebody can read off a screen", fn = function()
        local p = Player.new()
        assert(type(p.seed) == "number", "a new game should carry a seed, got " .. tostring(p.seed))
        assert(p.seed == math.floor(p.seed), "a seed with a fraction in it cannot be typed back in")
        assert(p.seed >= 0 and p.seed < Seed.SPAN,
            "a seed must fit in " .. Seed.SPAN .. ", got " .. p.seed)
        assert((p.runsStarted or 0) == 0, "a company that has never gone down has begun no descents")
    end },

    { name = "the mixing is fixed, because a seed that changes meaning is a lie", fn = function()
        -- A GOLDEN VECTOR, and the reason it is worth a case: every number below is a promise already
        -- made. A player who wrote a seed down, a bug report that names one, a spec that pins a run --
        -- all of them stop meaning what they meant the moment this arithmetic is "improved". Changing
        -- these values is a decision to invalidate every seed anybody has written down, and it should
        -- take a failing test to make it.
        assert(Seed.mix(1, 2) == 937028, "mix(1,2) moved: " .. Seed.mix(1, 2))
        assert(Seed.mix(0) == 965987, "mix(0) moved: " .. Seed.mix(0))
        assert(Seed.text("quest_the_gate_below") == 763577,
            "text() moved: " .. Seed.text("quest_the_gate_below"))

        -- ...and the tail that stops two laps of one save reading as consecutive numbers. Everything
        -- above it is affine in its inputs, so without the swap these two would be one apart.
        local a, b = Seed.mix(481920, 1), Seed.mix(481920, 2)
        assert(a == 931746 and b == 994934, "the lap vector moved: " .. a .. ", " .. b)
        assert(math.abs(a - b) > 1000, "two laps came out neighbours: " .. a .. " and " .. b)
    end },

    { name = "the seed rides in the save, and a save from before them grows one", fn = function()
        local p = Player.new()
        p.seed = 481920
        p.runsStarted = 3
        local back = Save.restore(reserialize(Save.snapshot(p)))
        assert(back.seed == 481920, "the seed did not survive the save: " .. tostring(back.seed))
        assert(back.runsStarted == 3, "the run count did not survive: " .. tostring(back.runsStarted))

        -- A SAVE WRITTEN BEFORE SEEDS EXISTED has none, and the honest answer is to mint one and keep
        -- it -- not to hand it a zero, and not to have every load look like a different world.
        local old = { seed = nil, ngPlus = 0 }
        local minted = Seed.base(old)
        assert(type(minted) == "number", "an old save should be handed a seed")
        assert(old.seed == minted, "...and should keep the one it was handed")
        assert(Seed.base(old) == minted, "asking twice must not mint twice")
    end },

    { name = "New Game+ is a different rift, and one number still describes the whole save", fn = function()
        local p = Player.new()
        p.seed = 481920

        local seen, lap0 = {}, nil
        for lap = 0, 5 do
            p.ngPlus = lap
            local s = Seed.lap(p)
            assert(not seen[s], "lap " .. lap .. " deals the same rift as an earlier one: " .. s)
            seen[s] = true
            if lap == 0 then lap0 = s end
        end
        assert(lap0 == 481920, "the first lap is the save's own seed, got " .. tostring(lap0))

        -- DERIVED, NOT STORED, which is the whole reason one number can describe a save that has been
        -- round-tripped. A second player on the same seed and the same lap is on the same rift, and
        -- nothing about the lap had to be written down for that to be true.
        local q = Player.new()
        q.seed, q.ngPlus = 481920, 3
        p.ngPlus = 3
        assert(Seed.lap(p) == Seed.lap(q), "the same seed and lap dealt two different rifts")

        local snap = reserialize(Save.snapshot(p))
        assert(snap.lapSeed == nil and snap.lap == nil,
            "the lap's seed is written down somewhere -- a stored copy of a derived value can disagree")
    end },

    { name = "two descents in one playthrough are two rifts, and the playthrough replays as itself",
      fn = function()
        local function threeRuns(seed)
            local p = Player.new()
            p.seed = seed
            local out = {}
            for i = 1, 3 do out[i] = Descent.new(p).seed end
            assert(p.runsStarted == 3, "three descents should count as three, got " ..
                tostring(p.runsStarted))
            return out
        end

        local a = threeRuns(481920)
        assert(a[1] ~= a[2] and a[2] ~= a[3] and a[1] ~= a[3],
            "a second descent in one playthrough dealt the first one again")

        -- The same save, played again from the same number, is the same three descents in the same
        -- order. This is the sentence a shared seed actually promises.
        local b = threeRuns(481920)
        for i = 1, 3 do
            assert(a[i] == b[i], "descent " .. i .. " did not replay: " .. a[i] .. " then " .. b[i])
        end

        -- ...and a different number is a different game.
        local c = threeRuns(481921)
        assert(c[1] ~= a[1], "two seeds dealt the same first descent")
    end },

    { name = "a pinned seed wins, and does not spend a descent", fn = function()
        -- What a spec uses to hold a run still. It must not advance the count, or pinning one run would
        -- move every run after it and a fixture would be changing the game it was measuring.
        local p = Player.new()
        p.seed, p.runsStarted = 481920, 0
        local run = Descent.new(p, 4242)
        assert(run.seed == 4242, "an explicit seed should win, got " .. tostring(run.seed))
        assert(p.runsStarted == 0, "pinning a run spent one")
    end },

    { name = "New Game+ starts the descents over with the lap", fn = function()
        local p = Player.new()
        p.seed = 481920
        local first = Descent.new(p).seed
        assert(p.runsStarted == 1, "precondition: the first descent is counted")

        -- Player.save writes the ACTIVE player, and this case must not touch a real file.
        local prev = Player.active
        Player.active = nil
        Player.newGamePlus(p)
        Player.active = prev

        assert(p.ngPlus == 1, "New Game+ should move the lap")
        assert(p.runsStarted == 0,
            "the second lap's first descent would be dealt as though it were the second")
        assert(Descent.new(p).seed ~= first, "the new lap opened on the old lap's rift")
    end },

    { name = "the first descent walks the poem whatever the seed", fn = function()
        -- THE SEED DEALS THE SHUFFLE, NOT THE ORDER. A first way down is Dante's, authored, and no
        -- number moves it -- the shuffle is what breaking the Crown opens up (Descent.sinOrder). This is
        -- the one thing about a run the seed is deliberately not allowed to decide, so it is asserted
        -- against seeds rather than assumed.
        for _, seed in ipairs({ 0, 1, 481920, 999999 }) do
            local order = Descent.sinOrder(seed, false)
            for i, id in ipairs(Descent.INFERNO) do
                assert(order[i] and order[i].id == id,
                    "seed " .. seed .. " moved the poem at circle " .. i .. ": " ..
                        tostring(order[i] and order[i].id))
            end
        end

        -- ...and once it IS open, the seed is what decides it: every sin exactly once, and not the poem.
        local moved = false
        for _, seed in ipairs({ 1, 7, 481920, 999999 }) do
            local order = Descent.sinOrder(seed, true)
            assert(#order == #Descent.SINS, "a shuffle dropped or invented a circle")
            local seen = {}
            for _, sin in ipairs(order) do
                assert(not seen[sin.id], "a shuffle dealt " .. sin.id .. " twice")
                seen[sin.id] = true
            end
            if order[1].id ~= Descent.INFERNO[1] then moved = true end
        end
        assert(moved, "every shuffled seed still opened on the poem's first circle")
    end },

    { name = "a floor's ground is dealt off the run and the depth, and nothing else", fn = function()
        local player = Player.new()
        local run = Descent.new(player, 909)

        local once = fingerprint(floorGround(run, 3, player))
        local twice = fingerprint(floorGround(run, 3, player))
        assert(once == twice, "the same run and depth laid two different floors")

        -- The depth is half the key: without it every floor of a run would be the same corridors.
        local deeper = fingerprint(floorGround(run, 4, player))
        assert(deeper ~= once, "floor four is floor three again")

        -- ...and so is the run, or two descents on one save would walk the same ground.
        local other = Descent.new(player, 910)
        assert(fingerprint(floorGround(other, 3, player)) ~= once,
            "two runs dealt the same floor three")
    end },

    { name = "the stop pool comes out in one order, on every machine", fn = function()
        -- The generator draws its stops in LIST order, and this list is assembled by walking a keyed
        -- table -- which Lua leaves unspecified. Unsorted, the same seed laid a different floor on
        -- another machine (or after a Lua build changed how it hashes strings), which is a seed that
        -- reproduces everything about a run except the run.
        --
        -- Repeating the call in ONE process cannot catch that (a build hashes the same strings the same
        -- way every time), so what is asserted is the property that makes it impossible: the list is
        -- ordered by something unique.
        local pool = Encounter.pool({ day = 1 })
        assert(#pool > 1, "precondition: the pool holds more than one blueprint")
        for i = 2, #pool do
            assert(pool[i - 1].id < pool[i].id,
                "the pool is not ordered by id at " .. i .. ": " .. tostring(pool[i - 1].id) ..
                    " then " .. tostring(pool[i].id))
        end
    end },

    { name = "nothing on the way to a board reads the clock", fn = function()
        -- The seam this whole file is about, stated where it can be checked. A single `os.time()` on
        -- the path from a save to a board is enough to make every promise above false, and it is
        -- invisible in play: the game still works, it just cannot be replayed. That is exactly how it
        -- got there the first time.
        local offenders = {}
        for _, path in ipairs({ "states/game.lua", "models/overworld.lua" }) do
            local src = assert(love.filesystem.read(path), "should be able to read " .. path)
            local line = 0
            for text in (src .. "\n"):gmatch("(.-)\r?\n") do
                line = line + 1
                -- Comments are where the old behaviour is explained; the ban is on calling it.
                local code = text:gsub("%-%-.*$", "")
                if code:find("os%.time") or code:find("os%.clock") then
                    offenders[#offenders + 1] = path .. ":" .. line .. " -> " .. text:gsub("^%s+", "")
                end
            end
        end
        assert(#offenders == 0,
            "a board dealt off the clock cannot be produced again:\n  " .. table.concat(offenders, "\n  "))
    end },

    { name = "the readout names what it would take to stand here again", fn = function()
        local Debug = require("models.debug")
        assert(Debug.enabled, "precondition: this is a development build")

        local p = Player.new()
        p.seed, p.ngPlus = 481920, 0
        -- At the Gate before a descent: the save's number, and nothing that is not true yet.
        local atGate = Seed.line(p, nil)
        assert(atGate:find("seed 481920", 1, true), "the save's seed is missing: " .. atGate)
        assert(not atGate:find("lap", 1, true), "lap zero is the save's own lap and does not need saying")
        assert(not atGate:find("rift", 1, true), "a rift was named before there was one")

        -- On a floor: the two numbers a board is dealt from (rift, depth) and nothing else needed.
        p.ngPlus = 2
        local run = Descent.new(p, 4242)
        run.floor = 7
        local onFloor = Seed.line(p, run)
        assert(onFloor:find("seed 481920", 1, true), "the save's seed is missing: " .. onFloor)
        assert(onFloor:find("lap 2", 1, true), "the lap is missing: " .. onFloor)
        assert(onFloor:find("rift 4242", 1, true), "the run's seed is missing: " .. onFloor)
        assert(onFloor:find("floor 7", 1, true), "the depth is missing: " .. onFloor)
    end },

    { name = "and a release build has no readout to leak", fn = function()
        -- Gated in ONE place (Seed.line) rather than at each drawing surface, so a second screen that
        -- wants the line cannot ship it by forgetting the `if`. Asserted by flipping the build constant,
        -- which is the only thing that decides it.
        local Debug = require("models.debug")
        local was = Debug.enabled
        Debug.enabled = false
        local line = Seed.line(Player.new(), nil)
        Debug.enabled = was
        assert(line == nil, "a release build printed its seed: " .. tostring(line))
    end },

    { name = "an unseeded board is an error, not a silent roll", fn = function()
        -- The enforcement under all of it. Arena.generateLayout has kept this gate over a battle's
        -- ground for as long as duels have been replayable; the overworld had a quiet `or os.time()`
        -- instead, which is how the seed came to describe everything about a floor except the floor.
        local ok, err = pcall(Overworld.generate, { biome = "forest", cols = 21, rows = 15 })
        assert(not ok, "an unseeded board should raise")
        assert(tostring(err):find("seed"), "the error should name the seed: " .. tostring(err))
    end },
}
