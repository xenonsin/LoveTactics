-- REQUEST RUNS (models/request.lua): a day spent foraging for a house instead of on its errands.
--
-- The calendar made this necessary rather than optional. Forty expeditions against ninety-two quests
-- means the player is always choosing which house to advance -- and until this existed, a day they did
-- not want to give to a story was a day they could not give to anything.
--
-- What these cases guard is mostly what a request DOES NOT pay. It is one short step from "a foraging
-- day tags this house's stock" to "a foraging day advances this house", and that second thing would
-- let a player buy the whole catalogue without running a single line, which is the campaign.

local Request = require("models.request")
local Player = require("models.player")
local Quest = require("models.quest")
local Vendor = require("models.vendor")
local Material = require("models.material")
local Calendar = require("models.calendar")

local function company()
    return { roster = {}, stash = {}, gold = 0, materials = {}, completedQuests = {} }
end

return {
    {
        name = "every house that holds stock can be foraged for, and the Cafe cannot",
        fn = function()
            local houses = Request.houses()
            assert(#houses == 7, "seven houses hold stock, got " .. #houses)
            for _, h in ipairs(houses) do
                assert(h.material and Material.defs[h.material],
                    h.id .. " offers foraging for a stock that does not exist")
                assert(h.id ~= "cafe", "the Cafe sells suppers; there is nothing in the ground for it")
            end
            -- Stable order, or the offer list reshuffles under the cursor between opens.
            local again = Request.houses()
            for i, h in ipairs(houses) do assert(again[i].id == h.id, "the order must hold still") end
        end,
    },
    {
        name = "a request is a quest descriptor the quest registry has never heard of",
        fn = function()
            local q = Request.quest("bastion")
            assert(q and q.request, "it flags itself, which is what states/game.lua branches on")
            assert(Request.isRequest(q.id), "and its id is recognisable from the id alone")
            -- THE PROPERTY THE WHOLE DESIGN RESTS ON. Anything that resolves an id -- the ledger, the
            -- sponsor count, the board -- skips it, because there is nothing to resolve.
            assert(Quest.defs[q.id] == nil, "a request must never be in Quest.defs")
            assert(q.sponsor == "bastion", "but it names the house whose stock it tags")
            assert(q.map and q.map.objective, "and it has an objective, so the extraction rule applies")
            assert((q.map.keyCount or 0) == 0, "no locked-door puzzle on a day out")
        end,
    },
    {
        name = "a house's country holds still, and is never the underworld",
        fn = function()
            for _, h in ipairs(Request.houses()) do
                local biome = Request.biomeFor(h.id)
                assert(biome ~= "underworld",
                    "the underworld is where the last door is, not where anyone runs an errand")
                assert(Request.biomeFor(h.id) == biome,
                    h.id .. " must forage in the same country every time")
            end
        end,
    },
    {
        name = "foraging pays gold and the house's stock, and advances the house not at all",
        fn = function()
            local p = company()
            local q = Request.quest("bastion")
            local house = Material.houseFor(Vendor.get("bastion").class)

            local standingBefore = Player.questsCompleted(p)
            local sponsorBefore = Quest.sponsorProgress(p, "bastion")

            local reward = Request.payout(p, q, { [house] = 4 }, 12, Calendar.DAYS)

            assert(p.gold == Request.GOLD, "the day pays its coin")
            assert(Player.materialCount(p, house) == 4, "and banks what the ground gave up")
            assert(reward.materials[house] == 4, "and the panel is told what it was")

            -- THE THREE THINGS IT MUST NOT DO.
            assert(Player.questsCompleted(p) == standingBefore,
                "foraging finishes no quest, so campaign standing does not move")
            assert(Quest.sponsorProgress(p, "bastion") == sponsorBefore,
                "...and the house's own standing does not either, or the shelf would open for free")
            assert(next(p.completedQuests) == nil, "nothing is written to the quest ledger")
        end,
    },
    {
        name = "a request reports the day, because a day is what it cost",
        fn = function()
            local p = company()
            local reward = Request.payout(p, Request.quest("arcanum"), {}, 9, Calendar.DAYS)
            assert(reward.day == 9 and reward.days == Calendar.DAYS,
                "the advancement bar fills from this, exactly as a quest's does")
            assert(reward.standing == reward.standingBefore,
                "and it reports standing that did not move, rather than omitting it")
        end,
    },
    {
        name = "a request pays no relic, no companion and nothing to name",
        fn = function()
            local q = Request.quest("undercroft")
            assert(q.rewardItems == nil, "a relic is what a LINE hands over")
            assert(q.rewardCharacter == nil, "and so is a companion")
            assert(q.endsLine == nil and q.endsCampaign == nil, "a foraging day ends nothing")
            local reward = Request.payout(company(), q, {}, 1, Calendar.DAYS)
            assert(#reward.received == 0, "so there is nothing for the panel to announce")
        end,
    },
    {
        name = "foraging is worth less coin than the work the houses post",
        fn = function()
            -- Or it would be the efficient way to earn, and the campaign becomes the inefficient one.
            -- The point of a request is the stock it tags, not the purse.
            local worst
            for id, def in pairs(Quest.defs) do
                if def.rewardGold and (not worst or def.rewardGold < worst) then worst = def.rewardGold end
            end
            assert(worst, "the campaign posts paid work")
            assert(Request.GOLD <= worst,
                string.format("a foraging day (%d) must not out-pay the cheapest quest (%d)",
                    Request.GOLD, worst))
        end,
    },
}
