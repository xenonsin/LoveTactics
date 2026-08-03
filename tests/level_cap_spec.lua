-- Tests for the character LEVEL CAP and the prestige -> level curve (models/growth.lua).
--
-- Levels are derived from the player's global prestige rather than earned per character, and prestige
-- never stops climbing -- New Game+ carries it forward (Player.newGamePlus resets only the quest
-- ledger). Before the cap, `level == prestige` meant a character ended a first campaign at level 138
-- and a second at 276.
--
-- The properties here are the ones the cap was chosen FOR, so they are asserted against the real quest
-- data rather than against remembered numbers: change the campaign's prestige payout and this spec
-- tells you whether the curve still fits it.

local Growth = require("models.growth")
local Quest = require("models.quest")
local Player = require("models.player")
local Character = require("models.character")

-- Total prestige a full campaign pays out, read off the quest blueprints.
local function campaignPrestige()
    local total = 0
    for _, def in pairs(Quest.defs) do total = total + (def.rewardPrestige or 0) end
    return total
end

return {
    {
        name = "the level curve is monotonic, starts at 1, and never passes the cap",
        fn = function()
            assert(Growth.levelForPrestige(1) == 1, "a fresh company is level 1")
            assert(Growth.levelForPrestige(0) == 1, "prestige below the start still floors at level 1")

            local prev = 0
            for prestige = 1, Growth.PRESTIGE_PER_LEVEL * Growth.LEVEL_CAP * 3 do
                local level = Growth.levelForPrestige(prestige)
                assert(level >= prev, "the curve must never run backward")
                assert(level <= Growth.LEVEL_CAP,
                    "prestige " .. prestige .. " resolved to level " .. level .. ", past the cap")
                prev = level
            end
            assert(prev == Growth.LEVEL_CAP, "enough prestige must actually reach the cap")
        end,
    },

    {
        -- The reason the cap is above the campaign's own total rather than at it. A cap reached before
        -- the last quest leaves a dead stretch where finishing a quest advances nobody, which is
        -- precisely the feeling a cap is supposed to prevent.
        name = "a first campaign never hits the ceiling -- no dead stretch of quests",
        fn = function()
            local total = campaignPrestige()
            assert(total > 0, "the campaign should pay prestige at all")

            local endLevel = Growth.levelForPrestige(total)
            assert(endLevel < Growth.LEVEL_CAP, string.format(
                "a full campaign (%d prestige) ends at level %d, which is AT the cap of %d -- the last "
                .. "quests would grant nothing. Raise LEVEL_CAP or PRESTIGE_PER_LEVEL.",
                total, endLevel, Growth.LEVEL_CAP))

            -- ...and the headroom is for New Game+, which carries prestige forward, so it must be
            -- reachable rather than decorative.
            assert(Growth.levelForPrestige(total * 2) == Growth.LEVEL_CAP,
                "a second campaign's prestige should reach the cap the first one left headroom in")
        end,
    },

    {
        name = "levels land often enough to be felt",
        fn = function()
            local total = campaignPrestige()
            local quests = 0
            for _, def in pairs(Quest.defs) do
                if (def.rewardPrestige or 0) > 0 then quests = quests + 1 end
            end

            local levels = Growth.levelForPrestige(total) - 1
            local questsPerLevel = quests / levels
            assert(questsPerLevel <= 3, string.format(
                "%d prestige-paying quests buy %d levels -- one every %.1f quests. Past about three "
                .. "the climb stops reading as progress.", quests, levels, questsPerLevel))
        end,
    },

    {
        name = "the bar's fill has somewhere to go below the cap, and nowhere at it",
        fn = function()
            local into, span = Growth.prestigeIntoLevel(1)
            assert(into == 0 and span == Growth.PRESTIGE_PER_LEVEL, "a fresh company starts an empty step")

            -- Every prestige below the cap sits somewhere inside a step.
            for prestige = 1, Growth.PRESTIGE_PER_LEVEL * (Growth.LEVEL_CAP - 1) do
                local i, s = Growth.prestigeIntoLevel(prestige)
                assert(i and s and i >= 0 and i < s, "prestige " .. prestige .. " fell outside its step")
            end

            -- At the cap there is no next level, so the panel must render a maximum rather than a bar
            -- frozen just short of full.
            local capped = Growth.PRESTIGE_PER_LEVEL * Growth.LEVEL_CAP
            assert(Growth.levelForPrestige(capped) == Growth.LEVEL_CAP, "the fixture should be capped")
            assert(Growth.prestigeIntoLevel(capped) == nil, "a capped company has no step to fill")
        end,
    },

    {
        name = "syncLevels is idempotent and stops advancing at the cap",
        fn = function()
            local p = Player.new()
            p.prestige = 10
            local first = Player.syncLevels(p)
            assert(#first > 0, "the roster should advance the first time")
            assert(#Player.syncLevels(p) == 0, "a re-sync at the same prestige advances nobody")

            -- Push prestige far past what the cap can absorb: everyone lands ON the cap, and further
            -- prestige (a New Game+ run, say) moves nobody.
            p.prestige = Growth.PRESTIGE_PER_LEVEL * Growth.LEVEL_CAP * 2
            Player.syncLevels(p)
            for _, char in ipairs(p.roster) do
                assert(char.level == Growth.LEVEL_CAP,
                    char.name .. " should sit exactly on the cap, not past it")
            end

            p.prestige = p.prestige * 2
            assert(#Player.syncLevels(p) == 0, "prestige beyond the cap advances no one")
        end,
    },
}
