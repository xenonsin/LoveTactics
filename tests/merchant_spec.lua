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
local Relic = require("models.relic")

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
    -- Day and depth, which is what the call site passes now: a cart is stocked against the deepest
    -- floor the company has stood on, not against a field the function never read (`prestige`).
    for _, id in ipairs(Spoils.shelf({ day = 3, floorLevel = 3, count = 3 })) do
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

-- The option card carrying `label` on the confirmation the panel just raised (the shape
-- tests/shop_buy_spec.lua uses on the city's shelf, because it is the same question).
local function option(panel, label)
    for _, o in ipairs(panel.confirm and panel.confirm.options or {}) do
        if o.label == label then return o end
    end
end

-- A one-row shelf carrying a RELIC, rolled the way states/game.lua rolls one, with `held` already in the
-- run. Returns nil when nothing rolls, so a re-cut relic pool skips the case rather than reddening it.
local function relicMarketFor(gold, held)
    local id = Relic.slate({ day = 3 }, 1)[1]
    if not id then return nil end
    local info = Relic.info(id)
    if not info then return nil end
    info.id = id
    local purse, bought = gold, {}
    local panel = Merchant.new({
        stock = { { id = id, relic = info, price = 40, held = held or 0 } },
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
                -- Settled on the press, not behind the question: being walked through a confirmation and
                -- only THEN told no is a worse answer than being told no on the press.
                assert(not panel.confirm, "a ware out of reach raises no question")
            end)
        end,
    },
    {
        -- The press ASKS. A row is one press from the cursor on every device, and on the pad and the
        -- keyboard confirm is the button that walks the list -- and there is no sell-back on the road.
        name = "buying asks first: the press raises a confirmation and spends nothing",
        fn = function()
            stubFonts(function()
                local panel, bought, purse = marketFor(9999)
                local price = panel.stock[1].price
                panel:buy(1)
                assert(panel.confirm, "the buy press raises the confirmation")
                assert(#bought == 0, "and sells nothing until it is answered")
                assert(purse() == 9999, "and takes no coin")

                option(panel, "Buy").cb()
                assert(not panel.confirm, "answering closes the question")
                assert(#bought == 1, "confirming sells the row")
                assert(panel.stock[1].bought, "a sold row says so")
                assert(purse() == 9999 - price, "the ware costs its shelf price, once")
                -- Pressing a sold row again must not sell it twice, nor raise a second question.
                panel:buy(1)
                assert(not panel.confirm, "a sold row raises nothing")
                assert(#bought == 1, "a sold row cannot be bought again")
            end)
        end,
    },
    {
        name = "cancelling the confirmation costs nothing",
        fn = function()
            stubFonts(function()
                local panel, bought, purse = marketFor(9999)
                panel:buy(1)
                option(panel, "Cancel").cb()
                assert(not panel.confirm, "the question is closed")
                assert(#bought == 0, "with nothing sold")
                assert(purse() == 9999, "and the purse untouched")
                assert(not panel.stock[1].bought, "and the row still on the shelf")
            end)
        end,
    },
    {
        -- The two things that make a modal a confirmation rather than a second press: the reading the
        -- player was looking at, and what the money does. Buying a blade sight unseen is the one thing a
        -- shop must never ask, and out here the shelf's own tooltip is covered while the question stands.
        name = "the confirmation carries the ware's reading, its price, and what it leaves the purse",
        fn = function()
            stubFonts(function()
                local panel = marketFor(9999)
                local entry = panel.stock[1]
                panel:buy(1)
                local pane = panel.confirm.pane
                assert(pane and pane.draw and pane.w and pane.h > 0,
                    "the question reserves a column for the ware's own tooltip")
                local prompt = panel.confirm.prompt
                assert(prompt:find(entry.item.name, 1, true), "the question names the ware: " .. prompt)
                assert(prompt:find(tostring(entry.price) .. "g", 1, true),
                    "and the price, in the coin the counter takes: " .. prompt)
                assert(prompt:find("Leaves you " .. (9999 - entry.price) .. " gold", 1, true),
                    "and what the purse is left holding: " .. prompt)
            end)
        end,
    },
    {
        -- A purse that exactly covers the price has no number left to print, and "Leaves you 0 gold" is
        -- a worse sentence than the one a player would say.
        name = "a purchase that empties the purse says so in words",
        fn = function()
            stubFonts(function()
                -- Built by hand rather than through marketFor: the shelf is ROLLED, so a purse sized off
                -- one panel's first row would not cover the next panel's.
                local stock = {}
                for _, id in ipairs(Spoils.shelf({ day = 3, floorLevel = 3, count = 1 })) do
                    stock[#stock + 1] = { id = id, price = Item.defs[id].price }
                end
                local purse = stock[1].price
                local panel = Merchant.new({ stock = stock, gold = function() return purse end })
                panel:buy(1)
                assert(panel.confirm.prompt:find("last of your gold", 1, true),
                    "an emptying purchase names the emptying: " .. panel.confirm.prompt)
            end)
        end,
    },
    {
        -- A relic is not an item: its reading is the relic card, and the fact that changes the purchase
        -- is the STACK, because a duplicate deepens what the company already carries.
        name = "a relic row asks with its own card, and names the stack a duplicate would make",
        fn = function()
            stubFonts(function()
                local panel, bought = relicMarketFor(9999, 2)
                if not panel then return end -- no relic pool to roll from: nothing to assert
                panel:buy(1)
                assert(panel.confirm, "a relic press asks like any other")
                local pane = panel.confirm.pane
                assert(pane and pane.draw and pane.h > 0, "the relic's card is the reading beside it")
                assert(panel.confirm.prompt:find("would make 3", 1, true),
                    "the question says what the stack becomes: " .. panel.confirm.prompt)
                option(panel, "Buy").cb()
                assert(#bought == 1, "and confirming buys the relic")
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
