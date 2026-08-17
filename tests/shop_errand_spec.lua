-- The Errands tab is a READOUT, and pressing a readout must do nothing.
--
-- ui/panels/shop.lua runs three lists (and a service) through one Menu, and every row it hands that
-- widget carries an `action`. The panel's own `locked` flag is not one the widget reads -- ui/menu.lua
-- steps over a bare header and nothing else -- so the cursor lands on an errand row and the click is
-- delivered. Shop:activateRow used to branch on Buy and the fence and let EVERYTHING ELSE fall through
-- to the sell path, which asked a row with no item what it was worth and crashed in Vendor.sellValue.
--
-- What is pinned here is the shape of that mistake, not the one row it happened on: activating a row on
-- a list that sells nothing must leave the purse and the stash exactly as they were.
--
-- Shop.new bakes fonts, so the panel is built straight through the metatable with the fields
-- activateRow actually reads -- the same trick shop_fold_spec uses.

local Shop = require("ui.panels.shop")
local Errand = require("models.errand")
local Vendor = require("models.vendor")

local VENDOR = "bastion"

-- The Errands tab as `player` sees it at this house.
local function errandTab(player)
    local panel = setmetatable({
        player = player,
        vendorId = VENDOR,
        def = Vendor.get(VENDOR) or {},
        mode = "errands",
        questsDone = 0,
        rows = {},
    }, Shop)
    panel:buildErrandRows()
    return panel
end

-- A company with this house's first errand on the books, and something to lose by pressing it.
local function company()
    local id = Errand.forVendor(VENDOR)[1]
    assert(id, VENDOR .. " asks for nothing at all -- the fixture has rotted")
    return {
        completedQuests = {},
        errands = { [id] = Errand.FLOORS_PER_RUNG },
        gold = 500,
        stash = { { id = "item_potion", name = "Potion", price = 40, quantity = 3 } },
    }, id
end

return {
    {
        name = "pressing an errand row spends nothing and sells nothing",
        fn = function()
            local player = company()
            local panel = errandTab(player)
            assert(#panel.rows > 0, "a company with an open errand should see it listed")
            assert(panel.rows[1].errand, "the first row is the errand, not the empty-list note")
            assert(not panel.rows[1].item, "an errand row carries no item -- that is the whole trap")

            for _, row in ipairs(panel.rows) do panel:activateRow(row) end

            assert(player.gold == 500, "the purse moved: " .. tostring(player.gold))
            assert(#player.stash == 1 and player.stash[1].quantity == 3,
                "the stash was sold out from under a list that sells nothing")
        end,
    },
    {
        name = "and it says why, so the press is answered rather than swallowed",
        fn = function()
            local player = company()
            local panel = errandTab(player)
            panel:activateRow(panel.rows[1])
            assert(type(panel.message) == "string" and panel.message ~= "",
                "an errand row that answers nothing reads as a dead panel")
            assert(panel.messageOk == false, "it is a refusal, not a receipt")
        end,
    },
    {
        name = "the empty-list note is inert too -- there is not even an errand behind it",
        fn = function()
            -- A house that has asked for nothing yet still fills the tab, with a sentence explaining
            -- which of the three silences this is. Those rows have neither item nor errand.
            local panel = errandTab({ completedQuests = {}, errands = {}, gold = 500, stash = {} })
            assert(#panel.rows > 0 and panel.rows[1].note, "the empty tab should still explain itself")
            for _, row in ipairs(panel.rows) do panel:activateRow(row) end
            assert(panel.message == nil, "a note is not a refusal -- there is nothing there to refuse")
        end,
    },
    {
        name = "and the till itself refuses a row with nothing on it",
        fn = function()
            -- Belt and braces, one layer down: the panel is not the only caller of sellValue, and a
            -- price is what makes a thing sellable -- no thing at all is the same answer.
            assert(Vendor.sellValue(nil) == 0, "nothing is worth nothing, not a crash")
            assert(Vendor.sellValue({ name = "Heirloom" }) == 0, "a priced-at-nothing item is unsellable")
        end,
    },
}
