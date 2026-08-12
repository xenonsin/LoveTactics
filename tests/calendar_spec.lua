-- THE CALENDAR (models/calendar.lua): how long there is, what spends it, and what the world does with
-- the number. The foundation of the campaign re-premise -- see the module header for the argument, and
-- docs/progression.md for what it replaced.
--
-- These cases pin the CONTRACT rather than the tuning. Calendar.DAYS and Calendar.FINAL_DANGER are
-- meant to be moved; the properties below have to survive the move, so nothing here asserts either
-- constant's value directly.

local Calendar = require("models.calendar")
local Quest = require("models.quest")
local Save = require("models.save")
local Character = require("models.character")

local function fresh() return { day = 1, completedQuests = {} } end

return {
    {
        name = "a fresh save stands on the first day with every expedition still to spend",
        fn = function()
            local p = fresh()
            assert(Calendar.day(p) == 1, "the first morning is day 1, not day 0")
            assert(Calendar.remaining(p) == Calendar.DAYS,
                "day one has every day left, got " .. Calendar.remaining(p))
            assert(not Calendar.isFinalDay(p) and not Calendar.isOver(p))
        end,
    },
    {
        name = "a player with no day at all reads as the first morning",
        fn = function()
            -- Every save written before the calendar existed, and any caller that hands over a bare
            -- table. It must not read as day 0, which would put the world at level 0.
            assert(Calendar.day({}) == 1, "a missing day is the first day")
            assert(Calendar.day(nil) == 1, "and so is no player at all")
            assert(Calendar.dangerLevel(0) >= 1, "the world is never at level zero")
        end,
    },
    {
        name = "spending walks the calendar to the deadline and then stops",
        fn = function()
            local p = fresh()
            for _ = 1, Calendar.DAYS - 1 do Calendar.spend(p) end
            assert(Calendar.isFinalDay(p), "the last expedition is still to be taken on the final day")
            assert(not Calendar.isOver(p), "the final day is a day, not the end of one")
            assert(Calendar.remaining(p) == 1, "one expedition left, got " .. Calendar.remaining(p))

            Calendar.spend(p)
            assert(Calendar.isOver(p), "past the last day the deadline has passed")
            assert(Calendar.remaining(p) == 0)

            -- The one thing spend refuses: a day that does not exist. Overrunning would put the
            -- danger curve past its own endpoint.
            local past = Calendar.day(p)
            Calendar.spend(p); Calendar.spend(p)
            assert(Calendar.day(p) == past, "the calendar does not run past the deadline")
        end,
    },
    {
        name = "the world hardens on the calendar, monotonically, and lands where it is aimed",
        fn = function()
            local last = 0
            for d = 1, Calendar.DAYS do
                local lv = Calendar.dangerLevel(d)
                assert(lv >= last, string.format("danger fell from %d to %d on day %d", last, lv, d))
                last = lv
            end
            assert(Calendar.dangerLevel(1) == 1, "the first morning is the gentlest")
            assert(Calendar.dangerLevel(Calendar.DAYS) == Calendar.FINAL_DANGER,
                "the last day fights at the level it is anchored on")
            -- THE PROPERTY THAT MAKES THE DEADLINE BITE. Danger is a function of the day alone -- it
            -- reads nothing about the company -- so squandering a week is a week the world pulled
            -- ahead. Scaling to the party would refund exactly what the clock is charging for.
            assert(Calendar.dangerLevel(20) == Calendar.dangerLevel(20),
                "danger is a pure function of the day")
        end,
    },
    {
        name = "the danger curve survives its own constants being retuned",
        fn = function()
            local days, final = Calendar.DAYS, Calendar.FINAL_DANGER
            Calendar.DAYS, Calendar.FINAL_DANGER = 12, 30
            local ok, err = pcall(function()
                assert(Calendar.dangerLevel(1) == 1)
                assert(Calendar.dangerLevel(12) == 30)
                assert(Calendar.dangerLevel(99) == 30, "past the end it holds rather than climbing")
            end)
            Calendar.DAYS, Calendar.FINAL_DANGER = days, final
            assert(ok, tostring(err))
        end,
    },

    {
        name = "campaign standing is a count of finished quests, not the calendar",
        fn = function()
            -- The other half of what prestige used to be. Two questions -- how far into the story, how
            -- dangerous is the world -- that used to share one number and now do not.
            local Player = require("models.player")
            local p = fresh()
            assert(Player.questsCompleted(p) == 0, "nothing finished yet")
            p.completedQuests.quest_a = true
            p.completedQuests.quest_b = true
            assert(Player.questsCompleted(p) == 2, "two finished, got " .. Player.questsCompleted(p))
            -- Spending days must not advance standing: a week of foraging finishes no quests.
            Calendar.spend(p); Calendar.spend(p)
            assert(Player.questsCompleted(p) == 2, "the calendar does not finish quests for you")
        end,
    },

    {
        name = "every general left alive stands beside him at the end",
        fn = function()
            local p = fresh()
            assert(Calendar.generalsStanding(p) == 7, "having felled none, all seven are waiting")
            for i, id in ipairs(Quest.GENERAL_QUESTS) do
                p.completedQuests[id] = true
                assert(Calendar.generalsStanding(p) == 7 - i,
                    "felling one should leave one fewer standing")
            end
            assert(Calendar.generalsStanding(p) == 0, "a clean sweep leaves him alone")
        end,
    },
    {
        name = "the seven generals are real quests, one per house",
        fn = function()
            -- The list is authored rather than derived (see the note on Quest.GENERAL_QUESTS), which is
            -- exactly the kind of thing a renumbering rots. The failure would be a finale quietly
            -- getting easier, so it is checked here rather than trusted.
            assert(#Quest.GENERAL_QUESTS == 7, "seven houses, seven generals")
            local houses = {}
            for _, id in ipairs(Quest.GENERAL_QUESTS) do
                assert(Quest.defs[id], "no such quest: " .. id)
                local house = Quest.defs[id].sponsor
                assert(house, id .. " has no sponsoring house")
                assert(not houses[house], "two generals sponsored by " .. tostring(house))
                houses[house] = true
            end
        end,
    },

    {
        name = "the day survives a save round trip, and an older save opens on the first morning",
        fn = function()
            local p = { roster = { Character.instantiate("character_knight") }, stash = {},
                        gold = 0, prestige = 1, day = 17 }
            local snap = Save.snapshot(p)
            assert(snap.day == 17, "the clock has to persist or every load is a reprieve")
            assert(Save.restore(snap).day == 17, "and come back the same")

            snap.day = nil
            assert(Save.restore(snap).day == 1,
                "a save written before the calendar existed opens on day one")
        end,
    },
}
