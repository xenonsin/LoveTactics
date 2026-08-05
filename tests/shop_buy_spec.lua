-- The vendor's BUY press (ui/panels/shop.lua): it asks before it spends, and it leaves the list where
-- the player put it.
--
-- Both are the same complaint from opposite ends. A shelf row is one press from the cursor on every
-- device -- and on the pad and the keyboard, confirm is the same button that walks the list -- so the
-- press has to be reversible before it commits; and a shelf runs dozens of rows deep, so a purchase
-- that scrolled the list back would cost the player their place on every single buy.
--
-- Shop.new bakes fonts and love.graphics.newFont throws without a window, so the whole panel is built
-- against a stubbed font (the trick tests/combat_fx_spec.lua uses). Nothing here draws.

local Shop = require("ui.panels.shop")
local Vendor = require("models.vendor")

-- A font stand-in with the three metrics the shop and its confirmation ask for while laying out.
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

local function shopFor(vendorId, gold)
    return Shop.new({
        vendor = vendorId,
        player = { completedQuests = {}, recipes = {}, gold = gold or 0, stash = {} },
    })
end

-- The first priced, unlocked row on any shipped shelf, so the test names no vendor and no item by hand
-- and cannot rot when a house's stock is re-cut. Returns the panel, the row, and its index.
local function anyBuyableRow(gold, minRows)
    for _, def in ipairs(Vendor.list()) do
        local panel = shopFor(def.id, gold)
        if #panel.rows >= (minRows or 0) then
            for i, row in ipairs(panel.rows) do
                if not row.header and not row.locked and row.entry and row.entry.price > 0 then
                    return panel, row, i
                end
            end
        end
    end
end

-- The option card carrying `label` on the confirmation the panel just raised.
local function option(panel, label)
    for _, o in ipairs(panel.confirm and panel.confirm.options or {}) do
        if o.label == label then return o end
    end
end

return {
    {
        name = "buying asks first: the press raises a confirmation and spends nothing",
        fn = function()
            stubFonts(function()
                local panel, row = anyBuyableRow(9999)
                assert(panel, "no shipped vendor sells anything -- the fixture has rotted")
                local price, gold = row.entry.price, panel.player.gold

                panel:activateRow(row)
                assert(panel.confirm, "the buy press raises the confirmation")
                assert(panel.player.gold == gold, "and takes no gold until it is answered")
                assert(#panel.player.stash == 0, "and puts nothing in the stash")

                option(panel, "Buy").cb()
                assert(not panel.confirm, "answering closes the question")
                assert(panel.player.gold == gold - price,
                    "confirming pays the price: " .. gold .. "g - " .. price .. "g")
                assert(#panel.player.stash == 1, "and the item lands in the stash")
            end)
        end,
    },
    {
        name = "cancelling the confirmation costs nothing",
        fn = function()
            stubFonts(function()
                local panel, row = anyBuyableRow(9999)
                local gold = panel.player.gold
                panel:activateRow(row)
                option(panel, "Cancel").cb()
                assert(not panel.confirm, "the question is closed")
                assert(panel.player.gold == gold, "with the gold untouched")
                assert(#panel.player.stash == 0, "and nothing bought")
            end)
        end,
    },
    {
        name = "a purchase you cannot afford is refused on the press, with no question asked",
        fn = function()
            -- Being walked through a confirmation and only THEN told no is a worse answer than being
            -- told no on the press, so affordability is settled before the modal is built.
            stubFonts(function()
                local probe, probeRow = anyBuyableRow(9999)
                assert(probe, "the fixture has rotted")
                local panel = shopFor(probe.vendorId, probeRow.entry.price - 1)
                local row
                for _, r in ipairs(panel.rows) do
                    if r.entry and r.entry.id == probeRow.entry.id then row = r break end
                end
                assert(row, "the same row is on the same shelf")

                panel:activateRow(row)
                assert(not panel.confirm, "a purchase out of reach raises no confirmation")
                assert(panel.message == "Not enough gold.", "it says so instead, got: " .. tostring(panel.message))
            end)
        end,
    },
    {
        name = "a purchase leaves the list exactly where the player scrolled it",
        fn = function()
            -- A rebuild that kept only the selection dragged the scroll window forward until the
            -- selected row scraped in at its bottom edge -- which, forty rows down a shelf, reads as
            -- the list snapping back. Buying changes no row's index, so nothing may appear to move.
            stubFonts(function()
                local panel, row = anyBuyableRow(9999, 20)
                assert(panel, "no shipped shelf runs 20 rows -- the fixture has rotted")
                panel.menu.scroll = 8
                panel.menu.selected = 12
                local scroll, selected = panel.menu.scroll, panel.menu.selected

                panel:commitBuy(row.entry)
                assert(panel.menu.scroll == scroll,
                    "the scroll window holds: " .. scroll .. " -> " .. panel.menu.scroll)
                assert(panel.menu.selected == selected,
                    "and so does the cursor: " .. selected .. " -> " .. panel.menu.selected)
            end)
        end,
    },
}
