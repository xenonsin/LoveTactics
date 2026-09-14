-- Tests for models/salvage.lua: breaking a carried piece down into Forge stock (docs/drops.md).
--
-- The load-bearing claim is the INEQUALITY -- a break must never pay what a rung costs -- because the
-- whole faucet is safe only while salvaging is a way to make progress on something else rather than
-- the optimal first move on a good drop. Everything else here guards a refusal or the discovery mark.

local Class = require("models.class")
local Forge = require("models.forge")
local Identify = require("models.identify")
local Item = require("models.item")
local Material = require("models.material")
local Player = require("models.player")
local Salvage = require("models.salvage")
local Spoils = require("models.spoils")

local function bare()
    return { gold = 0, materials = {}, stash = {}, roster = {}, found = {} }
end

local function total(t)
    local n = 0
    for _, count in pairs(t or {}) do n = n + count end
    return n
end

-- The first item matching a predicate, by sorted id so the fixture is stable across runs.
local function findItem(pred)
    local ids = {}
    for id in pairs(Item.defs) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if pred(id, Item.defs[id]) then return id, Item.defs[id] end
    end
end

local function rootClassItem()
    return findItem(function(_, def)
        return def.class and Class.defs[def.class] and Class.isRoot(def.class)
            and not def.bound and Material.houseFor(def.class) ~= nil
    end)
end

local function earnedClassItem()
    return findItem(function(_, def)
        return def.class and Class.defs[def.class] and not Class.isRoot(def.class) and not def.bound
    end)
end

