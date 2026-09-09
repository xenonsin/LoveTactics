-- The vendor shelf's LADDER: ui/panels/shop.lua bands a house's Buy list per discipline, and every
-- band is one row of a column with the selected band's stock standing beside it as tiles. What this
-- pins is the shape of that column -- that a band is a row and not a heading over rows, that a path
-- the company has not opened is NAMED and carries the gate that opens it, and that its stock stands on
-- the rack all the same, greyed to the last plate.
--
-- The old shelf folded instead: every band opened and shut, a locked one started shut, and a player
-- could open one and read every greyed row behind it. The rack replaced the fold -- nine band rows do
-- not need folding, and one rack shows one band by construction. For a while a locked band could not be
-- opened at all, on the argument that a screen of unbuyable tiles teaches nothing its count has not
-- said; it teaches the one thing a count cannot, which is WHAT is behind the gate, so the tiles came
-- back and the refusal moved onto each of them.
--
-- Most of it exercises the row-building half only. Shop.new bakes fonts, so those panels are built
-- straight through the metatable with the fields buildBuyRows actually reads -- the same trick
-- loadout_filter_spec uses; the rack case needs a whole panel and stubs the font instead.

local Shop = require("ui.panels.shop")
local Vendor = require("models.vendor")
local Class = require("models.class")
local Item = require("models.item")

-- A shelf built for `vendorId` as seen by a player who has finished nothing: no class levels, so every
-- discipline this house touches is still locked.
local function shelf(vendorId)
    local panel = setmetatable({
        player = { completedQuests = {}, recipes = {}, gold = 0, stash = {} },
        vendorId = vendorId,
        def = Vendor.get(vendorId) or {},
        shelfRung = 0,
        rows = {},
    }, Shop)
    panel:buildBuyRows()
    return panel
end

-- The first vendor whose shelf carries a locked discipline band, so the test names no content by hand
-- and cannot rot when a house's stock is re-cut.
local function vendorWithLockedPath()
    for _, def in ipairs(Vendor.list()) do
        for _, row in ipairs(shelf(def.id).rows) do
            if row.discipline and row.shut then return def.id, row.discipline end
        end
    end
end

local function bandFor(panel, classId)
    for _, row in ipairs(panel.rows) do
        if row.discipline == classId then return row end
    end
end

