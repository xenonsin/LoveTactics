-- COUNTED TRIPS AND THE PROWL (approved 2026-10-23).
--
--   * a trip counts only if it won a fight or ended in a wipe (models/gate.lua's Gate.homecoming); an
--     empty dip -- walk in, climb straight out -- counts for nothing;
--   * the city schedule (Player.tripsHome), the Ward's rest and the opening purse all read the counted
--     number, never `runsStarted`, which still advances per descent begun and still seeds the run;
--   * the counted number survives a save, and an old save seeds it from runsStarted;
--   * the prowl deals a fight per PROWL_STEPS (24) of walking, and a floor whose stair is beaten at half
--     that rate -- with the gauge's bands moved to match.

local Gate = require("models.gate")
local Player = require("models.player")
local Descent = require("models.descent")
local Injury = require("models.injury")
local Save = require("models.save")

local function company()
    local p = Player.new()
    p.gold = 0
    return p
end

-- Begin a descent the way the Gate screen does: Descent.new (which advances runsStarted) and the purse.
local function setOut(p)
    local run = Descent.new(p)
    p.descentRun = run
    Gate.payPurse(p, Descent.OPENING_GOLD)
    return run
end

local function comeHome(p, run, wiped)
    local counted = Gate.homecoming(p, run, wiped)
    p.descentRun = nil
    return counted
end

return {
    {
        name = "an empty dip is not a trip; a won fight is; a wipe is",
        fn = function()
            local p = company()
            assert(Player.tripsHome(p) == 0, "a new company has taken no trips")

            local run = setOut(p)
            assert(p.runsStarted == 1, "runsStarted still counts a descent begun")
            assert(not comeHome(p, run, false), "a dip that won nothing counted")
            assert(Player.tripsHome(p) == 0, "an empty dip moved the city clock")

            run = setOut(p)
            Gate.markWon(run)
            assert(comeHome(p, run, false), "a trip that won a fight did not count")
            assert(Player.tripsHome(p) == 1, "a won trip did not move the city clock")

            run = setOut(p)
            assert(comeHome(p, run, true), "a wipe did not count")
            assert(Player.tripsHome(p) == 2, "a wipe did not move the city clock")
            assert(p.runsStarted == 3, "runsStarted stopped counting descents begun")

            -- Once per run: two exits reaching the homecoming cannot count one trip twice.
            run = setOut(p)
            Gate.markWon(run)
            assert(Gate.homecoming(p, run, false) and not Gate.homecoming(p, run, true),
                "one run counted twice")
            assert(Player.tripsHome(p) == 3, "expected three counted trips, got " .. Player.tripsHome(p))
        end,
    },
    {
        name = "the Ward's rest ticks only on a counted trip",
        fn = function()
            local p = company()
            local id = p.roster[1].id
            p.injuries = { [id] = { "injury_blood_loss" } }
            assert(Injury.rest(p, id) == Injury.REST_DESCENTS, "precondition: one injury is a two-trip rest")

            comeHome(p, setOut(p), false)
            assert(Injury.resting(p, id) == Injury.REST_DESCENTS, "an empty dip ticked the Ward")

            local run = setOut(p)
            Gate.markWon(run)
            comeHome(p, run, false)
            assert(Injury.resting(p, id) == Injury.REST_DESCENTS - 1, "a counted trip did not tick the Ward")

            comeHome(p, setOut(p), true)
            assert(Injury.resting(p, id) == 0, "a wipe is a counted trip and did not tick the Ward")
        end,
    },
    {
        name = "the opening purse is topped up on the first descent and after each counted trip only",
        fn = function()
            local p = company()
            local run = setOut(p)
            assert(p.gold == Descent.OPENING_GOLD, "the first descent opened without its purse")
            p.gold = 0
            comeHome(p, run, false) -- an empty dip

            run = setOut(p)
            assert(p.gold == 0, "an empty dip refilled the purse")
            Gate.markWon(run)
            comeHome(p, run, false)

            setOut(p)
            assert(p.gold == Descent.OPENING_GOLD, "a counted trip did not refill the purse")
            -- A company already richer than the purse keeps what it has.
            p.gold = 500
            p.purseTrip = -1
            Gate.payPurse(p, Descent.OPENING_GOLD)
            assert(p.gold == 500, "the purse took gold away")
        end,
    },
    {
        name = "the counted trips survive a save, and an old save seeds them from runsStarted",
        fn = function()
            local p = company()
            p.runsStarted = 5
            p.tripsCounted = 2
            p.purseTrip = 2
            local back = Save.restore(Save.snapshot(p))
            assert(back.tripsCounted == 2, "tripsCounted did not survive: " .. tostring(back.tripsCounted))
            assert(back.purseTrip == 2, "purseTrip did not survive")
            assert(back.runsStarted == 5, "runsStarted did not survive")

            -- Zero counted trips beside five descents begun is NOT an old save and must stay zero.
            p.tripsCounted = 0
            back = Save.restore(Save.snapshot(p))
            assert(back.tripsCounted == 0, "five empty dips were promoted to trips on reload")

            -- An old save: no tripsCounted at all.
            local snap = Save.snapshot(p)
            snap.tripsCounted, snap.purseTrip = nil, nil
            snap.runsStarted = 4
            back = Save.restore(snap)
            assert(back.tripsCounted == 4, "an old save was not seeded from runsStarted")
            assert(Player.tripsHome(back) == 4, "the city clock did not read the seeded count")
        end,
    },
    {
        name = "a won fight on the run survives a save",
        fn = function()
            local run = Descent.new(nil, 4242)
            Gate.markWon(run)
            local back = Descent.restore(Descent.snapshot(run))
            assert(Gate.tripCounts(back, false), "a resumed run forgot it had won a fight")
            assert(not Gate.tripCounts(Descent.restore(Descent.snapshot(Descent.new(nil, 1))), false),
                "a run that won nothing counts after a reload")
        end,
    },
    {
        name = "the prowl deals a fight per 24 steps, and a beaten floor at half that rate",
        fn = function()
            assert(Descent.PROWL_STEPS == 24, "the approved interval is 24")
            local lo = Descent.PROWL_STEPS - Descent.PROWL_JITTER
            local hi = Descent.PROWL_STEPS + Descent.PROWL_JITTER
            for leg = 0, 40 do
                local run = { seed = 9001, leg = leg }
                local t = Descent.prowlTarget(run)
                assert(t >= lo and t <= hi, "leg " .. leg .. " ran " .. t)
                run.stairBeaten = true
                assert(Descent.prowlTarget(run) == 2 * t, "a beaten floor did not double the interval")
            end

            -- The gauge: "close" turns over PROWL_WARN steps before the earliest fight, on either floor.
            for _, beaten in ipairs({ false, true }) do
                local scale = beaten and 2 or 1
                local earliest = lo * scale
                local run = { seed = 1, leg = 0, stairBeaten = beaten or nil }
                run.prowl = 0
                assert(Descent.prowlBand(run) == "calm", "a fresh leg is not calm")
                run.prowl = earliest - Descent.PROWL_WARN - 1
                assert(Descent.prowlBand(run) == "stirring",
                    "one step short of close should be stirring (beaten = " .. tostring(beaten) .. ")")
                run.prowl = earliest - Descent.PROWL_WARN
                assert(Descent.prowlBand(run) == "close", "the warning did not turn over in time")
                -- ...and it is close strictly before any fight can land.
                local probe = { seed = 1, leg = 0, stairBeaten = beaten or nil, prowl = 0 }
                local steps = 0
                repeat steps = steps + 1 until Descent.stepProwl(probe)
                assert(steps >= earliest, "a fight landed before the window opened")
            end
        end,
    },
    {
        name = "a floor's stair reads as beaten off the board itself",
        fn = function()
            local grid = { cells = {
                { {}, { encounter = { kind = "ascent" } } },
                { { encounter = { kind = "combat" } }, {} },
            } }
            assert(not Descent.stairBeaten(grid), "a board with no open stair read as beaten")
            Descent.openStair(grid.cells[2][2])
            assert(Descent.stairBeaten(grid), "an open stair down did not read as beaten")
            assert(not Descent.stairBeaten(nil), "no board, no stair")
            assert(Descent.prowlScale({ stairBeaten = true }) == 2 and Descent.prowlScale({}) == 1,
                "the scale is two on a beaten floor and one otherwise")
        end,
    },
}
