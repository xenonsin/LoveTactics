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
local Errand = require("models.errand")
local Vendor = require("models.vendor")

-- A ledger with every house's door open and nothing else run. The shelf gates on Quest.shelfRung --
-- the standing less the opener, which buys the door rather than a band of stock -- so a company with an
-- empty ledger is standing outside, and a panel built for it has no unlocked row to press.
local function doorsOpen()
    local done = {}
    for vendorId in pairs(Errand.houses()) do done[Errand.opener(vendorId)] = true end
    return done
end

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
        player = { completedQuests = doorsOpen(), recipes = {}, gold = gold or 0, stash = {} },
    })
end

-- The one shop that sells everything (data/vendors/market.lua). It is the only vendor with a door in
-- the city, and the only one whose shelf is drawn as a grid of tiles.
local function marketId()
    for _, def in ipairs(Vendor.list()) do
        if (Vendor.get(def.id) or {}).sellsAll then return def.id end
    end
end

-- The first priced, unlocked row on any shipped shelf, so the test names no vendor and no item by hand
-- and cannot rot when a house's stock is re-cut. Returns the panel, the row, and its index.
--
-- `listOnly` skips the market: what it hands back is a panel with a Menu behind it, and the market has
-- none -- its counter is a grid (Shop:usesGrid), which is a different set of assertions.
local function anyBuyableRow(gold, minRows, listOnly)
    for _, def in ipairs(Vendor.list()) do
        local panel = (not (listOnly and (Vendor.get(def.id) or {}).sellsAll)) and shopFor(def.id, gold)
        if panel and #panel.rows >= (minRows or 0) then
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
                local panel, row = anyBuyableRow(9999, 20, true)
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
    {
        name = "the market's counter is a grid of tiles, and every tile names its own row",
        fn = function()
            -- ONE ITEM LANGUAGE: the counter is drawn in the widget the stash is drawn in
            -- (ui/pool_grid.lua), so a piece looks the same in the shop as it does in the Armory and
            -- the reading is the same hover tooltip. What this pins is the seam -- cell index to shelf
            -- row -- because that mapping is what turns a press on a tile into a purchase.
            stubFonts(function()
                local panel = shopFor(marketId(), 9999)
                assert(panel:usesGrid(), "the market draws its counter as a grid")
                assert(panel.menu == nil, "and builds no list menu behind it")
                assert(#panel.sections > 0, "with a rack for each band of stock")

                local rack
                for _, s in ipairs(panel.sections) do
                    if s.pool:count() > 0 then rack = s break end
                end
                assert(rack, "the counter has something on it")
                assert(rack.pool:count() == #rack.rows,
                    "every row is a tile: " .. rack.pool:count() .. " tiles, " .. #rack.rows .. " rows")
                for i = 1, rack.pool:count() do
                    assert(rack.pool:cellAt(i).entry.row == rack.rows[i], "tile " .. i .. " names its row")
                    assert(rack.pool:itemAt(i) == rack.rows[i].item,
                        "and shows the copy the shelf instantiated, at the level it sells at")
                end
            end)
        end,
    },
    {
        name = "a purchase leaves the grid's cursor and scroll exactly where the player put them",
        fn = function()
            -- The same complaint the list case above makes, in the shelf the player can actually walk
            -- into: buying changes no tile's index, so nothing may appear to move.
            stubFonts(function()
                local panel = shopFor(marketId(), 9999)
                local rack
                for _, s in ipairs(panel.sections) do
                    if s.pool:count() > 1 then rack = s break end
                end
                assert(rack, "no market rack carries two wares -- the fixture has rotted")

                rack.pool.cursor = 2
                local cursor, offset = rack.pool.cursor, rack.pool.offset
                panel:commitBuy(rack.rows[1].entry)

                local after
                for _, s in ipairs(panel.sections) do if s.key == rack.key then after = s end end
                assert(after, "the rack survives the rebuild")
                assert(after.pool.cursor == cursor,
                    "the cursor holds: " .. cursor .. " -> " .. after.pool.cursor)
                assert(after.pool.offset == offset,
                    "and so does the scroll: " .. offset .. " -> " .. after.pool.offset)
            end)
        end,
    },
    {
        name = "the confirmation carries the item's reading, and what the company already holds",
        fn = function()
            -- A name and a price is the least of what an item is, and the tooltip the player was
            -- reading when they pressed Buy is the thing the question covered up. It comes with the
            -- question now (as a measured pane the shop paints), and under the price sits the other
            -- half of "is this worth 30 gold": how many are already in the company, and where.
            stubFonts(function()
                local Item = require("models.item")
                local panel, row = anyBuyableRow(9999)
                assert(panel, "no shipped vendor sells anything -- the fixture has rotted")

                panel:activateRow(row)
                local pane = panel.confirm.pane
                assert(pane and pane.w > 0 and pane.h > 0, "the question reserves a column for the reading")
                assert(pane.draw, "and hands the panel back a way to paint it")
                assert(panel.confirm.prompt:find("You have none"),
                    "a first copy says so plainly: " .. panel.confirm.prompt)
                option(panel, "Cancel").cb()

                -- One loose in the pile and one on a body: the same total, two different facts.
                panel.player.stash = { Item.instantiate(row.entry.id) }
                panel.player.roster = { { id = "probe", inventory = { Item.instantiate(row.entry.id) } } }
                panel:activateRow(row)
                local prompt = panel.confirm.prompt
                assert(prompt:find("2 already"), "the count is the total: " .. prompt)
                assert(prompt:find("1 in the stash") and prompt:find("1 carried"),
                    "and it names the split: " .. prompt)
            end)
        end,
    },
}
