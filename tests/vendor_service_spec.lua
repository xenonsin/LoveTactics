-- A HOUSE'S OWN VERB. Every door in the city did Buy and Sell and nothing else, which is why the town
-- stops changing once the last building opens: a new shop is only ever more rows. A vendor may now
-- declare a `service`, and the Undercroft declares the first one -- the Fence, which turns a piece into
-- another piece of the same worth for a cut.
--
-- Two halves, tested separately: models/vendor.lua decides WHAT is on offer (player-free, like the rest
-- of that module), and ui/panels/shop.lua runs the two-step trade. The panel half borrows
-- tests/shop_buy_spec.lua's stubbed-font trick, since Shop.new bakes fonts and love.graphics.newFont
-- throws with no window.

local Vendor = require("models.vendor")
local Errand = require("models.errand")
local Item = require("models.item")
local Shop = require("ui.panels.shop")

-- A ledger with every house's door open and nothing else run: the shelf gates on Quest.shelfRung, the
-- standing less the door-buying opener, so a customer with an empty ledger sees an entirely shut shelf
-- and there is nothing to fence.
local function doorsOpen()
    local done = {}
    for vendorId in pairs(Errand.houses()) do done[Errand.opener(vendorId)] = true end
    return done
end

local function stubFonts(fn)
    local gfx = love.graphics
    local real = gfx.newFont
    gfx.newFont = function()
        return {
            getHeight = function() return 18 end,
            getWidth = function(_, s) return #tostring(s or "") * 8 end,
            getWrap = function(_, text, _) return text, { text } end,
        }
    end
    local ok, err = pcall(fn)
    gfx.newFont = real
    if not ok then error(err, 0) end
end

-- The house with the service, found by asking rather than by naming it, so moving the Fence to another
-- shelf (or adding a second) does not rot this file.
local function fenceVendorId()
    for id, def in pairs(Vendor.defs) do
        if def.service and def.service.id == "fence" then return id end
    end
end

-- An unlocked, priced ware on the fence's own shelf: the thing a player would plausibly be holding.
local function anySwappable(vendorId)
    for _, entry in ipairs(Vendor.stock(vendorId, 0, {}, {}, {})) do
        if not entry.locked and entry.price then
            local item = Item.instantiate(entry.id)
            if #Vendor.swapOffers(vendorId, item, 0, {}, {}, {}) > 0 then return item, entry end
        end
    end
end

