-- Tests for the Party screen's model-level economy and the quest party-composition rules. The UI
-- (ui/panels/party.lua, states/party_select.lua) is love.graphics-bound and mostly not exercised
-- here; what it delegates to -- Vendor.sellValue, the buy/sell gold+stash moves, the party
-- cap/duplicate guard, and the save round trip -- is pure logic and lives below. The panel's few
-- pure, love-free helpers (regionCross edge-crossing, equipDelta filter) are covered at the end.

local Player = require("models.player")
local Vendor = require("models.vendor")
local Item = require("models.item")
local Character = require("models.character")
local Save = require("models.save")
local Party = require("ui.panels.party")

-- A priced, non-stackable item id (so buying/selling doesn't merge into a consumable stack), and an
-- item id with no price (never for sale). Found from data so the test survives content edits.
local pricedId, noPriceId
for id, def in pairs(Item.defs) do
    if def.price and def.type ~= "consumable" and not pricedId then pricedId = id end
    if not def.price and not noPriceId then noPriceId = id end
end

return {
    {
        name = "Vendor.sellValue is half the shelf price, floored",
        fn = function()
            assert(pricedId, "no priced item found in data")
            local item = Item.instantiate(pricedId)
            local expected = math.floor(item.price * 0.5)
            assert(Vendor.sellValue(item) == expected,
                "sellValue " .. Vendor.sellValue(item) .. " ~= " .. expected)
            assert(expected > 0, "a priced item should have a positive sell value")
        end,
    },
    {
        name = "Vendor.sellValue is 0 for an item that was never for sale",
        fn = function()
            assert(noPriceId, "no price-less item found in data")
            assert(Vendor.sellValue(Item.instantiate(noPriceId)) == 0,
                "an item with no price must not be sellable")
        end,
    },
    {
        name = "buying spends gold and drops the item in the stash",
        fn = function()
            local p = Player.new()
            p.gold = 1000
            p.stash = {}
            local price = Item.defs[pricedId].price
            assert(Player.spendGold(p, price), "should afford the buy")
            Player.addToStash(p, Item.instantiate(pricedId))
            assert(p.gold == 1000 - price, "gold not deducted by price")
            assert(#p.stash == 1, "bought item not added to stash")
            assert(p.stash[1].id == pricedId, "wrong item in stash")
        end,
    },
    {
        name = "selling adds gold and removes the item from the grid",
        fn = function()
            local p = Player.new()
            p.gold = 0
            local char = p.roster[1]
            local item = Item.instantiate(pricedId)
            char.inventory[1] = item
            local value = Vendor.sellValue(item)
            Character.removeItem(char, item)
            Player.addGold(p, value)
            assert(p.gold == value, "gold not increased by sell value")
            assert(char.inventory[1] == nil, "sold item still in the grid")
        end,
    },
    {
        name = "addToParty enforces MAX_PARTY",
        fn = function()
            local p = Player.new()
            p.party = {}
            for i = 1, Player.MAX_PARTY do
                assert(Player.addToParty(p, p.roster[i] or Character.instantiate("character_knight")),
                    "add " .. i .. " within the cap should succeed")
            end
            assert(not Player.addToParty(p, Character.instantiate("character_knight")),
                "adding past MAX_PARTY must fail")
            assert(#p.party == Player.MAX_PARTY, "party overfilled")
        end,
    },
    {
        name = "addToParty rejects a duplicate member",
        fn = function()
            local p = Player.new()
            p.party = {}
            local knight = p.roster[1]
            assert(Player.addToParty(p, knight), "first add should succeed")
            assert(not Player.addToParty(p, knight), "second add of the same member must fail")
            assert(#p.party == 1, "duplicate should not have been added")
        end,
    },
    {
        name = "removeFromParty removes a member, reports absence",
        fn = function()
            local p = Player.new()
            p.party = {}
            local knight = p.roster[1]
            Player.addToParty(p, knight)
            assert(Player.removeFromParty(p, knight), "removing a present member returns true")
            assert(#p.party == 0, "member not removed")
            assert(not Player.removeFromParty(p, knight), "removing an absent member returns false")
        end,
    },
    {
        name = "a chosen party survives a save/load round trip by identity",
        fn = function()
            local p = Player.new()
            p.party = {}
            Player.addToParty(p, p.roster[1])
            Player.addToParty(p, p.roster[3])

            local restored = Save.restore(Save.snapshot(p))
            assert(restored, "snapshot did not restore")
            assert(#restored.party == 2, "party size not preserved")
            assert(restored.party[1].id == p.roster[1].id, "first party member id changed")
            assert(restored.party[2].id == p.roster[3].id, "second party member id changed")
            -- Party members must be the SAME instances as the restored roster, not copies.
            assert(restored.party[1] == restored.roster[1], "party[1] not aliased to roster")
            assert(restored.party[2] == restored.roster[3], "party[2] not aliased to roster")
        end,
    },
    {
        name = "shop stock marks a rank-gated item locked at low standing, unlocked at its rank",
        fn = function()
            -- Find any vendor selling an item that needs standing above rank 1.
            local vId, locked
            for vid in pairs(Vendor.defs) do
                for _, e in ipairs(Vendor.stock(vid, 1)) do
                    if e.repRank > 1 then vId, locked = vid, e break end
                end
                if vId then break end
            end
            if not locked then return end -- no rank-gated wares in data; nothing to assert
            assert(locked.locked, "a rank-gated item should be locked at rank 1")
            for _, e in ipairs(Vendor.stock(vId, locked.repRank)) do
                if e.id == locked.id then
                    assert(not e.locked, "the same item should unlock at its own repRank")
                end
            end
        end,
    },
    {
        name = "Vendor.upgradeAbility hones an owned ability one level for gold",
        fn = function()
            -- An upgradable ability item (one with a magnitude to level) whose class matches a vendor.
            local abilityId, vendorId
            for id, def in pairs(Item.defs) do
                if def.type == "ability" and def.class and Item.isUpgradable(Item.instantiate(id)) then
                    for vid, vdef in pairs(Vendor.defs) do
                        if vdef.class == def.class then abilityId, vendorId = id, vid break end
                    end
                end
                if abilityId then break end
            end
            if not abilityId then return end -- no class-matched ability in data
            local p = Player.new()
            p.gold = 500
            local item = Item.instantiate(abilityId)
            local newItem = Vendor.upgradeAbility(p, vendorId, item)
            assert(newItem, "upgrade should succeed at rank 1")
            assert((newItem.level or 0) == (item.level or 0) + 1, "level should rise by one")
            assert(p.gold < 500, "gold should be spent on the upgrade")
        end,
    },
    {
        name = "regionCross moves grid<->rail<->pool only at the correct column edges",
        fn = function()
            -- Grid (3 cols): left edge crosses to the rail, right edge to the stash.
            assert(Party.regionCross("grid", 0, 3, -1) == "rail", "grid left edge -> rail")
            assert(Party.regionCross("grid", 2, 3, 1) == "pool", "grid right edge -> pool")
            -- Interior columns stay put.
            assert(Party.regionCross("grid", 1, 3, -1) == nil, "grid interior stays (left)")
            assert(Party.regionCross("grid", 1, 3, 1) == nil, "grid interior stays (right)")
            -- Pool leftmost edge crosses back to the grid; it is rightmost, so right clamps.
            assert(Party.regionCross("pool", 0, 4, -1) == "grid", "pool left edge -> grid")
            assert(Party.regionCross("pool", 3, 4, 1) == nil, "pool right edge clamps")
            -- Rail is leftmost: right enters the grid, left clamps.
            assert(Party.regionCross("rail", 0, 1, 1) == "grid", "rail right -> grid")
            assert(Party.regionCross("rail", 0, 1, -1) == nil, "rail left clamps")
        end,
    },
    {
        name = "equipDelta keeps only the flat stats the focus sheet shows",
        fn = function()
            -- iron_plate: bonus = { defense = 13, movement = -2 }, plus a resist bag.
            local delta = Party.equipDelta(Item.instantiate("armor_iron_plate"))
            assert(delta.defense == 13, "defense bonus surfaced")
            assert(delta.movement == -2, "negative movement bonus surfaced")
            -- Resistances aren't flat stat rows, so they never leak into the delta.
            assert(delta.physical == nil and delta.slash == nil, "resist keys excluded")
        end,
    },
    {
        name = "equipDelta is empty for an item with no bonus, or for nil",
        fn = function()
            assert(next(Party.equipDelta(Item.instantiate("weapon_iron_sword"))) == nil, "no bonus -> empty")
            assert(next(Party.equipDelta(nil)) == nil, "nil item -> empty")
        end,
    },
}
