-- Tests for the two-currency economy: scrip (models/scrip.lua) and valuables (models/valuable.lua).
--
-- WHAT THIS FILE IS ACTUALLY DEFENDING is one claim, and it is a claim about what CANNOT happen rather
-- than about what does: the two purses never touch. Scrip cannot become gold, gold cannot be spent
-- underground, and no seam quietly converts one into the other. Every case below is either that
-- invariant or one of the mechanisms it rests on -- the drop pool refusing to stock valuables, the mule
-- weighing them, the counter paying them at par, the surface burning the purse.
--
-- The reason it needs pinning rather than reading: both halves are made of small exceptions scattered
-- across nine files, and the failure mode is silent. A valuable that slips into Spoils.shelf does not
-- crash -- it just puts the thing the player is descending to fetch on a counter for sale.

local Scrip = require("models.scrip")
local Valuable = require("models.valuable")
local Item = require("models.item")
local Vendor = require("models.vendor")
local Spoils = require("models.spoils")
local Mule = require("models.mule")
local Player = require("models.player")

-- A player with nothing but the two purses on it. Player.new drags a starting roster and stash in,
-- which is what most of these cases would rather not have to reason about.
local function purse(scrip)
    return { scrip = scrip or 0, gold = 0, materials = {} }
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
    -- Scrip: the purse itself
    -- ---------------------------------------------------------------------
    {
        name = "scrip adds, spends all-or-nothing, and reads zero on a player that has none",
        fn = function()
            local p = purse()
            assert(Scrip.get(p) == 0, "a fresh purse is not zero")
            assert(Scrip.get(nil) == 0, "a nil player should read zero, not error")

            Scrip.add(p, 40)
            assert(Scrip.get(p) == 40, "add did not credit")

            assert(Scrip.spend(p, 40) == true, "spend refused an affordable price")
            assert(Scrip.get(p) == 0, "spend did not debit")

            Scrip.add(p, 10)
            assert(Scrip.spend(p, 11) == false, "spend allowed an unaffordable price")
            assert(Scrip.get(p) == 10,
                "a REFUSED spend took coin anyway -- a counter that half-charges is worse than one "
                .. "that refuses")
        end,
    },
    {
        -- The clamping half, which is the money kit's contract: a broke party spends its last coppers
        -- and the blow lands soft, rather than the ability refusing to fire.
        name = "scrip take clamps to what is on hand and reports what it actually took",
        fn = function()
            local p = purse(30)
            assert(Scrip.take(p, 12) == 12, "take did not report the full amount it could cover")
            assert(Scrip.get(p) == 18, "take did not debit")
            assert(Scrip.take(p, 500) == 18, "take did not clamp to the balance")
            assert(Scrip.get(p) == 0, "take left something behind after clamping")
            assert(Scrip.take(p, 5) == 0, "take on an empty purse should report nothing taken")
        end,
    },
    {
        -- The rule the whole split rests on. If any exit keeps it, scrip is gold with extra steps.
        name = "the surface burns the purse, and opening a run refills it to the constant",
        fn = function()
            local p = purse(0)
            Scrip.open(p)
            assert(Scrip.get(p) == Scrip.OPENING, "a fresh run did not open on Scrip.OPENING")

            Scrip.add(p, 900)
            local burned = Scrip.clear(p)
            assert(Scrip.get(p) == 0, "the surface did not burn the purse")
            assert(burned == Scrip.OPENING + 900,
                "clear must report what it burned -- a resource that vanishes silently reads as a bug")
        end,
    },
    {
        -- Scrip.add is the payout seam and a payout that computed a negative is a bug, not a charge.
        -- The one caller that needs to take coin away (a crossroads toll) is routed through take.
        name = "scrip add refuses a negative rather than working as a spend",
        fn = function()
            local p = purse(50)
            Scrip.add(p, -20)
            assert(Scrip.get(p) == 50, "add applied a negative amount")
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
        -- The split that funds the two economies: the grind pays run coin, the ends pay the campaign.
        name = "an ordinary fight pays scrip and no gold; only an end leaves valuables",
        fn = function()
            local common = Spoils.roll({ count = 4, day = 5, floorLevel = 5, kind = "combat" })
            assert((common.scrip or 0) > 0, "an ordinary fight paid no scrip")
            assert((common.gold or 0) == 0,
                "an ordinary fight paid campaign gold -- the grind must not fund progression")
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
        name = "an authored rewardGold pays gold and not scrip",
        fn = function()
            local s = Spoils.roll({ count = 3, day = 5, kind = "combat", rewardGold = 250 })
            assert(s.gold == 250, "an authored purse did not pay gold")
            assert((s.scrip or 0) == 0, "an authored purse also paid scrip -- it must pay one of the two")
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
        -- The branch that keeps the prologue honest: above ground there is no Merchant, no Crossroads
        -- and no exit to burn a purse at, so scrip there would be a payout that can be neither spent nor
        -- kept. `floorLevel` is the tell, and it is set on every descent fight by Descent.floorQuest.
        name = "a fight pays the purse of the place it was fought in",
        fn = function()
            local road = Spoils.roll({ count = 4, day = 6, kind = "combat", loot = {} })
            assert(road.gold > 0 and (road.scrip or 0) == 0,
                "a campaign road stop stopped paying gold -- the prologue's fights pay nothing spendable")

            local floor = Spoils.roll({ count = 4, day = 6, floorLevel = 6, kind = "combat", loot = {} })
            assert(floor.scrip > 0 and (floor.gold or 0) == 0,
                "a descent floor paid campaign gold -- the grind must not fund progression")
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
    -- The mule: valuables have weight
    -- ---------------------------------------------------------------------
    {
        -- The load is measured in SLOTS now, off Player.atRisk's `id#level` keys. A regression here is
        -- silent: a three-slot idol weighing one just means the cap never binds.
        name = "the mule weighs a valuable by its bulk, and everything else by one",
        fn = function()
            local heavy, light = nil, nil
            for _, v in ipairs(eachValuable()) do
                if Valuable.bulk(v.id) >= 3 then heavy = v.id end
                if Valuable.bulk(v.id) == 1 then light = v.id end
            end
            assert(heavy and light, "the data has no heavy and light pair to weigh against each other")

            local player = { roster = {}, stash = {}, materials = {}, gold = 0, scrip = 0 }
            local entry = { roster = {}, stash = {}, materials = {}, gold = 0 }
            local run = { entry = entry }

            assert(Mule.load(player, run) == 0, "an untouched company is already carrying something")

            table.insert(player.stash, Item.instantiate(light))
            assert(Mule.load(player, run) == 1, "a one-slot valuable did not weigh one")

            table.insert(player.stash, Item.instantiate(heavy))
            assert(Mule.load(player, run) == 1 + Valuable.bulk(heavy),
                "a " .. Valuable.bulk(heavy) .. "-slot valuable weighed something else -- the cap "
                .. "will never bind")

            table.insert(player.stash, Item.instantiate("weapon_iron_sword"))
            assert(Mule.load(player, run) == 2 + Valuable.bulk(heavy),
                "an ordinary item stopped weighing exactly one slot")
        end,
    },
    {
        name = "canTakeItem asks about the thing, not about a count",
        fn = function()
            local heavy
            for _, v in ipairs(eachValuable()) do
                if Valuable.bulk(v.id) >= 3 then heavy = v.id end
            end
            assert(heavy, "no three-slot valuable to test the refusal with")

            local player = { roster = {}, stash = {}, materials = {}, muleCapacity = 8 }
            local run = { entry = { roster = {}, stash = {}, materials = {} } }
            -- Fill to two free slots.
            for _ = 1, 6 do table.insert(player.stash, Item.instantiate("weapon_iron_sword")) end
            assert(Mule.room(player, run) == 2, "the fixture did not leave two slots")
            assert(Mule.canTakeItem(player, "weapon_iron_sword", run),
                "a one-slot item was refused with two slots free")
            assert(not Mule.canTakeItem(player, heavy, run),
                "a three-slot valuable fit in two slots -- bulk is not reaching the check")
        end,
    },
    {
        -- Outside a descent there is no mule and never was, and every grant seam in the campaign asks.
        name = "weight is free outside a descent",
        fn = function()
            local player = { roster = {}, stash = {}, materials = {} }
            assert(Mule.canTakeItem(player, "valuable_crowned_reliquary", nil),
                "a valuable was refused on a campaign road, where there is no mule to fill")
        end,
    },

    -- ---------------------------------------------------------------------
    -- The wipe: the pack is the penalty now
    -- ---------------------------------------------------------------------
    {
        -- The line that was DELETED, which is the kind of change a spec has to hold down or somebody
        -- restores it on noticing that a wipe no longer costs coin. It costs the coin's whole source:
        -- the valuables are in the pack, and the pack hits the floor (Descent.dropPack).
        name = "a wipe no longer takes gold, and still takes ore",
        fn = function()
            local before = { gold = 100, materials = { material_iron_scrap = 2 } }
            local player = { gold = 900, materials = { material_iron_scrap = 10 } }

            local taken = Player.loseHaul(player, before)
            assert(player.gold == 900,
                "a wipe took gold -- the pack is the penalty now, and billing both charges one loss "
                .. "twice (models/player.lua)")
            assert(taken.gold == 0, "loseHaul reported taking gold it did not take")
            assert(player.materials.material_iron_scrap < 10, "a wipe stopped taking ore")
        end,
    },
}
