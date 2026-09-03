-- CROSSROADS: the question stop, and the two ways it can be silently broken.
--
-- These dilemmas are DATA WITH FUNCTIONS IN THEM, which is a shape nothing else in the tree quite has,
-- and it fails in a way ordinary data cannot: a resolve that calls `ctx.grantSeal()` parses, loads, ships,
-- and raises the moment a player picks that option -- on a stop they chose, mid-run, with a floor's
-- attrition behind them. Nothing else exercises those closures, so this file is the only thing standing
-- between a typo and that.
--
-- The other failure is quieter. A circle with nothing written for it degrades to "the shared set", which
-- is correct behaviour and indistinguishable from a circle whose pair was never authored -- so the count
-- is asserted per sin rather than in total.

local Crossroads = require("models.crossroads")
local Descent = require("models.descent")

-- The verbs states/game.lua actually binds onto the ctx it hands a resolve. Kept here as a literal, and
-- cross-checked against that file below, so this spec fails if either side moves without the other.
local BOUND = {
    rnd = true, notify = true, gold = true, addGold = true,
    reveal = true, drainParty = true, grantRelic = true, grantSealed = true,
}

local function source(path)
    local ok, text = pcall(function() return love.filesystem.read(path) end)
    return ok and text or nil
end

-- A ctx that RECORDS rather than acts, so a resolve can be checked by what it reached for. Kept from the
-- spec that stood here before the dilemmas were split by circle: asserting a branch's actual outcome is
-- strictly stronger than asserting it did not raise, and the two cases at the bottom are that spec's,
-- rehomed onto the dilemmas that replaced the ones they were written against.
local function recorder(rndValue)
    local log = { gold = 0, drained = 0, revealed = false, relics = 0, sealed = 0, notes = {} }
    return log, {
        rnd = function() return rndValue or 0 end,
        notify = function(m) log.notes[#log.notes + 1] = m end,
        gold = function() return 100 end,
        addGold = function(n) log.gold = log.gold + n end,
        drainParty = function(n) log.drained = log.drained + n end,
        reveal = function() log.revealed = true end,
        grantRelic = function() log.relics = log.relics + 1; return "Test Relic" end,
        grantSealed = function() log.sealed = log.sealed + 1; return true end,
    }
end

-- Every dilemma in the game, in a stable order.
local function everyDilemma()
    local all = {}
    for _, d in ipairs(Crossroads.SHARED) do all[#all + 1] = d end
    for _, sin in ipairs(Descent.SINS) do
        for _, d in ipairs(Crossroads.BY_SIN[sin.id] or {}) do all[#all + 1] = d end
    end
    return all
end

return {
    {
        name = "every dilemma calls only verbs the game actually binds",
        fn = function()
            local text = source("models/crossroads.lua")
            assert(text, "could not read models/crossroads.lua to scan it")
            local seen, n = {}, 0
            for verb in text:gmatch("ctx%.([%a_][%w_]*)") do
                if not seen[verb] then seen[verb] = true; n = n + 1 end
                assert(BOUND[verb],
                    ("a dilemma calls ctx.%s, which states/game.lua does not bind"):format(verb))
            end
            assert(n >= 5, "the scan found almost no ctx calls -- it is probably not scanning anything")
        end,
    },
    {
        name = "...and the game still binds every one of them",
        fn = function()
            -- The other direction, which the scan above cannot see: a verb renamed in states/game.lua
            -- leaves this file's calls pointing at nil, and nil is only found by picking that option.
            local text = source("states/game.lua")
            assert(text, "could not read states/game.lua to scan it")
            for verb in pairs(BOUND) do
                assert(text:find(verb .. " = function", 1, true) or text:find(verb .. " = ", 1, true),
                    ("states/game.lua no longer binds ctx.%s"):format(verb))
            end
        end,
    },
    {
        name = "seven shared dilemmas, and two for every circle the descent has",
        fn = function()
            assert(#Crossroads.SHARED == 7,
                ("%d shared dilemmas, not 7"):format(#Crossroads.SHARED))
            for _, sin in ipairs(Descent.SINS) do
                local own = Crossroads.BY_SIN[sin.id]
                assert(own, ("the %s circle has no dilemmas of its own"):format(sin.id))
                assert(#own == 2, ("%s has %d dilemmas, not 2"):format(sin.id, #own))
            end
            -- Twenty-one in all, which is the figure the count was argued to: four entries against ~30
            -- draws a run was each one met seven times, and the Darkest Dungeon curio set this borrows
            -- from runs about twenty-five over a shorter run.
            local total = #Crossroads.SHARED
            for _, sin in ipairs(Descent.SINS) do total = total + #Crossroads.BY_SIN[sin.id] end
            assert(total == 21, ("%d dilemmas in all, not 21"):format(total))
        end,
    },
    {
        name = "a floor draws the shared set plus its own circle's, and nobody else's",
        fn = function()
            for _, sin in ipairs(Descent.SINS) do
                local pool = Crossroads.pool(sin.id)
                assert(#pool == 9, ("%s draws from %d, not 9"):format(sin.id, #pool))
                -- Its own pair is in there, and no other circle's is.
                local mine = {}
                for _, d in ipairs(Crossroads.BY_SIN[sin.id]) do mine[d] = true end
                local found = 0
                for _, d in ipairs(pool) do if mine[d] then found = found + 1 end end
                assert(found == 2, ("%s's own pair is not in its pool"):format(sin.id))
                for _, other in ipairs(Descent.SINS) do
                    if other.id ~= sin.id then
                        for _, d in ipairs(Crossroads.BY_SIN[other.id]) do
                            for _, p in ipairs(pool) do
                                assert(p ~= d, ("%s's pool holds one of %s's"):format(sin.id, other.id))
                            end
                        end
                    end
                end
            end
        end,
    },
    {
        name = "a board that belongs to no circle still asks a question",
        fn = function()
            -- The campaign's grounds pass no sin, and an unfinished circle would pass one with nothing
            -- written for it. Both have to degrade to the shared set rather than to an empty pool, or a
            -- crossroads on a campaign board opens a modal with no options in it.
            assert(#Crossroads.pool(nil) == 7, "a sinless board draws no dilemmas")
            assert(#Crossroads.pool("a_circle_nobody_wrote") == 7, "an unwritten circle breaks the pool")
            local d = Crossroads.roll(function() return 0.5 end, nil)
            assert(d and d.prompt and d.options and #d.options == 2, "a sinless roll produced no dilemma")
        end,
    },
    {
        name = "every dilemma is a real choice: a prompt and two answers that say what they do",
        fn = function()
            for _, d in ipairs(everyDilemma()) do
                assert(type(d.prompt) == "string" and #d.prompt > 20, "a dilemma has no prompt worth reading")
                assert(#d.options == 2, ("'%s' does not offer two answers"):format(d.prompt))
                for _, o in ipairs(d.options) do
                    -- A name is not a description: the row a player CHOOSES between carries the sentence
                    -- that makes it a choice, so a label with no desc under it is a button, not an offer.
                    assert(type(o.label) == "string" and #o.label > 0, "an option has no label")
                    assert(type(o.desc) == "string" and #o.desc > 10,
                        ("'%s' has a label with nothing under it"):format(tostring(o.label)))
                    assert(type(o.resolve) == "function", "an option does not resolve")
                end
            end
        end,
    },
    {
        name = "roll stays in range at both extremes of rnd",
        fn = function()
            -- Kept from the spec this file replaced. An off-by-one here hands back nil and the modal
            -- opens on nothing, which is the one failure a question stop cannot survive.
            for _, sin in ipairs({ nil, "greed", "pride" }) do
                local pool = Crossroads.pool(sin)
                assert(Crossroads.roll(function() return 0 end, sin) == pool[1], "rnd 0 -> first")
                assert(Crossroads.roll(function() return 0.9999 end, sin) == pool[#pool],
                    "rnd ~1 -> last, never out of range")
            end
        end,
    },
    {
        name = "a wager pays on a good roll and wounds on a bad one",
        fn = function()
            -- The old altar's case, rehomed onto the dilemma that replaced it: the hole in the floor with
            -- something breathing under it. Same shape, same two branches, and the assertion is what the
            -- branch DID rather than that it survived.
            local hole = Crossroads.SHARED[2]
            local log, ctx = recorder(0.9) -- above the 0.55 gate -> it wakes
            hole.options[1].resolve(ctx)
            assert(log.drained > 0 and log.relics == 0, "a losing wager wounds the party and grants nothing")
            log, ctx = recorder(0.1) -- below it -> the find
            hole.options[1].resolve(ctx)
            assert(log.relics == 1 and log.drained == 0, "a winning wager grants, and costs no blood")
        end,
    },
    {
        name = "the dead company: one answer is the kit, the other is the coin",
        fn = function()
            -- The old courier's case, rehomed the same way. Two answers that pay in different currencies
            -- is the shape every dilemma is built on, so one of them is pinned by outcome.
            local dead = Crossroads.SHARED[1]
            local log, ctx = recorder()
            dead.options[1].resolve(ctx)
            assert(log.sealed == 1 and log.gold == 0, "taking the harness should hand up an unread piece")
            log, ctx = recorder()
            dead.options[2].resolve(ctx)
            assert(log.gold == 30 and log.sealed == 0, "taking the tally should pay coin and nothing else")
        end,
    },
    {
        name = "a resolve runs without reaching past its ctx",
        fn = function()
            -- Every branch of every dilemma, driven twice -- once with the rng low and once high, so the
            -- both sides of each `rnd() <` gate are taken -- against a ctx that records rather than acts.
            -- This is what turns the source scan above from "the names are right" into "the closures run".
            for _, roll in ipairs({ 0.01, 0.99 }) do
                for _, purse in ipairs({ 0, 500 }) do
                    local log, ctx = recorder(roll)
                    ctx.gold = function() return purse end
                    -- A bare shelf and a full one both have to be survivable: grantRelic answers nil when
                    -- the run already holds everything eligible, and a resolve that assumes a name came
                    -- back raises on exactly the run that has been going best.
                    ctx.grantRelic = function() log.relics = log.relics + 1; return roll > 0.5 and "A Relic" or nil end
                    ctx.grantSealed = function() log.sealed = log.sealed + 1; return roll > 0.5 end
                    for _, d in ipairs(everyDilemma()) do
                        for _, o in ipairs(d.options) do
                            local ok, err = pcall(o.resolve, ctx)
                            assert(ok, ("'%s' / '%s' raised: %s")
                                :format(d.prompt, o.label, tostring(err)))
                        end
                    end
                    assert(log.gold ~= 0 or log.drained > 0 or log.relics > 0 or log.sealed > 0,
                        "no dilemma did anything at all")
                end
            end
        end,
    },
}
