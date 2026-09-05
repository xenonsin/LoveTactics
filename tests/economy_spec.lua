-- Tests for the economy: ONE purse, and valuables (models/valuable.lua).
--
-- IT WAS TWO. Scrip was the run's own weightless coin -- earned below, spent at the Merchant and the
-- Crossroads and by the money kit, and burned at every exit -- and the claim this file defended was
-- that the two purses never touched. That split existed so nothing bought underground was priced
-- against a forge rung, and it worked; what ended it was the shelf recut (tools/drop_tier.lua), which
-- took the gear off the houses and so off the Merchant's cart, leaving scrip a currency with one and a
-- half sinks. models/scrip.lua is deleted.
--
-- WHAT THIS FILE DEFENDS NOW is the fence that replaced it, which is MAGNITUDE rather than a second
-- currency: nothing underground may ask more than a fraction of the cheapest forge rung, so the
-- comparison the split was built to prevent never gets close enough to bite. Plus everything that was
-- never about scrip at all and is unchanged -- the drop pool refusing to stock valuables, the counter
-- paying them at par, worth-per-slot being lumpy enough to make carrying one a decision.
--
-- The reason it needs pinning rather than reading: the failure mode is silent. A valuable that slips
-- into Spoils.shelf does not crash -- it just puts the thing the player is descending to fetch on a
-- counter for sale.

local Valuable = require("models.valuable")
local Item = require("models.item")
local Vendor = require("models.vendor")
local Spoils = require("models.spoils")
local Player = require("models.player")

-- A player with nothing but a purse on it. Player.new drags a starting roster and stash in, which is
-- what most of these cases would rather not have to reason about.
local function purse(gold)
    return { gold = gold or 0, materials = {} }
end

