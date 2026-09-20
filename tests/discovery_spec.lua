-- Tests for THE TWO ROADS TO A FOUND WARE, and for the handful that only ever have one.
--
-- Above a house's opening weapon nothing carries a price (tools/drop_tier.lua's recut): a weapon, a
-- utility or a piece of armor carries a `dropTier` instead. What that depth buys is THREE things, and
-- the whole of this file is that they are one number -- how deep the rift gives it up, what a counter
-- charges for one, and the class rung a counter deals it at. docs/shelf.md is the prose.
--
-- WHAT THIS FILE USED TO DEFEND, and it is worth knowing because the cases below are its inverse: a
-- found ware stood on the rack named, silhouetted and UNBUYABLE at any standing until the company had
-- carried one out. That gate came off -- 157 wares reached the player through the price band's tail
-- alone, which is the reachability obligation docs/shelf.md states and that arrangement could not
-- meet. The rift is the head start; the class ladder is the backstop.
--
-- SO WHAT IS DEFENDED NOW is two claims that pull against each other, which is why they are pinned
-- together: an ordinary found ware must be REACHABLE by climbing alone, however unlucky the company --
-- and a TROPHY must not be, at any rung, in any discipline, however rich they are. The second is the
-- only thing keeping "what this body is known for" from being a shopping trip.
--
-- The discovery LEDGER outlived the gate that read it. `player.found` is still stamped at the surface
-- and still rides the save; models/bestiary.lua redacts a body's drop list with it. The cases at the
-- foot of this file are unchanged and still its guard.

local Vendor = require("models.vendor")
local Player = require("models.player")
local Item = require("models.item")
local Save = require("models.save")
local Class = require("models.class")

-- THE HAND-WRITTEN BEAST TROPHIES, named rather than swept. docs/drops.md's rule is "what a body is
-- KNOWN for" -- a judgment made one animal at a time -- and a heuristic that gathered these would also
-- gather the lists tools/drop_assign.lua spread for coverage, which are ordinary stock and must stay
-- buyable. Named here, so adding one is a line somebody writes a sentence next to.
local TROPHIES = {
    "armor_bristlehide", "weapon_unclosing_spear",
    "armor_winterhide", "utility_knapped_claw", "utility_the_yearling_pelt",
    "utility_the_wake", "utility_treeline_horn", "utility_the_last_sounder",
    "ability_mothers_howl", "utility_the_wood_remembers", "weapon_the_second_bite",
    "armor_raveners_hide", "utility_in_and_out",
    "armor_runners_hide",
    -- The Meandering Stag's three (data/characters/character_meandering_stag.lua). The sandals are the
    -- odd one: they are not a new trophy but an existing SHELF item taken off the counter and given to
    -- an animal, which is the first time a piece has moved in that direction.
    "utility_wellspring_sandals", "utility_the_second_hound", "utility_swailing_brand",
}

local function vendorFor(class)
    for id, def in pairs(Vendor.defs) do
        if def.class == class then return id end
    end
end

-- An ORDINARY found ware: classed, unpriced, carrying a depth, on a class a house actually stocks, and
-- not one of the pieces a body is known for. Picked off the data rather than named, so a re-grade that
-- moves every tier does not redden this file.
--
-- The vendor check is not belt-and-braces: `creature` is a root with kit of its own and no counter
-- anywhere, so a bare isRoot filter picks a demon's cast and asks which shop sells it.
--
-- `unstocked` is excluded by asking Vendor.foundPrice rather than by reading the flag, so this helper
-- and the shelf agree on what "a counter could deal this" means by construction.
local function anyFound(want)
    local best
    for id, def in pairs(Item.defs) do
        if def.dropTier and def.class and Class.isRoot(def.class) and not def.bound
            and vendorFor(def.class) and Vendor.foundPrice(def) ~= nil
            and (not want or want(def)) and (not best or id < best) then
            best = id
        end
    end
    return best
end

local function rowFor(vendorId, itemId, rung)
    for _, entry in ipairs(Vendor.stock(vendorId, rung or 99, nil,
        Class.unlockedSet(Player.new()), Class.levelSet(Player.new()))) do
        if entry.id == itemId then return entry end
    end
end

