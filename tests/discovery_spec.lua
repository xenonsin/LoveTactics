-- Tests for DISCOVERY: the rule that a house sells nothing it has not been shown first.
--
-- Above a house's opening weapon nothing carries a price (tools/drop_tier.lua's recut). Weapons,
-- utilities and armor are found in the rift, and a counter deals one only once the company has carried
-- one out -- so the first of anything is earned and every one after it is bought. docs/shelf.md is the
-- prose; this is the copy that fails the build.
--
-- WHAT IS ACTUALLY BEING DEFENDED is two claims that pull against each other, which is why they are
-- pinned together: an unfound ware must be VISIBLE, because a shelf that hid what it could not deal
-- would be a record of what you have rather than a record of what there is -- and it must be
-- UNBUYABLE, at any standing, in any discipline, however rich the company is.

local Vendor = require("models.vendor")
local Player = require("models.player")
local Item = require("models.item")
local Save = require("models.save")
local Class = require("models.class")

local function vendorFor(class)
    for id, def in pairs(Vendor.defs) do
        if def.class == class then return id end
    end
end

-- A ware the recut moved: classed, unpriced, carrying a depth, on a class a house actually stocks.
-- Picked off the data rather than named, so a re-grade that moves every tier does not redden this file.
--
-- The vendor check is not belt-and-braces: `creature` is a root with kit of its own and no counter
-- anywhere, so a bare isRoot filter picks a demon's cast and asks which shop sells it.
local function anyFound()
    local best
    for id, def in pairs(Item.defs) do
        if def.dropTier and def.class and Class.isRoot(def.class) and not def.bound
            and vendorFor(def.class) and (not best or id < best) then
            best = id
        end
    end
    return best
end

local function rowFor(vendorId, itemId, found)
    for _, entry in ipairs(Vendor.stock(vendorId, 99, nil,
        Class.unlockedSet(Player.new()), Class.levelSet(Player.new()), found)) do
        if entry.id == itemId then return entry end
    end
end

return {
    {
        -- BOTH HALVES AT ONCE, because either alone is a different (and wrong) design: listed but
        -- buyable is the old catalogue, and hidden is a trophy case.
        name = "an unfound ware stands on the shelf, named, and cannot be bought at any standing",
        fn = function()
            local id = anyFound()
            assert(id, "no unpriced, classed ware in the data at all -- the recut did not run")
            local def = Item.defs[id]
            local vendorId = vendorFor(def.class)
            assert(vendorId, def.class .. " has no vendor to stock " .. id)

            local row = rowFor(vendorId, id, nil)
            assert(row, id .. " is not on " .. vendorId .. "'s shelf at all -- a shelf that hides what "
                .. "it cannot deal is a record of what you have, not of what there is")
            assert(row.locked, id .. " is buyable without ever having been found")
            assert(row.lockReason == "undiscovered",
                id .. " is shut for the wrong reason: " .. tostring(row.lockReason))
            -- The one thing a player can act on when the answer is "you have not found one".
            assert(row.dropTier, id .. " does not report the depth it falls at")
        end,
    },
    {
        name = "carrying one out opens its line, and the price is derived from the depth",
        fn = function()
            local id = anyFound()
            local def = Item.defs[id]
            local vendorId = vendorFor(def.class)

            local row = rowFor(vendorId, id, { [id] = true })
            assert(row, id .. " left the shelf once it was found")
            assert(not row.locked, id .. " is still shut after being carried out")
            assert(row.lockReason == nil, "a dealt row still names a reason: " .. tostring(row.lockReason))

            -- Derived, never authored: the depth is read as the slot the ware would have had.
            assert(row.price and row.price > 0, id .. " is stocked at no price at all")
            assert(row.price == Vendor.foundPrice(def),
                id .. " is priced at " .. tostring(row.price) .. ", not the "
                .. tostring(Vendor.foundPrice(def)) .. " its depth implies")
        end,
    },
    {
        -- A SECOND GATE WOULD MEAN FINDING A THING AND STILL BEING REFUSED IT, for a rung it never sat
        -- on. The rung stays on the blueprint because models/balance.lua reads it as the power level
        -- (docs/shelf.md), so this is the case that keeps the two uses of one field apart.
        name = "a found ware is never rung-locked, however high its rank",
        fn = function()
            local worst
            for id, def in pairs(Item.defs) do
                if def.dropTier and def.class and Class.isRoot(def.class) and not def.bound
                    and vendorFor(def.class) and (def.unlockQuests or 0) > 0
                    and (not worst or (def.unlockQuests or 0) > (Item.defs[worst].unlockQuests or 0)) then
                    worst = id
                end
            end
            if not worst then return end -- nothing found carries a rank; nothing to claim

            local def = Item.defs[worst]
            -- Standing nought: a company that has run no work at all, holding one of these.
            local row = rowFor(vendorFor(def.class), worst, { [worst] = true })
            assert(row, worst .. " is not on its house's shelf")
            assert(not row.locked, worst .. " (rank " .. tostring(def.unlockQuests) .. ") is refused to "
                .. "a company that has carried one out -- a find has no rung to climb")
        end,
    },
    {
        name = "the ledger is stamped by an expedition ending, and rides the save",
        fn = function()
            local player = Player.new()
            assert(not Player.hasFound(player, "weapon_iron_sword"),
                "a fresh company has discovered something")

            -- Everything the company is holding, marked -- which is what both exits do now that a wipe
            -- surfaces with the haul as surely as the stair does.
            local id = anyFound()
            Player.grantItem(player, id)
            local added = Player.recordFound(player)
            assert(added > 0, "recordFound marked nothing at all")
            assert(Player.hasFound(player, id), id .. " was carried out and not recorded")

            -- Idempotent: surfacing twice with the same thing is one discovery.
            assert(Player.recordFound(player) == 0, "a second surfacing re-counted what was already known")

            local back = Save.restore(Save.snapshot(player))
            assert(Player.hasFound(back, id), id .. " did not survive a save round-trip")
        end,
    },
    {
        -- The load-bearing default: every save written before this existed has no ledger, and must load
        -- as a company that has discovered nothing rather than crashing or discovering everything.
        name = "a player with no ledger reads as having found nothing, and never errors",
        fn = function()
            assert(Player.hasFound(nil, "weapon_iron_sword") == false, "a nil player should read false")
            assert(Player.hasFound({}, "weapon_iron_sword") == false, "a ledgerless player should read false")
            assert(Player.recordFound(nil) == 0, "recordFound errored on a nil player")
        end,
    },
    {
        -- A DUPLICATE HAULED OUT MUST BE WORTH SOMETHING. Reading `price` alone here would have made
        -- every weapon, utility and piece of armor above the opener worth nothing at a counter the
        -- moment the recut took their prices off.
        name = "a found ware sells back, at half what it would be stocked at",
        fn = function()
            local id = anyFound()
            local instance = Item.instantiate(id)
            local value = Vendor.sellValue(instance)
            assert(value > 0, id .. " sells for nothing: a duplicate is unusable and unsellable")
            assert(value == math.floor(Vendor.foundPrice(Item.defs[id]) * 0.5),
                id .. " sells at " .. value .. ", off the half-of-stocked rate every other ware takes")
        end,
    },
}
