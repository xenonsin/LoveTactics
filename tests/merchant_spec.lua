-- The road's shop (ui/panels/merchant.lua): the rules a wandering market has to keep when the panel is
-- the only thing standing between a run's purse and its stash.
--
-- Stocked exactly as states/game.lua stocks it -- Spoils.shelf ids at their blueprint prices -- so the
-- fixture names no item by hand and cannot rot when the item set is re-cut.
--
-- Merchant.new bakes fonts and love.graphics.newFont throws without a window, so the panel is built
-- against a stubbed font (the trick tests/shop_buy_spec.lua uses). Nothing here draws.

local Merchant = require("ui.panels.merchant")
local Spoils = require("models.spoils")
local Item = require("models.item")

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

-- A panel over a real rolled shelf, with `gold` in the purse. `bought` collects every entry the panel
-- reports as sold, standing in for the caller's spend-and-grant.
local function marketFor(gold)
    local stock = {}
    for _, id in ipairs(Spoils.shelf({ prestige = 3, count = 3 })) do
        stock[#stock + 1] = { id = id, price = Item.defs[id].price }
    end
    local purse, bought = gold, {}
    local panel = Merchant.new({
        stock = stock,
        gold = function() return purse end,
        onBuy = function(entry)
            if purse < entry.price then return false end
            purse = purse - entry.price
            bought[#bought + 1] = entry
            return true
        end,
    })
    return panel, bought, function() return purse end
end

return {
    {
        -- The tooltip is the whole of what this panel can say about a piece, and it reads off the
        -- display copy the panel builds per row. No copy, no reading -- and buying a blade sight unseen
        -- is the one thing a shop must never ask.
        name = "every row carries an instantiated item for its tooltip to read",
        fn = function()
            stubFonts(function()
                local panel = marketFor(9999)
                assert(#panel.stock == 3, "the fixture must roll a full shelf")
                for _, entry in ipairs(panel.stock) do
                    assert(entry.item, "a row with no item has nothing to show")
                    assert(entry.item.id == entry.id, "the display copy must be of the ware on sale")
                    assert(entry.item.name, "the copy must carry the name the row prints")
                end
            end)
        end,
    },
    {
        name = "a ware the purse cannot cover is inert: no spend, and the row stays for sale",
        fn = function()
            stubFonts(function()
                local panel, bought, purse = marketFor(0)
                panel:buy(1)
                assert(#bought == 0, "a market must not sell what the company cannot pay for")
                assert(not panel.stock[1].bought, "an unaffordable row stays on the shelf")
                assert(purse() == 0, "and the purse is untouched")
            end)
        end,
    },
    {
        name = "buying spends once and marks the row sold",
        fn = function()
            stubFonts(function()
                local panel, bought, purse = marketFor(9999)
                local price = panel.stock[1].price
                panel:buy(1)
                assert(#bought == 1, "the press sells the row")
                assert(panel.stock[1].bought, "a sold row says so")
                assert(purse() == 9999 - price, "the ware costs its shelf price, once")
                -- Pressing a sold row again must not sell it twice: the shelf holds one of each.
                panel:buy(1)
                assert(#bought == 1, "a sold row cannot be bought again")
            end)
        end,
    },
    {
        -- The three-input standard: the keyboard and the pad reach every row and its tooltip by moving
        -- the focus, so the focus has to wrap rather than stick at either end.
        name = "focus wraps in both directions",
        fn = function()
            stubFonts(function()
                local panel = marketFor(9999)
                assert(panel.focus == 1, "the shelf opens on its first row")
                panel:moveFocus(-1)
                assert(panel.focus == #panel.stock, "stepping up off the top lands on the last row")
                panel:moveFocus(1)
                assert(panel.focus == 1, "and stepping down off the bottom comes back to the first")
            end)
        end,
    },
    {
        -- Leaving is not clearing: the cell stays, so the player can come back and spend later. The
        -- panel's only job is to fire onClose exactly once, whichever way it is dismissed.
        name = "closing fires once",
        fn = function()
            stubFonts(function()
                local closed = 0
                local panel = Merchant.new({ stock = {}, onClose = function() closed = closed + 1 end })
                panel:keypressed("escape")
                panel:keypressed("escape")
                panel:gamepadpressed(nil, "b")
                assert(closed == 1, "the close callback must fire exactly once, got " .. closed)
            end)
        end,
    },
}