return {
    {
        name = "exactly one house declares a service, and it is the Undercroft's fence",
        fn = function()
            local found = {}
            for id, def in pairs(Vendor.defs) do
                if def.service then found[#found + 1] = id end
            end
            assert(#found == 1, "one service is authored so far, got " .. #found)
            assert(found[1] == "undercroft", "greed's house keeps the fence, got " .. found[1])
            local svc = Vendor.defs.undercroft.service
            assert(svc.label and svc.blurb,
                "a tab nobody can read is a tab nobody presses -- a service needs a label and a blurb")
        end,
    },
    {
        name = "the fence offers wares of about the worth of the piece handed in",
        fn = function()
            local vid = fenceVendorId()
            local item, entry = anySwappable(vid)
            assert(item, "no shipped ware on the fence's own opening shelf can be traded at all")
            local worth = entry.price
            for _, offer in ipairs(Vendor.swapOffers(vid, item, 0, {}, {}, {})) do
                assert(offer.price >= worth * (1 - Vendor.SWAP_BAND)
                    and offer.price <= worth * (1 + Vendor.SWAP_BAND),
                    string.format("%s (%dg) offered for %s (%dg) is outside the band",
                        offer.name, offer.price, item.name, worth))
                assert(offer.id ~= item.id, "trading a thing for the same thing is not a trade")
                assert(not offer.locked, "the fence may not dangle stock it cannot actually hand over")
            end
        end,
    },
    {
        name = "a house with no service offers no swaps, whatever it is handed",
        fn = function()
            local item = anySwappable(fenceVendorId())
            -- The gate is the SERVICE, not the shelf. Without it any vendor holding same-priced stock
            -- would quietly become a fence the moment a caller asked.
            assert(#Vendor.swapOffers("bastion", item, 99, {}, {}, {}) == 0,
                "only a house that declares the fence runs one")
        end,
    },
    {
        name = "a bound relic and an unpriced item are not tradeable",
        fn = function()
            local vid = fenceVendorId()
            local item = anySwappable(vid)
            local bound = Item.instantiate(item.id)
            bound.bound = true
            assert(#Vendor.swapOffers(vid, bound, 99, {}, {}, {}) == 0,
                "a bound relic is never for sale, and a swap is a sale in both directions")
            assert(Vendor.swapFee({ name = "junk" }) == nil, "a thing with no price has no fee")
        end,
    },
    {
        name = "the fee is dearer than a sell-back, or selling would be strictly worse",
        fn = function()
            local item = anySwappable(fenceVendorId())
            local fee, sell = Vendor.swapFee(item), Vendor.sellValue(item)
            -- A swap returns an ITEM of the grade given up, with no second trip and no waiting on a
            -- gate. If it cost less than the half-price sell-back, the Sell tab would be decorative at
            -- the one house that has both.
            assert(fee > sell, string.format("fee %d must exceed sell value %d", fee, sell))
            assert(Vendor.swapFee({ price = 1, level = 0 }) >= 1, "no swap is ever free")
        end,
    },

    -- -----------------------------------------------------------------------
    -- The panel's two-step trade
    -- -----------------------------------------------------------------------
    {
        -- EVERY HOUSE HAS THREE TABS NOW: Buy, Sell and Errands. The third joined the base set when a
        -- shelf stopped opening on the campaign's quest count and started opening on the small work the
        -- house asks for (models/errand.lua) -- "what does this house want" became as much a thing you
        -- come to a counter to read as "what does it sell". A SERVICE is still the exception it always
        -- was, and still sits last.
        name = "every house has Buy, Sell and Errands; only a service house grows a fourth tab",
        fn = function()
            stubFonts(function()
                local base = { completedQuests = doorsOpen(), recipes = {}, gold = 0, stash = {} }
                local plain = Shop.new({ vendor = "bastion", player = base })
                assert(#plain.modes == 3, "Buy, Sell and Errands, and nothing else")
                assert(plain.modes[3] == "errands", "Errands is the third of the three every house has")
                local fenced = Shop.new({ vendor = fenceVendorId(), player = base })
                assert(#fenced.modes == 4 and fenced.modes[4] == "fence",
                    "the service tab sits after the three every house has")
            end)
        end,
    },
    {
        name = "a trade takes the piece, pays the fee, and hands back the one that was chosen",
        fn = function()
            stubFonts(function()
                local vid = fenceVendorId()
                local item = anySwappable(vid)
                local fee = Vendor.swapFee(item)
                local player = { completedQuests = doorsOpen(), recipes = {}, gold = fee + 50, stash = { item } }
                local shop = Shop.new({ vendor = vid, player = player })

                shop:setMode("fence")
                local row = shop.rows[1]
                assert(row and row.item == item, "the stash's one piece is the one row on offer")
                shop:activateRow(row) -- step one: put it on the counter

                assert(shop.rows[1].back, "step two leads with a way back out")
                local offer = shop.rows[2]
                assert(offer and offer.swapTo, "step two lists what the fence will give")
                local wanted = offer.swapTo.id
                shop:activateRow(offer)

                assert(player.gold == 50, "the fee is paid, got " .. player.gold)
                assert(#player.stash == 1, "one in, one out -- the stash does not grow")
                assert(player.stash[1].id == wanted,
                    "the player gets the piece they picked, not a roll: " .. tostring(player.stash[1].id))
                assert(not shop.swapFrom, "the counter is clear once the trade is done")
            end)
        end,
    },
    {
        name = "a company short of the fee is told so, and nothing moves",
        fn = function()
            stubFonts(function()
                local vid = fenceVendorId()
                local item = anySwappable(vid)
                local player = { completedQuests = doorsOpen(), recipes = {}, gold = 0, stash = { item } }
                local shop = Shop.new({ vendor = vid, player = player })
                shop:setMode("fence")
                shop:activateRow(shop.rows[1])
                shop:activateRow(shop.rows[2])
                -- Checked BEFORE anything moves, so a short purse never leaves a half-done trade.
                assert(#player.stash == 1 and player.stash[1] == item, "the piece stays on the counter")
                assert(player.gold == 0, "and no coin was found down the back of it")
                assert(shop.message and not shop.messageOk, "the refusal names the price")
            end)
        end,
    },
    {
        name = "backing out of a trade puts the piece down",
        fn = function()
            stubFonts(function()
                local vid = fenceVendorId()
                local item = anySwappable(vid)
                local player = { completedQuests = doorsOpen(), recipes = {}, gold = 999, stash = { item } }
                local shop = Shop.new({ vendor = vid, player = player })
                shop:setMode("fence")
                shop:activateRow(shop.rows[1])
                assert(shop.swapFrom, "the piece is on the counter")
                shop:activateRow(shop.rows[1]) -- the Back row
                assert(not shop.swapFrom, "and back off it again")
                assert(#player.stash == 1, "with nothing traded")
            end)
        end,
    },
    {
        name = "leaving the fence tab puts the piece down too",
        fn = function()
            stubFonts(function()
                local vid = fenceVendorId()
                local item = anySwappable(vid)
                local player = { completedQuests = doorsOpen(), recipes = {}, gold = 999, stash = { item } }
                local shop = Shop.new({ vendor = vid, player = player })
                shop:setMode("fence")
                shop:activateRow(shop.rows[1])
                shop:setMode("buy")
                shop:setMode("fence")
                -- Otherwise the tab reopens mid-trade on a piece the player has forgotten choosing,
                -- with a Back row and no memory of why.
                assert(not shop.swapFrom, "a tab switch clears the counter")
                assert(shop.rows[1] and shop.rows[1].item == item, "and the fence opens on step one")
            end)
        end,
    },
    {
        name = "the trade finds its piece by identity, not by the index the row was built with",
        fn = function()
            stubFonts(function()
                local vid = fenceVendorId()
                local item = anySwappable(vid)
                local other = Item.instantiate(item.id)
                local player = { completedQuests = doorsOpen(), recipes = {}, gold = 9999, stash = { item } }
                local shop = Shop.new({ vendor = vid, player = player })
                shop:setMode("fence")
                shop:activateRow(shop.rows[1])
                -- Something reorders the stash between choosing and confirming -- a sale on the other
                -- tab, a stack merging. An index captured at row-build time now points at the wrong
                -- thing, and a swap that trusted it would fence a piece the player never offered.
                table.insert(player.stash, 1, other)
                shop:activateRow(shop.rows[2])
                assert(player.stash[1] == other, "the bystander is untouched")
                for _, it in ipairs(player.stash) do
                    assert(it ~= item, "the piece actually put on the counter is the one that left")
                end
            end)
        end,
    },
}