return {
    {
        -- The point of the feature: a break pays stock, and it pays it from the piece's OWN line.
        name = "breaking a piece pays its own house's stock and its own quality's craft stock",
        fn = function()
            local id, def = rootClassItem()
            assert(id, "the catalogue must hold a root-class item with a house stock")
            local yield = Salvage.yield({ id = id })
            assert(total(yield) > 0, id .. " broke down into nothing")

            local house = Material.houseFor(def.class)
            assert((yield[house] or 0) == Salvage.HOUSE,
                id .. " must pay " .. Salvage.HOUSE .. " of " .. tostring(house))

            local craft = Salvage.craftGradeFor(def)
            assert((yield[craft] or 0) == Salvage.CRAFT,
                id .. " must pay craft stock at its own grade (" .. tostring(craft) .. ")")
        end,
    },
    {
        -- The Forge bills an earned class's gear from every PARENT house, because "ninja" is not a
        -- house. A break that read the field naively would pay nothing at all and look like a bug in
        -- the arithmetic rather than in the taxonomy (docs/class-fold.md).
        name = "an earned class breaks down into its parent houses, not a house that does not exist",
        fn = function()
            local id, def = earnedClassItem()
            if not id then return end -- no crossing stock authored; nothing to claim
            local yield = Salvage.yield({ id = id })
            assert(Material.houseFor(def.class) == nil,
                "this case only means something while an earned class has no house stock of its own")
            local paidAHouse = false
            for _, parent in ipairs(Class.parents(def.class)) do
                if (yield[Material.houseFor(parent)] or 0) > 0 then paidAHouse = true end
            end
            assert(paidAHouse, id .. " paid no parent house stock at all")
        end,
    },
    {
        -- THE INEQUALITY. Breaking a thing may never fund the rung that thing would have cost, or the
        -- faucet becomes the bench and every good drop is worth more in pieces.
        name = "a break never pays what a forge rung costs",
        fn = function()
            local player = bare()
            local checked = 0
            local ids = {}
            for id in pairs(Item.defs) do ids[#ids + 1] = id end
            table.sort(ids)
            for _, id in ipairs(ids) do
                local def = Item.defs[id]
                if def.class and Class.defs[def.class] and not def.bound and Forge.canWork({ id = id,
                    level = 0, class = def.class, price = def.price, type = def.type }) then
                    local cost = Forge.upgradeCost(player, { id = id, level = 0, class = def.class,
                        price = def.price, type = def.type })
                    if cost and cost.materials then
                        local yield = Salvage.yield({ id = id })
                        assert(total(yield) < total(cost.materials),
                            id .. " breaks into " .. total(yield) ..
                            " stock against a first rung costing " .. total(cost.materials))
                        checked = checked + 1
                    end
                end
            end
            -- A green pass over an empty set is not a pass (the reachable-domain trap).
            assert(checked > 20, "only " .. checked .. " items were actually compared")
        end,
    },
    {
        -- The arbitrage this refuses: forge it up, break it down, bank the difference. The blueprint
        -- is the whole of what a break reads, so there is no difference to bank.
        name = "a forged piece breaks down into exactly what an unforged one does",
        fn = function()
            local id = rootClassItem()
            local plain = Salvage.yield({ id = id, level = 0 })
            local hammered = Salvage.yield({ id = id, level = 9 })
            for mat, count in pairs(plain) do
                assert(hammered[mat] == count, id .. " paid differently at +9 for " .. mat)
            end
            for mat in pairs(hammered) do
                assert(plain[mat], id .. " paid " .. mat .. " only when forged")
            end
        end,
    },
    {
        -- Three refusals and no fourth. Owning only one is NOT a refusal -- that is the decision the
        -- feature exists to offer (docs/drops.md).
        name = "a bound relic and an unread husk both refuse to break",
        fn = function()
            local player = bare()
            local boundId = findItem(function(_, def) return def.bound end)
            if boundId then
                assert(Salvage.refusal(player, { id = boundId }) == "bound",
                    boundId .. " is bound and must refuse")
            end

            local sealableId = findItem(function(id) return Identify.canSeal(id) end)
            assert(sealableId, "the catalogue must hold something sealable")
            local husk = Identify.sealed(sealableId, 5, 2)
            assert(Identify.isUnidentified(husk), "the fixture must actually be a husk")
            assert(Salvage.refusal(player, husk) == "unread", "an unread husk must refuse")
        end,
    },
    {
        name = "a first copy may be broken",
        fn = function()
            local player = bare()
            local id = rootClassItem()
            assert(Player.ownedCount(player, id) == 0, "the company holds none of these")
            assert(Salvage.canBreak(player, { id = id }),
                "holding only one must not be a refusal -- that is the decision")
        end,
    },
    {
        -- THE OBLIGATION of letting a first copy break. Player.recordFound stamps at the surface by
        -- walking the stash and the grids; a piece broken underground is in neither when that fires, so
        -- without this mark the counter line that copy opened is lost for good (models/vendor.lua).
        name = "breaking a piece stamps the discovery ledger before it goes",
        fn = function()
            local player = bare()
            local id = rootClassItem()
            assert(not Player.hasFound(player, id), "not found yet")
            local yield = Salvage.breakDown(player, { id = id })
            assert(yield, "the break should have succeeded")
            assert(Player.hasFound(player, id),
                id .. " was broken without ever being recorded as found")
        end,
    },
    {
        name = "breaking banks the yield onto the player, and a refusal banks nothing",
        fn = function()
            local player = bare()
            local id = rootClassItem()
            local yield = Salvage.breakDown(player, { id = id })
            for mat, count in pairs(yield) do
                assert(Player.materialCount(player, mat) == count,
                    "expected " .. count .. " of " .. mat)
            end

            local before = {}
            for mat, n in pairs(player.materials) do before[mat] = n end
            local got, why = Salvage.breakDown(player, { id = "item_that_does_not_exist" })
            assert(got == nil and why == "unknown", "an unknown id refuses")
            for mat, n in pairs(player.materials) do
                assert(before[mat] == n, "a refused break must charge and pay nothing")
            end
        end,
    },
    {
        -- Depth buys a BETTER grade, never a bigger pile -- which is what keeps the inequality above
        -- structural instead of tuned. And it is the only thing separating a floor-one find from a
        -- floor-eight one, since above a house's opener the found catalogue carries no price to grade
        -- on at all (docs/shelf.md).
        name = "a deeper unpriced find breaks into better ore, and never into more of it",
        fn = function()
            local shallow = findItem(function(_, def)
                return def.dropTier and not def.bound and not def.price
                    and Spoils.depthOf(def) <= 2
            end)
            local deep = findItem(function(_, def)
                return def.dropTier and not def.bound and not def.price
                    and Spoils.depthOf(def) >= 8
            end)
            assert(shallow and deep, "need a shallow and a deep unpriced find to compare")

            local grades = Material.craftGrades()
            local rank = {}
            for i, id in ipairs(grades) do rank[id] = i end

            local a = Salvage.craftGradeFor(Item.defs[shallow])
            local b = Salvage.craftGradeFor(Item.defs[deep])
            assert(rank[b] > rank[a],
                deep .. " (" .. tostring(b) .. ") must grade above " ..
                shallow .. " (" .. tostring(a) .. ")")

            -- ...and the quantity did not move, which is the half that keeps the bench safe.
            assert(Salvage.yield({ id = shallow })[a] == Salvage.CRAFT, "one unit, shallow")
            assert(Salvage.yield({ id = deep })[b] == Salvage.CRAFT, "one unit, deep")
        end,
    },
    {
        -- A priced piece must grade the same way whichever question you ask, or the two halves of the
        -- catalogue disagree about the same object.
        name = "a priced piece still grades off its price",
        fn = function()
            local id = findItem(function(_, def)
                return def.price and def.price > 0 and not def.bound
            end)
            assert(id, "the catalogue must hold something priced")
            assert(Salvage.craftGradeFor(Item.defs[id]) == Material.gradeFor(Item.defs[id]),
                id .. " must grade off price, as the bench does")
        end,
    },
    {
        -- P5's one piece of engineering: a rift-only ware sits on no counter, ever. Without `unstocked`
        -- the recut's own rule (a found ware is stocked once one has been carried out) makes the rarest
        -- thing in the game something you buy a second of, which is what "found only" was supposed to
        -- mean in the first place (docs/drops.md).
        name = "an unstocked piece has no price in either direction, and can still be broken",
        fn = function()
            local Vendor = require("models.vendor")
            local id = findItem(function(_, def)
                return def.dropTier and not def.bound and not def.price and def.class
                    and Class.defs[def.class]
            end)
            assert(id, "need an unpriced found ware to stand in for one")
            local def = Item.defs[id]

            -- As authored it is ordinary found stock: a counter will deal and buy one.
            assert(Vendor.foundPrice(def), id .. " should quote a found price as authored")
            assert(Vendor.sellValue(def) > 0, "...and sell for something")

            -- Flagged, it leaves the money economy in both directions.
            local had = def.unstocked
            def.unstocked = true
            assert(Vendor.foundPrice(def) == nil, "an unstocked ware is never stocked")
            assert(Vendor.sellValue(def) == 0, "...and never bought")

            -- But it is still the company's: it breaks down like anything else, which is the whole
            -- difference between `unstocked` and `bound`.
            assert(Salvage.canBreak({ gold = 0, stash = {}, roster = {} }, { id = id }),
                "an unstocked piece is yours -- it must still break")
            local yield = Salvage.yield({ id = id })
            assert(next(yield) ~= nil, "and pay stock for it")
            def.unstocked = had
        end,
    },
}
