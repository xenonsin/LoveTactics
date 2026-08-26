-- THE CALENDAR (models/calendar.lua): the day, what moves it, and what the world does with the number.
--
-- IT USED TO PIN A DEADLINE -- forty days, a last one, and a state of being past it. The Quest Board
-- those days were bought off is retired and the deadline went with it: what presses on a company now is
-- the count (models/descent.lua, docs/the-count.md), which is a price on a decision rather than a
-- schedule. So the cases below pin the two things that survived -- an uncapped day, and a danger ramp
-- that is a pure function of it -- plus the one that arrived: the day no longer running out.
--
-- These pin the CONTRACT rather than the tuning. Calendar.SPAN and Calendar.FINAL_DANGER are meant to
-- be moved; nothing here asserts either constant's value directly.

local Calendar = require("models.calendar")
local Save = require("models.save")
local Character = require("models.character")

local function fresh() return { day = 1, completedQuests = {} } end

return {
    {
        name = "a fresh save stands on the first morning",
        fn = function()
            local p = fresh()
            assert(Calendar.day(p) == 1, "the first morning is day 1, not day 0")
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
        name = "the day does not run out, and nothing hardens for being rested through",
        fn = function()
            -- THE CASE THAT REPLACED THE DEADLINE. `spend` used to refuse a day past the fortieth, and
            -- the Inn refused a night on the same test. Nights are unbounded now: a beaten company can
            -- buy as many as it can pay for, which is the whole reason the counter exists (a company too
            -- hurt to descend had no other way to reach a morning).
            local p = fresh()
            for _ = 1, Calendar.SPAN * 3 do Calendar.spend(p) end
            assert(Calendar.day(p) == Calendar.SPAN * 3 + 1,
                "every night passes, got day " .. Calendar.day(p))

            -- ...and the world is no worse for it. The ramp holds at its endpoint rather than climbing,
            -- so resting is not a soft deadline wearing a different name.
            assert(Calendar.dangerLevel(Calendar.day(p)) == Calendar.dangerLevel(Calendar.SPAN),
                "past the top of the axis the world holds where it is")
        end,
    },
    {
        name = "spending with no player is a no-op rather than an error",
        fn = function()
            assert(Calendar.spend(nil) == 1, "there is no clock on nobody")
        end,
    },
    {
        name = "the world hardens along the axis, monotonically, and lands where it is aimed",
        fn = function()
            local last = 0
            for d = 1, Calendar.SPAN do
                local lv = Calendar.dangerLevel(d)
                assert(lv >= last, string.format("danger fell from %d to %d on day %d", last, lv, d))
                last = lv
            end
            assert(Calendar.dangerLevel(1) == 1, "the first morning is the gentlest")
            assert(Calendar.dangerLevel(Calendar.SPAN) == Calendar.FINAL_DANGER,
                "the top of the axis fights at the level it is anchored on")
            -- Danger reads the day and nothing about the company: a descent that wants to harden on
            -- depth passes its own number (Descent.dangerLevel) rather than bending this one.
            assert(Calendar.dangerLevel(20) == Calendar.dangerLevel(20),
                "danger is a pure function of the day")
        end,
    },
    {
        name = "the danger curve survives its own constants being retuned",
        fn = function()
            local span, final = Calendar.SPAN, Calendar.FINAL_DANGER
            Calendar.SPAN, Calendar.FINAL_DANGER = 12, 30
            local ok, err = pcall(function()
                assert(Calendar.dangerLevel(1) == 1)
                assert(Calendar.dangerLevel(12) == 30)
                assert(Calendar.dangerLevel(99) == 30, "past the end it holds rather than climbing")
            end)
            Calendar.SPAN, Calendar.FINAL_DANGER = span, final
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
            -- Spending days must not advance standing: a week of resting finishes no quests.
            Calendar.spend(p); Calendar.spend(p)
            assert(Player.questsCompleted(p) == 2, "the calendar does not finish quests for you")
        end,
    },

    {
        -- IT FELLED THEM BY COMPLETING quest_<house>_slot_10, seven times. Those went with the retired
        -- board, and a general is put down on her circle's stair now -- credited to the run's `standing`
        -- keyed by her house's vendor (models/descent.lua's clearFloor). Same count, one route.
        name = "every general left alive stands beside him at the end",
        fn = function()
            local Descent = require("models.descent")
            local p = fresh()
            assert(Calendar.generalsStanding(p) == 7, "having felled none, all seven are waiting")

            p.descentRun = { standing = {} }
            for i, sin in ipairs(Descent.SINS) do
                p.descentRun.standing[sin.vendor] = 1
                assert(Calendar.generalsStanding(p) == 7 - i,
                    "sealing one circle should leave one fewer standing")
            end
            assert(Calendar.generalsStanding(p) == 0, "a clean sweep leaves him alone")
        end,
    },
    {
        -- IT ASSERTED SEVEN REAL QUESTS, one per house, off Quest.GENERAL_QUESTS -- an authored list of
        -- the seven line-enders, kept authored precisely because a renumbering would rot a derivation.
        -- The list is deleted with the quests it named. The seven are Descent.SINS now, and the pairing
        -- it guards is the same one in the other direction: seven circles, seven distinct houses.
        name = "the seven circles are one per house, and every house is a real vendor",
        fn = function()
            local Descent = require("models.descent")
            local Vendor = require("models.vendor")
            assert(#Descent.SINS == 7, "seven sins, seven circles")
            local houses = {}
            for _, sin in ipairs(Descent.SINS) do
                assert(sin.vendor, sin.id .. " names no house")
                assert(Vendor.defs[sin.vendor], sin.id .. " names an unknown house: " .. tostring(sin.vendor))
                assert(not houses[sin.vendor], "two circles pay into " .. tostring(sin.vendor))
                houses[sin.vendor] = true
            end
        end,
    },

    {
        name = "New Game+ opens in the morning rather than on the last campaign's bookkeeping",
        fn = function()
            local Player = require("models.player")
            local p = { roster = {}, stash = {}, gold = 0, completedQuests = { a = true },
                        day = 214, meal = "meal_hunters_stew" }

            Player.finishCampaign(p)
            Player.newGamePlus(p)

            -- Nothing breaks if the number carries -- there is no deadline to be past any more -- but a
            -- second campaign reporting the first one's day count is bookkeeping leaking into a fresh
            -- start, and the day is still what an encounter's `minDay` reads.
            assert(Calendar.day(p) == 1, "the clock starts over")

            -- A supper is bought for one expedition; the last run's is not owed to the first day of
            -- the next.
            assert(p.meal == nil, "the meal does not carry across a new campaign")

            -- And what the player DID still stands. The post-game door is not taken back.
            assert(Player.hasFinishedCampaign(p),
                "beating the game once cannot be undone by playing it again")
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
