-- THE BREACH: what happens when the tally fills (models/descent.lua, states/game.lua's ascent branch).
--
-- The count has had a ceiling since it was written and nothing at it -- docs/the-count.md carried it
-- under "What is not built", and the readout's top band deliberately shared a warning with the band
-- below rather than announce an event the game did not deliver. This is that event, and these cases pin
-- the three things about it that can rot silently.
--
-- IT IS ALSO WHAT REPLACED THE FORTIETH DAY. The campaign used to end on a date with every unfelled
-- general standing beside him (models/calendar.lua); the same fight is now reached by letting the floors
-- you keep walking away from fill up. Calendar.generalsStanding sizes it either way, which is why that
-- function survived a deadline it was written for.
--
-- Pure model plus a source scan. Nothing here draws.

local Descent = require("models.descent")
local Calendar = require("models.calendar")
local Arena = require("models.arena")
local Character = require("models.character")

local function run(count) return { floor = 3, seed = 99, count = count, standing = {} } end

-- THE TALLY IS THE COMPANY'S, so the thing isBreached asks is a player rather than a run
-- (models/descent.lua's Descent.count). `run` above is still a run -- breachComposition reads the
-- circles it sealed off `player.descentRun` -- and the two are deliberately separate here so a case
-- cannot quietly hand one where the other is meant.
local function company(count) return { count = count } end

-- The cast, as a set, so a case can ask whether a body is in the fight without caring where.
local function idSet(list)
    local set = {}
    for _, id in ipairs(list) do set[id] = (set[id] or 0) + 1 end
    return set
end

local function source(path)
    local f = assert(io.open(path, "r"), "cannot read " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

return {
    {
        name = "the stair is an exit until the tally is full, and then it is not",
        fn = function()
            assert(not Descent.isBreached(company(0)), "an empty tally breaches nothing")
            assert(not Descent.isBreached(company(Descent.COUNT_MAX - 1)),
                "one short of the ceiling the way up is still a way up")
            assert(Descent.isBreached(company(Descent.COUNT_MAX)), "at the ceiling it is not")
            assert(not Descent.isBreached(nil), "and nil reads as a company that owes nothing")

            -- THE ONE THING THAT MAKES THIS A STATE AND NOT A GAME OVER: descending pays it down, so a
            -- company that meets the breach and loses can always fight its way back under the ceiling.
            local p, r = company(Descent.COUNT_MAX), run(Descent.COUNT_MAX)
            Descent.advance(r, p)
            assert(not Descent.isBreached(p), "reaching a floor prunes, and the stair opens again")
        end,
    },
    {
        name = "what comes up the stair is the Crown and every general still unsealed",
        fn = function()
            local player = { descentRun = run(Descent.COUNT_MAX) }
            local all = idSet(Descent.breachComposition(player, 6))

            assert(all.character_demon_lord == 1, "the Hollow Crown is what came up")
            for _, sin in ipairs(Descent.SINS) do
                assert(all[sin.guardian.lead], sin.id .. "'s general should be standing beside it")
            end

            -- ...AND SEALING A CIRCLE TAKES ONE OUT OF IT. The same reading the retired finale was sized
            -- by, so the two roads to this fight agree about who is in it.
            local sealed = Descent.SINS[1]
            player.descentRun.standing[sealed.vendor] = 1
            local fewer = idSet(Descent.breachComposition(player, 6))
            assert(not fewer[sealed.guardian.lead],
                "a general felled on her own floor does not come up the stair")
            assert(fewer.character_demon_lord == 1, "the Crown still does")
            assert(Calendar.generalsStanding(player) == 6,
                "and the campaign's own count agrees, got " .. Calendar.generalsStanding(player))
        end,
    },
    {
        name = "every body it names is a real blueprint",
        fn = function()
            -- A cast list is a claim about seven other files. Nothing else asserts the generals' ids
            -- outside the SINS table they are read from, so a rename lands here rather than on a board.
            local player = { descentRun = run(Descent.COUNT_MAX) }
            for _, id in ipairs(Descent.breachComposition(player, 15)) do
                assert(Character.defs[id], "the breach names an unknown body: " .. tostring(id))
            end
        end,
    },
    {
        name = "no arena cap can trim a general off the fight",
        fn = function()
            -- REPORTED IS NOT ENFORCED, in the shape that would actually bite: the card names how many
            -- generals are standing, and a fight that then fielded four of them would be a threat
            -- reported and not delivered. What protects it is Arena.clampComposition keeping one of
            -- every DISTINCT id ahead of repeated filler -- so this pins the property rather than the
            -- comment that describes it.
            local player = { descentRun = run(Descent.COUNT_MAX) }
            local full = Descent.breachComposition(player, 15)
            local kept = idSet(Arena.clampComposition(full, Arena.ELITE_CAP))

            assert(kept.character_demon_lord, "the Crown survives the cap")
            for _, sin in ipairs(Descent.SINS) do
                assert(kept[sin.guardian.lead],
                    sin.id .. "'s general was trimmed off the breach by the arena cap")
            end
        end,
    },
    {
        name = "the top band stops sharing its warning with the band below it",
        fn = function()
            -- The readout held one string across the top two bands FOR AS LONG AS the ending was not
            -- built, on the argument that a second string invented early is a promise to keep later.
            -- It is built, so the ceiling says the event and the band under it goes on warning.
            local top = Descent.COUNT_BANDS[1]
            local under = Descent.COUNT_BANDS[2]
            assert(top.at == Descent.COUNT_MAX, "the top band begins at the ceiling")
            assert(type(top.phrase) == "string" and #top.phrase > 0, "and it says something")
            assert(type(under.phrase) == "string" and #under.phrase > 0, "so does the one below")
            assert(top.phrase ~= under.phrase,
                "the ceiling and the warning are different events and must read differently")
        end,
    },
    {
        -- A SOURCE SCAN, because the failure route is the one that skips the bookkeeping. The breach
        -- borrows the way-up tile for the length of its fight, and BOTH exits have to hand it back: the
        -- winning one goes to the credits and never snapshots, but the losing one writes the floor into
        -- the company's map book -- so a wipe that forgot to restore would store a floor whose only exit
        -- is a fight, permanently, and nothing would report it.
        name = "both ends of the breach give the stair back",
        fn = function()
            local text = source("states/game.lua")
            local restores = 0
            for _ in text:gmatch("cell%.encounter = cell%.wasAscent") do restores = restores + 1 end
            assert(restores >= 2,
                "the stair is restored on the win and on the wipe; found " .. restores .. " restore(s)")

            local onLoss = text:match("onLoss = %(not game%.tutorial%) and function%(%)(.-)\n            end")
            assert(onLoss, "could not find the loss handler to read")
            assert(onLoss:find("cell%.wasAscent"),
                "the losing route is the one that snapshots the floor, and it must restore first")
        end,
    },
}