return {
    {
        -- BOTH HALVES AT ONCE, because either alone is a different (and wrong) design: open at rung 0
        -- is the old catalogue, and shut at the top of the ladder is content nobody can reach.
        name = "a found ware is shut under its rung and dealt at it, and the rung is its depth",
        fn = function()
            -- A ware deep enough to have a rung to climb; a tier-1 piece is open from the first
            -- morning and could not tell a working gate from a missing one.
            local id = anyFound(function(def) return def.dropTier >= 3 end)
            assert(id, "no unpriced, classed ware below the opening tier -- the tier pass did not run")
            local def = Item.defs[id]
            local vendorId = vendorFor(def.class)
            assert(vendorId, def.class .. " has no vendor to stock " .. id)
            local need = def.dropTier - 1

            local shut = rowFor(vendorId, id, need - 1)
            assert(shut, id .. " is not on " .. vendorId .. "'s shelf at all -- a shelf that hides what "
                .. "it cannot yet deal is a record of what you have, not of what there is")
            assert(shut.locked, id .. " (depth " .. def.dropTier .. ") is buyable at class level "
                .. (need - 1) .. ", a rung under its own")
            assert(shut.lockReason == "rung",
                id .. " is shut for the wrong reason: " .. tostring(shut.lockReason))
            -- THE ROW REPORTS THE RUNG IT WAS MEASURED AGAINST, not the authored rank. Two fifths of
            -- the catalogue carries no `unlockQuests`, so a reader taking the rank would promise a
            -- gate at 0 over a tile that refuses the press -- which is what the shop's refusal
            -- sentence and the market's rotation band both read (ui/panels/shop.lua, models/market.lua).
            assert(shut.rung == need, id .. " reports rung " .. tostring(shut.rung) .. ", not the "
                .. need .. " its depth names")
            -- The OTHER road, still named on the row: climb to the rung, or go down to the floor.
            assert(shut.dropTier, id .. " does not report the depth it falls at")

            local open = rowFor(vendorId, id, need)
            assert(open and not open.locked,
                id .. " is still shut at class level " .. need .. ", the rung its depth names")
            assert(open.lockReason == nil,
                "a dealt row still names a reason: " .. tostring(open.lockReason))
        end,
    },
    {
        -- NOTHING WAS CARRIED OUT, and that is the case. The gate is the ladder and only the ladder;
        -- a company that has never seen one of these buys it the moment the class is grown for it.
        name = "the rung is the whole gate -- having found one is asked nowhere",
        fn = function()
            local id = anyFound()
            local def = Item.defs[id]
            local player = Player.new()
            assert(not Player.hasFound(player, id), id .. " is already in a fresh company's ledger")

            local row = rowFor(vendorFor(def.class), id, 99)
            assert(row and not row.locked,
                id .. " is refused to a company at the top of the ladder that never found one")

            -- Derived, never authored: the depth is read as the slot the ware would have had.
            assert(row.price and row.price > 0, id .. " is stocked at no price at all")
            assert(row.price == Vendor.foundPrice(def),
                id .. " is priced at " .. tostring(row.price) .. ", not the "
                .. tostring(Vendor.foundPrice(def)) .. " its depth implies")
        end,
    },
    {
        -- THE EXCEPTION, AND IT IS THE ONE THING KEEPING A CHASE FROM BEING AN ERRAND. Asserted at the
        -- TOP of the ladder with the discipline sets handed over, because "not yet" and "not ever" are
        -- the two answers this has to tell apart -- a trophy shut at rung 0 would pass a lazier check
        -- and open at rung 8.
        name = "a trophy is on no counter at any rung, and nobody will buy one back",
        fn = function()
            for _, id in ipairs(TROPHIES) do
                local def = Item.defs[id]
                assert(def, id .. " is named a trophy and is not in the data")
                assert(def.unstocked, id .. " lost its `unstocked` flag: a counter will deal one")
                assert(def.dropTier, id .. " has no depth, so nothing can drop it either")
                assert(Vendor.foundPrice(def) == nil, id .. " can still be quoted a price")
                assert(Vendor.sellValue(Item.instantiate(id)) == 0,
                    id .. " sells back: a piece that exists only where it fell has no market price in "
                    .. "either direction")

                local vendorId = def.class and vendorFor(def.class)
                if vendorId then
                    assert(not rowFor(vendorId, id, 99),
                        id .. " stands on " .. vendorId .. "'s rack at the top of the ladder")
                end
            end
        end,
    },
    {
        -- THE SET IS CLOSED, from the other end. Without this, flagging a piece by accident -- or a
        -- tool pass writing the field -- takes a ware off every counter in the game in silence, which
        -- is the failure the recut already shipped once in the other direction.
        name = "nothing outside the named trophies carries the flag",
        fn = function()
            local named = {}
            for _, id in ipairs(TROPHIES) do named[id] = true end
            for id, def in pairs(Item.defs) do
                assert(not def.unstocked or named[id],
                    id .. " carries `unstocked` and is not a named trophy -- it is off every counter "
                    .. "in the game, and docs/drops.md says who is allowed to be")
            end
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
