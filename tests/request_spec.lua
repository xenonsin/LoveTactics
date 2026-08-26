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

            local reward = Request.payout(p, q, { [house] = 4 })

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
        -- IT PINNED `day` AND `days` HERE, because a request run reported the calendar exactly as a
        -- quest did and the advancement panel drew a bar from the pair. There is no deadline and no bar
        -- (models/calendar.lua); what a payout still owes the panel is a standing that did not move,
        -- reported rather than omitted -- an absent field and an unmoved one read the same to a caller
        -- and mean opposite things.
        name = "a request reports standing that did not move rather than omitting it",
        fn = function()
            local p = company()
            local reward = Request.payout(p, Request.quest("arcanum"), {})
            assert(reward.standing == reward.standingBefore,
                "a foraging day finishes no quest, and says so")
            assert(reward.day == nil and reward.days == nil,
                "and it does not report a calendar reading nothing reads")
        end,
    },
    {
        name = "a request pays no relic, no companion and nothing to name",
        fn = function()
            local q = Request.quest("undercroft")
            assert(q.rewardItems == nil, "a relic is what a LINE hands over")
            assert(q.rewardCharacter == nil, "and so is a companion")
            assert(q.endsLine == nil and q.endsCampaign == nil, "a foraging day ends nothing")
            local reward = Request.payout(company(), q, {})
            assert(#reward.received == 0, "so there is nothing for the panel to announce")
        end,
    },
    -- -----------------------------------------------------------------------
    -- Several requests, one board, partial completion
    -- -----------------------------------------------------------------------
    {
        name = "the day's postings are fixed by the day, so a player can plan around them",
        fn = function()
            local p = company()
            local a = Request.offer(p, 12)
            local b = Request.offer(p, 12)
            assert(#a == 7, "one posting per house that holds stock, got " .. #a)
            for i, req in ipairs(a) do
                assert(req.id == b[i].id and req.quota == b[i].quota,
                    "the same day must post the same work -- rolling it fresh on every open makes the "
                    .. "offer a slot machine and 'I will come back for that tomorrow' meaningless")
                assert(Request.KINDS[req.kind], req.house .. " asks in a shape nothing can build")
            end
            -- A different day is different work, and later work is heavier.
            assert(Request.offer(p, 38)[1].quota > a[1].quota, "a late request is a real trip")
        end,
    },
    {
        name = "a house asks in the shape its sin implies",
        fn = function()
            -- Not decoration: the shape is what the board has to carry, so a house whose kind changes
            -- changes what its day looks like. Stated as a claim rather than derived, and checked so a
            -- new house cannot be added without somebody deciding what it wants.
            for _, house in ipairs(Request.houses()) do
                local kind = Request.KIND_BY_HOUSE[house.id]
                assert(kind and Request.KINDS[kind],
                    house.id .. " has no request shape -- what does this house actually want?")
            end
            assert(Request.KIND_BY_HOUSE.bastion == "rescue", "sloth guards: people brought out alive")
            assert(Request.KIND_BY_HOUSE.colosseum == "fell", "wrath: a named thing, dead")
        end,
    },
    {
        name = "an expedition is assembled from what was accepted, and the board does not grow for it",
        fn = function()
            local p = company()
            local offer = Request.offer(p, 10)
            local byHouse = {}
            for _, r in ipairs(offer) do byHouse[r.house] = r end

            local accepted = { byHouse.bastion, byHouse.alchemist, byHouse.colosseum }
            local quest = Request.expedition(accepted)
            assert(quest and quest.request, "the day is one expedition, flagged as a request")
            assert(#quest.requests == 3, "carrying all three, so the payout can ask each one")

            -- EVERY HOUSE ASKING GETS STOCK DEALT ACROSS THE CACHES THE BOARD ALREADY HAS. No cache
            -- count is passed, which is the point: three houses share four or five caches rather than
            -- the board growing to give each of them their own.
            assert(#quest.map.houseMaterials == 3, "three houses' stock on one board")
            assert(quest.map.cacheCount == nil,
                "the board must NOT be told to grow -- sharing the caches is the whole tension")

            -- The kinds that need content on the board seeded it; harvest needed none.
            local always = quest.map.encounters.always
            assert(#always >= 2, "rescue and fell each put something on the board, got " .. #always)
        end,
    },
    {
        name = "each request is paid on its own, so two of three is a real outcome",
        fn = function()
            local p = company()
            local offer = Request.offer(p, 1)
            local byHouse = {}
            for _, r in ipairs(offer) do byHouse[r.house] = r end
            local quest = Request.expedition({ byHouse.alchemist, byHouse.arcanum, byHouse.bastion })

            -- The run brought back the Crucible's quota and none of the Arcanum's, and saved nobody.
            local run = { haul = { [byHouse.alchemist.material] = byHouse.alchemist.quota } }
            local met, missed, gold = Request.settle(p, quest, run)

            assert(#met == 1 and met[1].house == "alchemist", "the filled one pays")
            assert(#missed == 2, "and the other two simply do not")
            assert(gold == byHouse.alchemist.gold, "paid per request, never per trip")
            assert(p.gold == gold, "and that is all the coin the day handed over")
        end,
    },
    {
        name = "turning back early and clearing the board go through the same arithmetic",
        fn = function()
            -- THE PROPERTY PARTIAL COMPLETION RESTS ON. There is no "the expedition succeeded" flag
            -- anywhere -- what was carried out is asked against each quota at the payout, so a player
            -- who left at the fourth stop is not on a different path from one who cleared it.
            local p = company()
            local req -- a HARVEST request: the kind whose progress is a count of what came home
            for _, r in ipairs(Request.offer(p, 1)) do
                if r.kind == "harvest" then req = r break end
            end
            assert(req, "at least one house asks for stock")

            assert(not Request.met({ haul = { [req.material] = req.quota - 1 } }, req),
                "one short of the quota is not met")
            assert(Request.met({ haul = { [req.material] = req.quota } }, req), "exactly the quota is")
            assert(Request.met({ haul = { [req.material] = req.quota + 5 } }, req), "and more is too")
            assert(not Request.met({}, req), "and a run that found nothing meets nothing")
        end,
    },
    {
        name = "three requests cannot all be filled by a board's caches without taking every one",
        fn = function()
            -- THE ARITHMETIC THE WHOLE DESIGN RESTS ON, checked rather than asserted in prose. A board
            -- carries about four and a half caches (`. board-report`), each paying 1-3 of its house's
            -- stock; three houses each wanting `quota` cannot all be satisfied unless the company takes
            -- essentially everything, including the guarded spurs.
            local CACHES, HOUSE_MAX = 4, 3 -- Overworld's CACHE_HOUSE_MAX at the deepest detour
            local offer = Request.offer(company(), 1)
            local quota = offer[1].quota
            local perHouse = math.floor(CACHES / 3) * HOUSE_MAX -- best case, dealt round-robin
            assert(perHouse < quota * 3,
                "if three quotas fit comfortably on one board there is no decision to make")
            assert(perHouse >= quota,
                "...but one of them must be fillable, or accepting three is never worth doing")
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
