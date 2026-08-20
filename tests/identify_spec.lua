-- Tests for models/identify.lua: the unread gear the rift hands up and the counter that reads it.
--
-- THE CENTRAL TEST IS THE LEAK TEST. Everything else here is arithmetic; the thing this feature can
-- actually get wrong in a way nobody notices is a husk quietly telling the player what it is -- through
-- its name, its tags, its price, its discipline, or a save that rehydrates it in the clear. Those cases
-- are worth more than the rest of this file put together.
--
-- Headless: no love.graphics, no window. Item.defs is the real shelf, so a blueprint change flows in.

local Identify = require("models.identify")
local Item = require("models.item")
local Player = require("models.player")
local Save = require("models.save")
local Spoils = require("models.spoils")

-- A real, sealable blueprint id off the live shelf, so the spec never pins a hand-picked item that a
-- content edit could delete out from under it. Sorted, so the pick is the same every run.
local function sealableId(wantType)
    local ids = {}
    for id, def in pairs(Item.defs) do
        if Identify.canSeal(def) and (not wantType or def.type == wantType) then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids[1]
end

-- A bare player stand-in: the fields identification actually touches, and nothing else.
local function stubPlayer(gold)
    return { gold = gold or 0, stash = {}, visitedVendors = {} }
end

return {
    {
        name = "the module loads headless and every label is a real item type",
        fn = function()
            assert(type(Identify.sealed) == "function", "Identify.sealed is missing")
            for itemType in pairs(Identify.LABELS) do
                local found = false
                for _, def in pairs(Item.defs) do
                    if def.type == itemType then found = true; break end
                end
                assert(found, "no item in the game has type '" .. itemType .. "'")
            end
            -- The one type that must never be sealable. A stack merges by id, and two unread potions
            -- have no id to merge on without giving away that they are the same potion.
            assert(Identify.LABELS.consumable == nil, "consumables must never be sealable")
        end,
    },
    {
        name = "a consumable, a bound relic and an unpriced natural weapon can never be sealed",
        fn = function()
            local checked = { consumable = 0, bound = 0, unpriced = 0 }
            for id, def in pairs(Item.defs) do
                if def.type == "consumable" then
                    checked.consumable = checked.consumable + 1
                    assert(not Identify.canSeal(def), "a consumable was sealable: " .. id)
                end
                if def.bound then
                    checked.bound = checked.bound + 1
                    assert(not Identify.canSeal(def), "a bound relic was sealable: " .. id)
                end
                if not (def.price and def.price > 0) then
                    checked.unpriced = checked.unpriced + 1
                    assert(not Identify.canSeal(def), "an unpriced item was sealable: " .. id)
                end
            end
            assert(checked.consumable > 0 and checked.bound > 0 and checked.unpriced > 0,
                "the shelf no longer has one of the three exempt families; this test stopped testing")
        end,
    },
    {
        -- THE LEAK TEST. A husk may say what TYPE it is and nothing else whatsoever.
        name = "a husk gives away nothing but its type",
        fn = function()
            for _, wantType in ipairs({ "weapon", "armor", "utility", "ability" }) do
                local id = sealableId(wantType)
                if id then
                    local truth = Item.instantiate(id)
                    local husk = Identify.sealed(id, 7)
                    assert(husk, "no husk built for " .. id)
                    assert(husk.name == Identify.LABELS[wantType],
                        "a husk's name is not its type label: " .. tostring(husk.name))
                    assert(not husk.name:find(truth.name, 1, true),
                        "a husk's name contains the true name: " .. tostring(husk.name))
                    assert(husk.name:find("+", 1, true) == nil,
                        "a husk's name carries its forge level: " .. tostring(husk.name))
                    -- Everything a surface could read the answer out of.
                    for _, field in ipairs({ "tags", "discipline", "class", "price", "traits", "aura",
                                             "activeAbility", "bonus", "resist", "flavor", "charge" }) do
                        assert(husk[field] == nil,
                            "a husk leaked `" .. field .. "` for " .. id)
                    end
                    -- ...and the two derived readers that build the Armory's filter chips off them.
                    assert(Item.archetype(husk) == nil, "a husk answered a weapon family")
                    assert(Item.classOf(husk) == nil, "a husk answered a class")
                end
            end
        end,
    },
    {
        name = "the roll never pays a dud and never passes the item ceiling",
        fn = function()
            for floor = 1, 15 do
                local cap = Identify.capFor(floor)
                assert(cap <= Item.MAX_LEVEL, "floor " .. floor .. " caps above the item ceiling")
                assert(cap >= Identify.MIN_LEVEL, "floor " .. floor .. " caps below the floor")
                for _ = 1, 200 do
                    local level = Identify.rollLevel(floor)
                    assert(level >= Identify.MIN_LEVEL,
                        "floor " .. floor .. " rolled a dud: " .. level)
                    assert(level <= cap,
                        "floor " .. floor .. " rolled " .. level .. " above its cap " .. cap)
                end
            end
        end,
    },
    {
        -- Depth is the only thing the player spends to raise the ceiling, so it has to actually move.
        name = "going deeper raises the ceiling and never lowers it",
        fn = function()
            local prev = 0
            for floor = 1, 15 do
                local cap = Identify.capFor(floor)
                assert(cap >= prev, "floor " .. floor .. " caps lower than floor " .. (floor - 1))
                prev = cap
            end
            assert(Identify.capFor(15) > Identify.capFor(1),
                "the bottom of the rift caps no higher than the top")
        end,
    },
    {
        -- Both halves of the overshoot rule: a shallow floor must never hand out the rarest animation
        -- in the game for a coin flip.
        name = "the overshoot cannot fire on a shallow floor",
        fn = function()
            for floor = 1, 3 do
                for level = 0, Item.MAX_LEVEL do
                    assert(not Identify.isOvershoot(level, floor),
                        "floor " .. floor .. " overshot at level " .. level)
                end
            end
            local deep = 15
            assert(Identify.isOvershoot(Identify.capFor(deep), deep),
                "hitting a deep floor's cap is not an overshoot")
            assert(not Identify.isOvershoot(Identify.capFor(deep) - 1, deep),
                "falling short of the cap counted as an overshoot")
        end,
    },
    {
        -- The bill may only read facts the player already has. A fee that moved with the item would
        -- print the answer on the price tag.
        name = "the fee reads the floor and never the item",
        fn = function()
            local cheap, dear
            for id, def in pairs(Item.defs) do
                if Identify.canSeal(def) then
                    if not cheap or def.price < Item.defs[cheap].price then cheap = id end
                    if not dear or def.price > Item.defs[dear].price then dear = id end
                end
            end
            assert(cheap and dear and cheap ~= dear, "the shelf has no price spread to test against")
            assert(Item.defs[dear].price > Item.defs[cheap].price * 2,
                "the spread is too narrow for this test to mean anything")
            local a = Identify.fee(Identify.sealed(cheap, 5))
            local b = Identify.fee(Identify.sealed(dear, 5))
            assert(a == b, "two husks off the same floor were quoted different fees: " .. a .. " vs " .. b)
            assert(Identify.fee(Identify.sealed(cheap, 9)) > a, "a deeper find is not dearer to read")
        end,
    },
    {
        -- The counter is the ONLY door out of a husk. Every ordinary path -- equip, hand over, sell at a
        -- shop -- goes through Player.takeFromStash, which refuses one.
        name = "an unidentified piece leaves the stash only through the counter",
        fn = function()
            local player = stubPlayer(0)
            local husk = Identify.grant(player, sealableId(), 6)
            assert(Player.takeFromStash(player, 1) == nil, "a husk was lifted out of the stash")
            assert(#player.stash == 1 and player.stash[1] == husk, "the husk left the satchel anyway")
            -- ...and the moment it IS named, it is ordinary goods again and comes out like anything else.
            player.gold = 10000
            assert(Identify.read(player, husk), "the naming was refused")
            assert(Player.takeFromStash(player, 1) == husk, "a named piece is still stuck in the stash")
        end,
    },
    {
        -- One number in two directions, and a premium on the third. If the buy-back ever drops to par the
        -- counter stops being a decision and becomes a free locker (see Identify.fee).
        name = "selling pays the fee, and buying back costs more than it paid",
        fn = function()
            local id = sealableId()
            for floor = 1, 15 do
                local player = stubPlayer(0)
                local husk = Identify.grant(player, id, floor)
                local quoted = Identify.fee(husk)
                local paid = Identify.sell(player, husk)
                assert(paid == quoted,
                    "floor " .. floor .. ": sold for " .. tostring(paid) .. ", quoted " .. quoted)
                assert(player.gold == paid, "the sale did not pay into the purse")
                assert(#player.stash == 0, "the sold husk is still in the satchel")
                assert(Identify.shelfCount(player) == 1, "the sold husk is not on the shelf")

                local back = Identify.buyBackPrice(husk)
                assert(back > paid,
                    "floor " .. floor .. ": buying back cost " .. back .. ", no more than the " ..
                    paid .. " it paid -- the counter is a free locker")
                -- Broke by exactly the markup: the sale money alone must not be enough.
                assert(not Identify.buyBack(player, husk), "bought it back on the sale money alone")
                assert(Identify.shelfCount(player) == 1, "a refused buy-back took it off the shelf")
            end
        end,
    },
    {
        name = "a piece bought back is the same piece, seal and level intact",
        fn = function()
            local player = stubPlayer(10000)
            local husk = Identify.grant(player, sealableId(), 11)
            local level, floor = husk.level, Identify.floorOf(husk)
            Identify.sell(player, husk)
            local before = player.gold
            local price = Identify.buyBackPrice(husk)
            assert(Identify.buyBack(player, husk), "the buy-back was refused with gold in the purse")
            assert(player.gold == before - price, "the buy-back did not spend exactly its price")
            assert(Identify.shelfCount(player) == 0, "it is still on the shelf")
            assert(player.stash[1] == husk, "a different table came back than the one that left")
            assert(Identify.isUnidentified(husk), "it came back already named")
            assert(husk.level == level and Identify.floorOf(husk) == floor,
                "the piece was re-rolled while she was holding it")
        end,
    },
    {
        -- A shelf that silently drops its oldest is a shelf that steals. It must both evict and SAY so.
        name = "the shelf keeps only its cap, and reports what fell off",
        fn = function()
            local player = stubPlayer(0)
            local id = sealableId()
            local first
            for i = 1, Identify.SHELF_MAX do
                local husk = Identify.grant(player, id, i)
                if i == 1 then first = husk end
                local _, dropped = Identify.sell(player, husk)
                assert(dropped == nil, "the shelf evicted before it was full (sale " .. i .. ")")
            end
            assert(Identify.shelfCount(player) == Identify.SHELF_MAX, "the shelf is not full")

            local extra = Identify.grant(player, id, 15)
            local _, dropped = Identify.sell(player, extra)
            assert(dropped == first, "the shelf dropped something other than its oldest")
            assert(Identify.shelfCount(player) == Identify.SHELF_MAX, "the shelf grew past its cap")
            for _, held in ipairs(Identify.shelf(player)) do
                assert(held ~= first, "the evicted piece is still on the shelf")
            end
        end,
    },
    {
        name = "a save round-trip keeps the shelf, sealed",
        fn = function()
            local player = Player.new and Player.new() or nil
            assert(player, "Player.new is gone; this test needs a real profile to snapshot")
            player.stash, player.touchstoneShelf = {}, nil
            local id = sealableId()
            local husk = Identify.grant(player, id, 8)
            local level = husk.level
            Identify.sell(player, husk)

            local restored = Save.restore(Save.snapshot(player))
            assert(restored, "the profile did not restore")
            assert(Identify.shelfCount(restored) == 1, "the shelf did not survive the save")
            local back = Identify.shelf(restored)[1]
            assert(Identify.isUnidentified(back), "a shelved piece came back already named")
            assert(back.id == id and back.level == level, "the shelved piece changed across the save")
            assert(Identify.floorOf(back) == 8, "the shelved piece lost the floor it was found on")
        end,
    },
    {
        name = "reading spends the fee, keeps the table, and hands over the true item",
        fn = function()
            local id = sealableId()
            local player = stubPlayer(10000)
            local husk = Identify.grant(player, id, 7)
            local address = husk           -- the exact table the stash and every view is holding
            local level = husk.level
            local fee = Identify.fee(husk)
            local before = player.gold

            assert(Identify.read(player, husk), "the read was refused with gold in the purse")
            assert(player.gold == before - fee, "the read did not spend exactly the fee")
            assert(player.stash[1] == address, "the stash row was replaced instead of re-stamped")
            assert(husk == address, "the live table was swapped out from under its holders")
            assert(not Identify.isUnidentified(husk), "the piece is still sealed after reading")

            -- It must be indistinguishable from one bought at that level and hammered up to it.
            local twin = Item.instantiate(id, 1, level)
            assert(husk.name == twin.name, "a read piece is named differently: " ..
                tostring(husk.name) .. " vs " .. tostring(twin.name))
            assert(husk.level == level, "the read moved the level it was hiding")
            assert(husk.price == twin.price, "a read piece is priced differently")
            assert(husk.description == twin.description, "a read piece describes itself differently")
        end,
    },
    {
        name = "a read that cannot be paid for charges nothing and reveals nothing",
        fn = function()
            local id = sealableId()
            local player = stubPlayer(0)
            local husk = Identify.grant(player, id, 9)
            local ok = Identify.read(player, husk)
            assert(not ok, "a broke player read a piece anyway")
            assert(player.gold == 0, "gold moved on a refused read")
            assert(Identify.isUnidentified(husk), "a refused read revealed the piece")
            assert(husk.name == Identify.LABELS[Item.defs[id].type], "a refused read renamed the piece")
        end,
    },
    {
        -- The whole feature undone by a load, if this ever breaks.
        name = "a save round-trip keeps the seal and the hidden level",
        fn = function()
            local id = sealableId()
            local player = Player.new and Player.new() or nil
            assert(player, "Player.new is gone; this test needs a real profile to snapshot")
            player.stash = {}
            local husk = Identify.grant(player, id, 11)
            local hiddenLevel = husk.level

            local snap = Save.snapshot(player)
            local restored = Save.restore(snap)
            assert(restored, "the profile did not restore")

            local back
            for _, item in ipairs(restored.stash or {}) do
                if Identify.isUnidentified(item) then back = item end
            end
            assert(back, "the sealed piece came back read, or did not come back at all")
            assert(back.id == id, "the restored husk is built on a different blueprint")
            assert(back.level == hiddenLevel, "the hidden level did not survive the save")
            assert(Identify.floorOf(back) == 11, "the floor it was found on did not survive the save")
            assert(back.name == Identify.LABELS[Item.defs[id].type], "the restored husk leaked its name")
        end,
    },
    {
        -- The campaign opts out by having no floor. A husk on a road whose shop is three stops away is a
        -- delayed reward with nowhere to collect it.
        name = "the campaign never seals anything",
        fn = function()
            for _ = 1, 200 do
                for _, kind in ipairs({ "combat", "elite", "treasure" }) do
                    local out = Spoils.rollSealed({ kind = kind, day = 9 })
                    assert(#out == 0, "a campaign stop sealed something (" .. kind .. ")")
                end
            end
            local roll = Spoils.roll({ count = 3, day = 4, kind = "combat" })
            assert(type(roll.sealed) == "table" and #roll.sealed == 0,
                "Spoils.roll sealed something without a floor")
        end,
    },
    {
        name = "a descent chest seals above the band, and never more than one per stop",
        fn = function()
            local seen, rolls = 0, 400
            for _ = 1, rolls do
                local out = Spoils.rollSealed({ kind = "treasure", floorLevel = 9 })
                assert(#out <= 1, "a stop paid more than one unread find")
                for _, find in ipairs(out) do
                    seen = seen + 1
                    local def = Item.defs[find.id]
                    assert(def, "a sealed find named a blueprint that does not exist: " .. tostring(find.id))
                    assert(Identify.canSeal(def), "a chest sealed something unsealable: " .. find.id)
                    assert(find.floor == 9, "the find did not carry the floor it was found on")
                end
            end
            assert(seen > 0, "400 chests on floor 9 sealed nothing at all")
        end,
    },
    {
        -- A wolf pack carries nothing priced, so there is nothing to seal and nothing must be invented.
        name = "a roster carrying nothing sealable pays no unread find",
        fn = function()
            for _ = 1, 200 do
                local out = Spoils.rollSealed({ kind = "elite", floorLevel = 9, enemyUnits = {} })
                assert(#out == 0, "an empty roster paid an unread find out of nowhere")
            end
        end,
    },
    {
        -- The door is for reading unread gear. Before there is any, it is a price quoted for a service
        -- nobody wants; after the counter has been walked into, it stays.
        name = "the door opens on the first unread find and stays once visited",
        fn = function()
            local player = stubPlayer(0)
            assert(not Identify.everFound(player), "the door was open before anything was found")
            local husk = Identify.grant(player, sealableId(), 3)
            assert(Identify.everFound(player), "the door stayed shut on a full satchel")
            Player.markVendorVisited(player, Identify.VENDOR)
            player.gold = 10000
            assert(Identify.read(player, husk), "the naming was refused")
            assert(Identify.count(player) == 0, "the satchel still holds something unnamed")
            assert(Identify.everFound(player), "the door came off the plaza after being used")
        end,
    },
}
