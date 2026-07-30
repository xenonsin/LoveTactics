-- Tests for models/crossroads.lua: the dilemma data and its resolve functions, driven with a stub ctx
-- that records which helpers each option calls. Pure logic, no window.

local Crossroads = require("models.crossroads")

-- A ctx that records calls, so a resolve can be checked by what it reached for.
local function recorder(rndValue)
    local log = { gold = 0, drained = 0, revealed = false, relics = 0, notes = {} }
    return log, {
        rnd = function() return rndValue or 0 end,
        notify = function(m) log.notes[#log.notes + 1] = m end,
        gold = function() return 100 end,
        addGold = function(n) log.gold = log.gold + n end,
        drainParty = function(n) log.drained = log.drained + n end,
        reveal = function() log.revealed = true end,
        grantRelic = function() log.relics = log.relics + 1; return "Test Relic" end,
    }
end

return {
    {
        name = "every dilemma has a prompt and >=2 options, each with a resolve",
        fn = function()
            assert(#Crossroads.dilemmas >= 3, "there should be a few dilemmas")
            for _, d in ipairs(Crossroads.dilemmas) do
                assert(type(d.prompt) == "string" and #d.prompt > 0, "a dilemma needs a prompt")
                assert(#d.options >= 2, "a dilemma needs at least two options")
                for _, o in ipairs(d.options) do
                    assert(type(o.label) == "string" and type(o.resolve) == "function",
                        "each option needs a label and a resolve")
                end
            end
        end,
    },
    {
        name = "roll returns a dilemma in range for the extremes of rnd",
        fn = function()
            assert(Crossroads.roll(function() return 0 end) == Crossroads.dilemmas[1], "rnd 0 -> first")
            local last = Crossroads.roll(function() return 0.9999 end)
            assert(last == Crossroads.dilemmas[#Crossroads.dilemmas], "rnd ~1 -> last, never out of range")
        end,
    },
    {
        name = "the courier: Take grants a relic, Search takes coin",
        fn = function()
            local courier = Crossroads.dilemmas[1]
            local log, ctx = recorder()
            courier.options[1].resolve(ctx) -- Take the case
            assert(log.relics == 1, "Take the case should grant a relic")
            log, ctx = recorder()
            courier.options[2].resolve(ctx) -- Search the purse
            assert(log.gold == 28, "Search the purse should add 28 gold")
        end,
    },
    {
        name = "the altar wager: a bad roll wounds the party instead of granting",
        fn = function()
            local altar = Crossroads.dilemmas[2]
            local log, ctx = recorder(0.9) -- above the 0.55 threshold -> the scorn branch
            altar.options[1].resolve(ctx)
            assert(log.drained > 0 and log.relics == 0, "a losing wager wounds the party, grants nothing")
            log, ctx = recorder(0.1) -- below threshold -> the favour branch
            altar.options[1].resolve(ctx)
            assert(log.relics == 1 and log.drained == 0, "a winning wager grants a relic, no wound")
        end,
    },
}