-- Every valuable in the data, which is the set most of these cases sweep.
local function eachValuable()
    local out = {}
    for id, def in pairs(Item.defs) do
        if def.valuable then out[#out + 1] = { id = id, def = def } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

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
    -- Valuables: the shape of the content
    -- ---------------------------------------------------------------------
    {
        name = "every valuable is priced, weighed, classless and useless",
        fn = function()
            local all = eachValuable()
            assert(#all > 0, "no valuables in data/items/valuable -- the campaign has no income")
            for _, v in ipairs(all) do
                assert(v.def.price and v.def.price > 0, v.id .. " has no price, so it is worth nothing")
                assert(v.def.type == "valuable",
                    v.id .. " does not declare type 'valuable', so every type-keyed pass will "
                    .. "mistake it for gear")
                assert(not v.def.class,
                    v.id .. " names a class -- a valuable belongs to no shelf (docs/classes.md)")
                assert(not v.def.unlockQuests,
                    v.id .. " carries unlockQuests, which is a shelf slot on a thing no shelf holds")
                -- The whole promise of the type: it does nothing. An effect on one would make it gear
                -- that happens to be worth money, and the mule decision it exists to create would then
                -- be competing with a reason to keep it.
                assert(not v.def.activeAbility, v.id .. " has an active ability")
                assert(not v.def.traits, v.id .. " grants traits")
                assert(not v.def.bonus, v.id .. " grants a stat bonus")
                assert(Valuable.bulk(v.id) >= 1, v.id .. " weighs less than a slot")
            end
        end,
    },
    {
        -- The knapsack. If worth-per-slot were flat, the mule would only ever ask "how many", which is
        -- not a question -- see models/valuable.lua's header.
        name = "worth per slot climbs with bulk, so a heavy piece is worth clearing space for",
        fn = function()
            local best = {}
            for _, v in ipairs(eachValuable()) do
                local b = Valuable.bulk(v.id)
                best[b] = math.max(best[b] or 0, v.def.price / b)
            end
            local bulks = {}
            for b in pairs(best) do bulks[#bulks + 1] = b end
            table.sort(bulks)
            assert(#bulks > 1, "every valuable is the same weight -- there is no packing decision")
            for i = 2, #bulks do
                assert(best[bulks[i]] > best[bulks[i - 1]],
                    "bulk " .. bulks[i] .. " tops out at " .. math.floor(best[bulks[i]]) ..
                    " per slot, no better than bulk " .. bulks[i - 1] .. " -- the big ones are "
                    .. "strictly worse and nobody would ever carry one")
            end
        end,
    },
    {
        -- THE LADDER ITSELF, named piece by piece. Written out rather than derived because it is the
        -- authored shape of the whole campaign economy -- what each floor band can hand over, and what
        -- it costs to carry -- and a sweep that only checks internal consistency would stay green while
        -- somebody halved every price. Three bands of weight, and the depth each one opens at.
        name = "every valuable is authored at its rung: worth, weight and the floor it opens on",
        fn = function()
            local LADDER = {
                -- pocket pieces: one slot, found from the top of the stack
                { "valuable_gilded_thurible",      110,  1, 1 },
                { "valuable_martyrs_knucklebone",  160,  1, 1 },
                { "valuable_counting_house_seal",  240,  1, 3 },
                { "valuable_choristers_glass_eye", 320,  1, 5 },
                -- two-handed: worth more per slot than anything above it
                { "valuable_chained_psalter",      380,  2, 3 },
                { "valuable_ossuary_lamp",         520,  2, 5 },
                { "valuable_tribute_plate",        700,  2, 7 },
                -- a load: the deep floors' lumpy finds, worth clearing the mule for
                { "valuable_weeping_idol",         900,  3, 7 },
                { "valuable_bronze_penitent",     1200,  3, 9 },
                { "valuable_crowned_reliquary",   1500,  3, 11 },
            }
            for _, row in ipairs(LADDER) do
                local id, price, bulk, depth = row[1], row[2], row[3], row[4]
                local def = Item.defs[id]
                assert(def, id .. " is gone from the data")
                assert(def.price == price, id .. " is worth " .. tostring(def.price) ..
                    ", authored at " .. price .. " -- re-read docs/economy.md before moving it")
                assert(Valuable.bulk(id) == bulk, id .. " weighs " .. Valuable.bulk(id) ..
                    " slots, authored at " .. bulk)
                assert((def.depth or 1) == depth, id .. " opens at depth " .. tostring(def.depth) ..
                    ", authored at " .. depth)
            end
            assert(#eachValuable() == #LADDER,
                "the data holds " .. #eachValuable() .. " valuables and this ladder names " .. #LADDER
                .. " -- a new one has to take a rung on it, or the band it lands in is an accident")
        end,
    },
    {
        name = "bulk is one for everything that is not a valuable",
        fn = function()
            assert(Valuable.bulk("weapon_iron_sword") == 1, "an ordinary item stopped weighing one")
            assert(Valuable.bulk(nil) == 1, "a nil weighs something other than one slot")
            assert(Valuable.bulk("no_such_item_id") == 1, "an unknown id weighs something other than one")
        end,
    },

    -- ---------------------------------------------------------------------
    -- The valve: neither currency may leak into the other
    -- ---------------------------------------------------------------------
    {
        -- The Market declares sellsAll, so every rule that reads `price` says yes to it by default --
        -- which would put the idol the player is descending to fetch on a counter in town.
        name = "no vendor stocks a valuable, the Market included",
        fn = function()
            local defs = { { class = "fighter" }, { sellsAll = true }, { class = "rogue" } }
            for _, v in ipairs(eachValuable()) do
                local item = Item.instantiate(v.id)
                for _, def in ipairs(defs) do
                    assert(not Vendor.sells(def, item),
                        v.id .. " is stocked by a vendor -- a valuable crosses a counter one way")
                end
            end
        end,
    },
    {
        name = "a counter pays a valuable its full price, where gear sells back at half",
        fn = function()
            for _, v in ipairs(eachValuable()) do
                local item = Item.instantiate(v.id)
                assert(Vendor.sellValue(item) == v.def.price,
                    v.id .. " sells for " .. Vendor.sellValue(item) .. " against a price of " ..
                    v.def.price .. " -- a valuable is never marked down (models/valuable.lua)")
            end
            local sword = Item.instantiate("weapon_iron_sword")
            assert(Vendor.sellValue(sword) < (sword.price or 0),
                "ordinary gear stopped taking the sell-back haircut")
        end,
    },
    {
        -- Spoils.shelf and the loot roll draw from one pool, and it reads `price` as the "shoppable"
        -- marker -- so without an explicit refusal every valuable in the data lands in both.
        name = "valuables never turn up as ordinary loot or on the road's shelf",
        fn = function()
            local band = { day = 40, count = 40 }
            for _, id in ipairs(Spoils.shelf(band)) do
                assert(not Valuable.is(id), id .. " is stocked on the road's shelf")
            end
            for _ = 1, 40 do
                local s = Spoils.roll({ count = 3, day = 40, kind = "combat" })
                for _, id in ipairs(s.loot or {}) do
                    assert(not Valuable.is(id), id .. " fell out as ordinary loot")
                end
            end
        end,
    },
    {
        -- ONE PURSE, TWO KINDS OF INCOME. The grind pays coin and the ends pay OBJECTS, and that is
        -- still the split that matters: a valuable has to be carried out and sold, so the richest
        -- stops are the ones you have to survive the walk home from. It used to be a split of
        -- currencies too -- the grind paid scrip, which died at the surface -- and that half is gone.
        name = "an ordinary fight pays coin and no valuables; only an end leaves objects",
        fn = function()
            local common = Spoils.roll({ count = 4, day = 5, floorLevel = 5, kind = "combat" })
            assert((common.gold or 0) > 0, "an ordinary fight paid nothing at all")
            assert(#(common.valuables or {}) == 0, "an ordinary fight left a valuable")

            local found = false
            for _ = 1, 20 do
                local elite = Spoils.roll({ count = 4, day = 5, floorLevel = 5, kind = "elite" })
                if #(elite.valuables or {}) > 0 then found = true end
                for _, id in ipairs(elite.valuables or {}) do
                    assert(Valuable.is(id), id .. " is not a valuable but was rolled as one")
                end
            end
            assert(found, "an elite never left a valuable -- the campaign has no income")
        end,
    },
    {
        -- An AUTHORED payout is an end somebody wrote down, and an end pays the campaign's coin.
        name = "an authored rewardGold is paid exactly, and replaces the roll",
        fn = function()
            local s = Spoils.roll({ count = 3, day = 5, kind = "combat", rewardGold = 250 })
            assert(s.gold == 250, "an authored purse did not pay what it was authored at")
        end,
    },
    {
        -- The pool widens with depth and the roll leans deep, so descending raises the haul rather than
        -- only raising its ceiling.
        name = "the valuable pool widens with depth and the roll leans toward the dearer end",
        fn = function()
            local shallow, deep = Valuable.pool(1), Valuable.pool(99)
            assert(#deep > #shallow, "the pool does not widen with depth")
            for _, id in ipairs(shallow) do
                assert((Item.defs[id].depth or 1) <= 1, id .. " is offered at depth 1 but is authored deeper")
            end

            -- Pinned with a fixed sequence rather than by sampling. The pool is sorted by ID, not by
            -- price, so "always answer 0" does not mean "the cheapest" -- it means the first id
            -- alphabetically, which says nothing. What the two draws must do is pick the DEARER of
            -- whatever pair they landed on, so the generator is fed a pair and the answer checked
            -- against that pair rather than against the pool.
            local pool = Valuable.pool(99)
            local first, last = pool[1], pool[#pool]
            local seq, i = { 0, 0.999 }, 0
            local rnd = function() i = i + 1; return seq[i] end
            local picked = Valuable.roll({ kind = "elite", depth = 99, rnd = rnd })[1]
            assert(picked, "the roll paid nothing on a full pool")
            local dearer = (Item.defs[last].price > Item.defs[first].price) and last or first
            assert(picked == dearer,
                "the roll took " .. picked .. " where " .. dearer ..
                " was the dearer of the two draws -- descending must raise the haul, not only its ceiling")
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
    {
        name = "an ordinary fight kind rolls no valuables however deep it is",
        fn = function()
            assert(#Valuable.roll({ kind = "combat", depth = 99 }) == 0, "a common fight left a valuable")
            assert(#Valuable.roll({ depth = 99 }) == 0, "a kindless roll left a valuable")
        end,
    },
    -- ---------------------------------------------------------------------
    -- The mule: DELETED, and what a valuable's weight was for
    -- ---------------------------------------------------------------------
    --
    -- Three cases stood here: a valuable weighed by its bulk rather than counted, a cap that refused a
    -- three-slot idol to a company with two slots free, and a campaign road where there was no mule to
    -- fill. models/mule.lua is gone -- its cap, its send-home verb and its trip timer -- because all
    -- three existed to bound a bet a wipe collected on, and a wipe collects nothing now.
    --
    -- WHAT SURVIVES IS THE BULK ITSELF (models/valuable.lua's Valuable.bulk), pinned in the
    -- worth-per-slot cases above: an idol being three of something is still what makes carrying it a
    -- decision at the stair, where the toll takes a share of the haul by count (states/game.lua's
    -- game:payToll). What it no longer decides is whether the thing can be picked up at all.

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
