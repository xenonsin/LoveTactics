-- Tests for the economy: ONE purse, and the END PURSE that carries the campaign's income.
--
-- IT WAS TWO CURRENCIES AND AN OBJECT. Scrip was the run's own weightless coin, burned at every exit,
-- and the claim this file defended was that the two purses never touched; what ended it was the shelf
-- recut (tools/drop_tier.lua), which took the gear off the houses and so off the Merchant's cart,
-- leaving scrip a currency with one and a half sinks. models/scrip.lua is deleted.
--
-- THEN THE OBJECTS WENT TOO. The campaign's income arrived for a while as VALUABLES -- priced loot with
-- no use, dropped by ends, carried out of the rift and sold at a counter. Weight was the whole argument
-- for them: they took mule slots, so treasure competed with gear, and they rode in the pack, so a wipe
-- dropped the takings on the floor. The mule is deleted and a wipe takes nothing, so both arguments
-- went, and what was left was an inventory step between winning a fight and being paid for it.
-- models/valuable.lua and data/items/valuable are gone; an end pays coin (Spoils.endPurse).
--
-- WHAT THIS FILE DEFENDS NOW is the fence that replaced the second currency, which is MAGNITUDE rather
-- than a purse: nothing underground may ask more than a fraction of the cheapest forge rung, so the
-- comparison the split was built to prevent never gets close enough to bite. Plus the shape the objects
-- left behind, which outlived them -- income is LUMPY and END-WEIGHTED, and climbs steeply with depth.
--
-- The reason it needs pinning rather than reading: the failure mode is silent. An end that quietly
-- stops paying its purse does not crash; the descent simply stops being worth descending.

local Item = require("models.item")
local Vendor = require("models.vendor")
local Spoils = require("models.spoils")
local Player = require("models.player")