-- The bands, without the inert rule row that divides the open ones from the shut ones.
local function bands(panel)
    local out = {}
    for _, row in ipairs(panel.rows) do
        if row.band then out[#out + 1] = row end
    end
    return out
end

-- A font stand-in with the three metrics the shop asks for while laying out (tests/shop_buy_spec.lua
-- uses the same one).
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

return {
    {
        name = "the Buy list is bands and nothing else: no item stands on it as a row",
        fn = function()
            local vendorId = vendorWithLockedPath()
            assert(vendorId, "no shipped vendor bands a locked discipline -- the fixture has rotted")
            local panel = shelf(vendorId)
            assert(#panel.rows > 1, "a house shelf runs several bands, got " .. #panel.rows)
            for _, row in ipairs(panel.rows) do
                assert(row.band or row.rule, "every row on the shelf is a band or the rule between "
                    .. "them: " .. tostring(row.label))
                assert(row.header, "and every one of them is a header row")
                assert(row.item == nil and row.entry == nil,
                    "no band is an item row: " .. tostring(row.label))
            end
        end,
    },
    {
        name = "what can be shopped stands above the rule, and what cannot below it",
        fn = function()
            -- The rail's top half is bands with stock behind them. A locked path dealt in among the open
            -- ones by gate depth put four refusals between a player and the rack they came for.
            local vendorId = vendorWithLockedPath()
            local panel = shelf(vendorId)

            local seenShut, ruleAt, i = false, nil, 0
            for _, row in ipairs(panel.rows) do
                i = i + 1
                if row.rule then
                    assert(not ruleAt, "one rule, not one per locked band")
                    assert(not seenShut, "the rule stands BEFORE the first shut band")
                    ruleAt = i
                elseif row.shut then
                    assert(ruleAt, "no shut band stands above the rule")
                    seenShut = true
                else
                    assert(not seenShut, tostring(row.label) .. ": an open band below a shut one")
                end
            end
            assert(ruleAt, "a shelf with a locked path draws the rule")

            -- The rule is inert: it is a divider, and the cursor must never come to rest on one.
            local rule = panel.rows[ruleAt]
            assert(rule.band == nil and rule.label == "", "the rule carries no name and no band")
        end,
    },
    {
        name = "a locked band is named, and says what opens it in the class column's words",
        fn = function()
            -- The gate reads as levels ("Knight 5  +  Rogue 5") because that is how the Armory's class
            -- column words the same fact (ui/class_editor.lua's lockParts). A player crossing the
            -- square between the two screens must not have to translate one into the other.
            local vendorId, classId = vendorWithLockedPath()
            local panel = shelf(vendorId)
            local band = bandFor(panel, classId)
            assert(band, classId .. " lost its band on the second build")

            local name = Class.displayName(classId) or classId
            assert(band.label == name, "a locked path keeps its name: " .. tostring(band.label))
            assert(type(band.meta) == "string" and band.meta:find("%d"),
                classId .. ": a locked band names the rung that opens it, got " .. tostring(band.meta))
            local house = Item.classDisplayName(panel.def.class)
            local requires = (Class.defs[classId] or {}).requires or {}
            if house and requires[panel.def.class] then
                assert(band.meta:find(house .. " " .. requires[panel.def.class], 1, true),
                    classId .. ": the gate names this house and its level, got " .. band.meta)
            end
        end,
    },
    {
        -- A locked band used to hand the rack NOTHING: the count of what waited behind it was the whole
        -- of what a player got, on the argument that a wall of greyed tiles teaches nothing a number has
        -- not said. It teaches the one thing a number cannot -- WHAT -- so the stock is dealt now and
        -- every piece of it is shut. What this pins is both halves: the rack is whole, and not one tile
        -- on it can be bought.
        name = "a locked band hands the rack its stock, and not one piece of it is open",
        fn = function()
            local vendorId, classId = vendorWithLockedPath()
            local panel = shelf(vendorId)
            local band = bandFor(panel, classId)
            assert(#band.stock > 0, classId .. ": a locked band counts what waits behind it")
            assert(#band.rows == #band.stock, classId .. ": and hands every piece of it to the rack, got "
                .. #band.rows .. " of " .. #band.stock)
            assert(band.total == #band.stock, classId .. ": and the count is that number")
            assert(band.open == 0, classId .. ": none of which is open to a company standing outside")
            for _, row in ipairs(band.rows) do
                assert(row.locked, classId .. ": " .. tostring(row.label) .. " is buyable on a shut path")
            end
        end,
    },
    {
        name = "an open band hands the rack every piece it bands",
        fn = function()
            -- The house's own rack is never gated -- everyone may shop the base class -- so it is the
            -- band that is open on the first morning, and its stock is what the rack shows.
            local vendorId = vendorWithLockedPath()
            local base = shelf(vendorId).rows[1]
            assert(base.key == "__base", "the base rack leads the shelf and is not a path")
            assert(base.discipline == nil, "and bands no discipline")
            assert(not base.shut, "it is never shut")
            assert(#base.rows == #base.stock and #base.rows > 0,
                "every piece on it reaches the rack: " .. #base.rows .. " of " .. #base.stock)
        end,
    },
    {
        -- The pane beside the column is the only room a band has to say what it IS, and for a locked
        -- one that sentence is the entire pitch for the gate. class_spec and discipline_spec pin that
        -- the sentences exist; this pins that the shelf actually picks them up, for every band.
        name = "every band on every shelf carries the blurb its pane prints",
        fn = function()
            local checked = 0
            for _, def in ipairs(Vendor.list()) do
                for _, row in ipairs(bands(shelf(def.id))) do
                    -- The general store has no class, so its base rack is not a shelf with a point of
                    -- view and has nothing to say about itself; every other band does.
                    if row.discipline or def.class then
                        assert(type(row.blurb) == "string" and row.blurb ~= "",
                            def.id .. ": band '" .. tostring(row.label) .. "' has no blurb")
                        checked = checked + 1
                    end
                end
            end
            assert(checked > 0, "no vendor banded its shelf -- the fixture has rotted")
        end,
    },
    {
        name = "the rack is the selected band's stock, and every tile names its own row",
        fn = function()
            -- ONE ITEM LANGUAGE: a house's stock is drawn in the widget the stash is drawn in
            -- (ui/pool_grid.lua), so a piece looks the same here as it does in the Armory and the
            -- Market. What this pins is the seam -- cell index to shelf row -- because that mapping is
            -- what turns a press on a tile into a purchase.
            stubFonts(function()
                local vendorId = vendorWithLockedPath()
                local panel = Shop.new({
                    vendor = vendorId,
                    player = { completedQuests = {}, recipes = {}, gold = 0, stash = {} },
                })
                assert(panel:usesShelf(), "a house's Buy tab is the band shelf")
                assert(panel.menu, "which keeps a list of bands")
                assert(#panel.sections == 1, "and exactly one rack beside it, got " .. #panel.sections)

                local rack, band = panel.sections[1], panel.rows[panel.menu.selected]
                assert(rack.key == band.key, "the rack is the band the cursor is on")
                assert(rack.pool:count() == #band.rows,
                    "every row is a tile: " .. rack.pool:count() .. " tiles, " .. #band.rows .. " rows")
                for i = 1, rack.pool:count() do
                    assert(rack.pool:cellAt(i).entry.row == band.rows[i], "tile " .. i .. " names its row")
                    assert(rack.pool:itemAt(i) == band.rows[i].item,
                        "and shows the copy the shelf instantiated, at the level it sells at")
                end
            end)
        end,
    },
    {
        name = "walking onto a locked band brings its own rack, standing under the gate",
        fn = function()
            -- The rack follows the cursor with no press (Shop:syncBand), and a shut band is no
            -- exception: what it must never do is leave the LAST band's rack standing, which would
            -- price a locked path with the pieces of an open one.
            --
            -- The pitch that argues for the gate is measured first and the rack laid out under what it
            -- takes (Shop:bandPitch) -- the fixed block placed off a measurement, the grower capped by
            -- what is left -- so the tiles can never be drawn over by the sentence above them.
            stubFonts(function()
                local vendorId, classId = vendorWithLockedPath()
                local panel = Shop.new({
                    vendor = vendorId,
                    player = { completedQuests = {}, recipes = {}, gold = 0, stash = {} },
                })
                assert(#panel.sections == 1, "the shelf opens on a band with stock")

                local index
                for i, row in ipairs(panel.rows) do
                    if row.discipline == classId then index = i end
                end
                panel.menu.selected = index
                panel:syncBand()
                assert(#panel.sections == 1, "a locked band builds its rack like any other")
                local rack, band = panel.sections[1], panel.rows[index]
                assert(rack.key == band.key, "and it is THIS band's rack, not the one it walked off")
                assert(rack.pool:count() == #band.rows and #band.rows > 0,
                    "every piece it bands is a tile: " .. rack.pool:count() .. " of " .. #band.rows)
                assert(rack.pitch and rack.pitch.h > 0, "the gate takes room above the tiles")
                assert(rack.pool.y == panel.bandTop + rack.pitch.h,
                    "and the rack begins under exactly what it took")

                -- Pressing it crosses into the rack AND says what opens it, once, on the crossing.
                panel:activateBand(band)
                assert(panel.zone == "grid", "the press crosses into the rack")
                assert(type(panel.message) == "string" and panel.message:find("Locked"),
                    "and answers with the gate: " .. tostring(panel.message))
            end)
        end,
    },
}
