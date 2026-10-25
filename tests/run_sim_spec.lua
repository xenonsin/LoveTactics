-- Tests for tools/run_sim.lua: one fresh save, one descent, capped at floor one so it stays quick.
--
-- What is held here is the TOOL's contract, not the balance it measures: the report carries every field
-- the printout reads, the numbers are the kind of numbers they claim to be, and the harness puts back
-- every stub it swapped in -- a sim that left states.battle, Player.save or Combat.FORCE_HIT replaced
-- would quietly change every spec that runs after this one.

local RunSim = require("tools.run_sim")
local Combat = require("models.combat")
local Player = require("models.player")

local cached
local function result()
    if not cached then
        cached = RunSim.simulateSave(RunSim.SEED_BASE, 1, false, { maxFloor = 1 })
    end
    return cached
end

return {
    { name = "one run of one save reports every field, and sanely", fn = function()
        local battleBefore = package.loaded["states.battle"]
        local saveBefore, forceBefore = Player.save, Combat.FORCE_HIT
        local res = result()
        assert(res and res.runs and #res.runs == 1, "no run came back")
        local run = res.runs[1]
        for _, field in ipairs({ "ending", "floor", "cleared", "battles", "walkOffs", "wins", "smokes", "relics",
                                 "goldStart", "goldEnd", "party", "company", "fights", "roadDraughts" }) do
            assert(run[field] ~= nil, "the report has no " .. field)
        end
        local endings = { climb = true, wipe = true, crown = true, home = true }
        assert(endings[run.ending], "the run ended in an unknown way: " .. tostring(run.ending))
        assert(run.floor >= 1, "the company never stood on floor one")
        assert(run.cleared >= 0 and run.cleared <= run.floor, "cleared " .. run.cleared .. " of " .. run.floor)
        assert(run.wins <= run.battles, "more wins than fights")
        assert(run.battles + run.walkOffs >= 1, "a floor was crossed without a single fight")
        assert(run.party >= 1 and run.party <= 4, "an expedition of " .. run.party)
        assert(type(run.relics) == "table", "relics is not a list")
        assert(run.company.levels:find("%d"), "no levels in the company snapshot")
        for _, f in ipairs(run.fights) do
            local known = { win = true, loss = true, smoke = true, stall = true, crash = true }
            assert(known[f.result],
                "a fight resolved as " .. tostring(f.result))
        end
        -- The harness put the world back.
        assert(package.loaded["states.battle"] == battleBefore, "states.battle is still the sim's stub")
        assert(Player.save == saveBefore, "Player.save is still stubbed")
        assert(Combat.FORCE_HIT == forceBefore, "Combat.FORCE_HIT was not restored")
    end },

    { name = "the gold ledger names every coin a run earned, and the wage lands under a fight purse", fn = function()
        local res = result()
        local run = res.runs[1]
        local led = run.gold
        assert(led and led.bySource and led.byFloor, "the run carries no gold ledger")
        local sum, floorSum = 0, 0
        for label, n in pairs(led.bySource) do
            assert(type(label) == "string" and #label > 0 and n > 0, "a ledger line is unnamed or empty")
            sum = sum + n
        end
        for _, t in pairs(led.byFloor) do for _, n in pairs(t) do floorSum = floorSum + n end end
        assert(sum == led.total and floorSum == led.total, "the ledger's lines do not add up to its total")
        -- A won fight's lump was split into its parts rather than landing under game.lua's raw name.
        if run.wins > 0 and run.goldWon > 0 then
            local fights = 0
            for label, n in pairs(led.bySource) do
                if label:find("^fight purse") or label:find("^end purse") then fights = fights + n end
            end
            assert(fights > 0, "a won fight paid and no fight purse was credited")
        end
        local totals = RunSim.goldTotals(res.runs and { res } or {})
        assert(totals.total == led.total and totals.runs == 1, "goldTotals does not read the run back")
    end },

    { name = "the policy prints, and names its thresholds", fn = function()
        local lines = RunSim.policyLines()
        assert(#lines >= 5, "the policy block is too short to be the policy")
        local text = table.concat(lines, "\n")
        assert(text:find(tostring(math.floor(RunSim.POLICY.climbBelow * 100)) .. "%%"),
            "the climb-out threshold is not printed")
        assert(text:find("Smoke"), "the smoke rule is not printed")
    end },
}