return {
    -- ---------------------------------------------------------------------
    -- The purse: one of it, and a ceiling on what the rift may ask
    -- ---------------------------------------------------------------------
    {
        -- THE FENCE, and the whole of what replaced the second currency. A run that spends the
        -- campaign's coin underground is only safe while nothing underground is priced anywhere near
        -- what that coin is really for -- so the ceiling is the invariant.
        --
        -- Anchored to the grader rather than to a typed number, exactly as Spoils.priceCeiling is: an
        -- underground ask may never exceed the price of a house's opening rung, which makes it the
        -- smaller decision by construction and so never a thing to weigh a forge rung against.
        name = "nothing the rift asks for can be weighed against a permanent upgrade",
        fn = function()
            local Grade = require("models.grade")
            assert(Spoils.priceCeiling() == Grade.PRICE_BASE,
                "the ceiling drifted off the opening rung it is defined as")

            -- Every seam that quotes a price underground goes through the clamp, so the claim is about
            -- the clamp: nothing it returns may exceed the ceiling, whatever it was handed.
            local cap = Spoils.priceCeiling()
            for _, ask in ipairs({ 1, 40, cap, cap + 1, 400, 4000 }) do
                assert(Spoils.askingPrice(ask) <= cap,
                    "an ask of " .. ask .. " came back at " .. Spoils.askingPrice(ask)
                    .. ", over the ceiling of " .. cap)
            end
            assert(Spoils.askingPrice(40) == 40, "the clamp moved a price that was already under it")
            assert(Spoils.askingPrice(0) >= 1, "the clamp handed back a free thing")
        end,
    },
    -- ---------------------------------------------------------------------
    -- The end purse: lumpy income, and what the objects left behind
    -- ---------------------------------------------------------------------
    {
        -- ONE PURSE, TWO KINDS OF INCOME, and it is still the split that matters: the grind pays a wage
        -- and the ends pay the campaign. Paying every fight a share instead would flatten the two and
        -- make the whole floor worth the same to walk.
        name = "only an end pays the campaign's purse; an ordinary fight pays a wage",
        fn = function()
            assert(Spoils.endPurse("combat", 5) == 0, "an ordinary fight paid the end purse")
            assert(Spoils.endPurse(nil, 5) == 0, "a kindless fight paid the end purse")
            assert(Spoils.endPurse("treasure", 5) == 0, "a chest paid the end purse")

            for _, kind in ipairs({ "elite", "objective", "general" }) do
                assert(Spoils.endPurse(kind, 1) > 0, "an " .. kind .. " pays nothing at all")
            end
            -- A general closes a circle and pays double, which is the count the old ladder used.
            assert(Spoils.endPurse("general", 5) == 2 * Spoils.endPurse("elite", 5),
                "a general stopped paying two shares where an elite pays one")
        end,
    },
    {
        -- THE CLIMB IS THE GREED. An end's purse is what makes floor eleven worth the risk of floor
        -- eleven, so it rises much faster than an ordinary fight's gold -- and it STOPS, because a
        -- campaign road passes its day in as depth and the calendar runs far past the rift's floors.
        name = "the end purse climbs with depth and goes flat at the bottom of the rift",
        fn = function()
            local last = 0
            for depth = 1, 11 do
                local p = Spoils.endPurse("elite", depth)
                assert(p > last, "floor " .. depth .. " pays " .. p .. ", no better than floor "
                    .. (depth - 1) .. " -- descending must raise the haul")
                last = p
            end
            local bottom = Spoils.endPurse("elite", 11)
            assert(Spoils.endPurse("elite", 40) == bottom and Spoils.endPurse("elite", 99) == bottom,
                "the purse keeps climbing past the deepest floor, so a late campaign road out-pays the "
                .. "bottom of the rift")
            -- The old ladder's own numbers, which these were fitted to: ~150 gold on the first floor,
            -- ~850 on the eleventh. Held loosely -- what is pinned is the band, not the arithmetic.
            assert(Spoils.endPurse("elite", 1) >= 100 and Spoils.endPurse("elite", 1) <= 200,
                "the first floor's end purse left the band the valuable ladder set")
            assert(bottom >= 700 and bottom <= 1000,
                "the deepest floor's end purse left the band the valuable ladder set")
        end,
    },
    {
        -- The purse has to REACH the player, and it reaches them inside the fight's own gold rather
        -- than in a field of its own -- so every reader of `spoils.gold` pays it without being taught.
        name = "an end's purse lands in the gold its fight pays, and an authored purse speaks alone",
        fn = function()
            local common = Spoils.roll({ count = 4, day = 5, floorLevel = 5, kind = "combat" })
            assert((common.gold or 0) > 0, "an ordinary fight paid nothing at all")
            assert(common.valuables == nil, "a fight still rolls valuables, which are deleted")

            local elite = Spoils.roll({ count = 4, day = 5, floorLevel = 5, kind = "elite" })
            assert(elite.gold > Spoils.endPurse("elite", 5),
                "an elite paid " .. elite.gold .. ", no more than its purse alone -- the fight it was "
                .. "fought is not being paid for")
            assert(common.gold < Spoils.endPurse("elite", 5),
                "an ordinary fight out-earns an end's purse, so the ends are not where the income is")

            -- AND AN AUTHORED FIGURE SPEAKS ALONE, which is this file's oldest rule: `rewardGold` short
            -- circuits the roll AND the purse, because now that both are coin an authored payout can
            -- say the whole of what an end pays. The valuables it replaces could not -- they were
            -- objects and the gold was a number, so neither could stand for the other.
            local authored = Spoils.roll({ count = 3, day = 5, floorLevel = 5, kind = "elite",
                rewardGold = 100 })
            assert(authored.gold == 100,
                "an authored elite paid " .. authored.gold .. " against an authored 100")
        end,
    },
    {
        -- An AUTHORED payout on an ordinary fight is exactly itself: no purse, no roll, no jitter.
        name = "an authored rewardGold is paid exactly, and replaces the roll",
        fn = function()
            local s = Spoils.roll({ count = 3, day = 5, kind = "combat", rewardGold = 250 })
            assert(s.gold == 250, "an authored purse did not pay what it was authored at")
        end,
    },
    {
        -- WHAT THIS CASE BECAME. It used to guard the branch that decided WHICH PURSE a fight paid --
        -- scrip below, gold above -- because a purse the prologue could neither spend nor keep would
        -- have been a payout that quietly vanished at the first Gate. There is one purse now, so the
        -- branch is gone and the claim that outlives it is the simpler one underneath: a won fight pays
        -- SOMETHING, wherever it was fought, and depth pays better than the road.
        name = "a fight pays wherever it was fought, and pays deeper for depth",
        fn = function()
            local road = Spoils.roll({ count = 4, day = 6, kind = "combat", loot = {} })
            assert(road.gold > 0, "a campaign road stop pays nothing spendable")

            local floor = Spoils.roll({ count = 4, day = 6, floorLevel = 6, kind = "combat", loot = {} })
            assert(floor.gold > 0, "a descent floor pays nothing spendable")
        end,
    },
    -- ---------------------------------------------------------------------
    -- The valuables: DELETED, and held down
    -- ---------------------------------------------------------------------
    {
        -- WHAT WENT, pinned so nobody restores half of it. A valuable was the one priced thing in the
        -- game whose price meant what a counter PAYS rather than what a shop charges -- so it sold at
        -- par, no shelf could stock it, and three separate rules existed to keep it out of the pools
        -- that read `price` as "shoppable". All three are deleted with it, and the way that breaks
        -- silently is a new item quietly authored `valuable = true` against rules that are gone.
        name = "no item prices from the counter's side of the desk any more",
        fn = function()
            for id, def in pairs(Item.defs) do
                assert(not def.valuable,
                    id .. " declares `valuable`, and nothing reads it: the objects are deleted and an "
                    .. "end pays coin (models/spoils.lua's END_PURSE)")
                assert(def.type ~= "valuable", id .. " is typed as a valuable, which is not a type")
            end
            assert(not pcall(require, "models.valuable"),
                "models.valuable is back -- an end pays its purse in coin now")
        end,
    },
    {
        -- The par exception went with them, so the sell-back rate is one rule again.
        name = "everything priced sells back at half, with no exception left",
        fn = function()
            local sword = Item.instantiate("weapon_iron_sword")
            assert(Vendor.sellValue(sword) == math.floor((sword.price or 0) * 0.5),
                "ordinary gear stopped taking the sell-back haircut, or something else is being paid "
                .. "at par")
        end,
    },
    -- ---------------------------------------------------------------------
    -- The mule: DELETED, and what a valuable's weight was for
    -- ---------------------------------------------------------------------
    --
    -- Three cases stood here: a valuable weighed by its bulk rather than counted, a cap that refused a
    -- three-slot idol to a company with two slots free, and a campaign road where there was no mule to
    -- fill. models/mule.lua is gone -- its cap, its send-home verb and its trip timer -- because all
    -- three existed to bound a bet a wipe collected on, and a wipe collects nothing now. The bulk went
    -- with the objects it weighed; what the stair still counts is FINDS, by the head (game:payToll).

    -- ---------------------------------------------------------------------
    -- The wipe: it costs the count, and nothing a company can carry
    -- ---------------------------------------------------------------------
    {
        -- WHAT WAS DELETED, held down so nobody restores it on noticing that a wipe no longer costs
        -- anything. Two lines went, a year apart and for the same reason. The gold cut went when the
        -- campaign's coin became objects -- the pack took it instead. Then the pack itself went, and
        -- Player.loseHaul with it: docs/the-count.md prices a need at nothing and a decision at a mark,
        -- and charging the FAILURE the haul plus the purse plus a wound on every head was the most
        -- expensive line in the game landing on the company that had just lost.
        --
        -- A lost expedition is billed on the count now (models/descent.lua's COUNT_WIPE) -- two marks
        -- against the stair's one, which is what keeps dying from being the cheaper way home without
        -- reaching into anything the player is holding.
        name = "a wipe takes neither gold nor ore -- it is billed on the count",
        fn = function()
            assert(Player.loseHaul == nil,
                "Player.loseHaul is back: a wipe is priced in marks, never out of a purse or a pack")
            assert(Player.WIPE_LOSS == nil, "and the share it took is gone with it")

            local Descent = require("models.descent")
            assert(Descent.COUNT_WIPE > Descent.COUNT_STAIR,
                "dying must cost more than walking out, or the optimal play is to die where you stand "
                .. "rather than walk back to the stair (models/descent.lua)")
        end,
    },
}
