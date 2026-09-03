-- THE MARKET COUNTER: twenty-five rows, not four hundred and eighty-five.
--
-- What this pins, and why each half needs pinning:
--
--   THE SET      the standing rack is a DECLARED list here, both directions -- every id below is out,
--                and nothing that is not below is. A derived answer ("everything at rung 0") is what
--                put the whole catalogue on the counter in the first place; a set that can only grow
--                by someone editing this file is the ceiling that stops it happening again.
--   THE GATE     a blade is out when its class's companion has joined, and a draught always. The
--                second half is not a nicety: seven of the nine consumables are the Crucible's, so a
--                gate that did not carve them out would price a healing potion behind recruiting Ren.
--   THE ROTATION three rows, the same all day, different tomorrow, and every one of them buyable.
--   THE CALLER   the shop actually asks. models/market.lua existed, was complete, said exactly what
--                the counter should hold -- and had no caller, so the panel listed the catalogue
--                instead. Prose is not an implementation, and a model with no caller is prose.
--
-- Pure model plus one source scan; no window.

local Class = require("models.class")
local Errand = require("models.errand")
local Item = require("models.item")
local Market = require("models.market")
local Player = require("models.player")
local Vendor = require("models.vendor")

-- THE STANDING RACK, DECLARED. Nine draughts, and one plain weapon per class -- the nine named for the
-- ore plus the four that are not (a mage's Staff and Wand, a priest's Censer, an alchemist's Lancet),
-- all thirteen at 80 gold on the opening rung, which is what makes them the same rack.
local DRAUGHTS = {
    "consumable_ball_bearings", "consumable_clearwater_vial", "consumable_healing_potion",
    "consumable_mana_potion", "consumable_net", "consumable_panacea",
    "consumable_stamina_potion", "consumable_throwing_stone", "consumable_witchlight_flare",
}
local BLADES = {
    "weapon_apothecarys_lancet", "weapon_censer", "weapon_iron_axe", "weapon_iron_bow",
    "weapon_iron_dagger", "weapon_iron_greatsword", "weapon_iron_hammer", "weapon_iron_longbow",
    "weapon_iron_mace", "weapon_iron_spear", "weapon_iron_sword", "weapon_staff", "weapon_wand",
}

local function set(list)
    local out = {}
    for _, id in ipairs(list) do out[id] = true end
    return out
end

-- Every house that posts a companion, so a case can recruit one or all of them.
local function houses()
    local out = {}
    for id, def in pairs(Vendor.defs) do
        if def.class and def.companion then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

local function recruit(player, vendorId)
    player.completedQuests = player.completedQuests or {}
    player.completedQuests[assert(Errand.opener(vendorId), vendorId .. " posts an opener")] = true
end

local function recruitAll(player)
    for _, id in ipairs(houses()) do recruit(player, id) end
end

local function rack(player, day, which)
    local out = {}
    for _, row in ipairs(Market.stock(player, day)) do
        if row.rack == which then out[#out + 1] = row end
    end
    return out
end

local function ids(rows)
    local out = {}
    for _, row in ipairs(rows) do out[#out + 1] = row.id end
    table.sort(out)
    return out
end

return {
    {
        name = "the standing rack is the declared plain kit, and nothing else is on it",
        fn = function()
            local p = Player.new()
            recruitAll(p)

            local want, got = set(DRAUGHTS), {}
            for _, id in ipairs(BLADES) do want[id] = true end

            for _, row in ipairs(rack(p, 1, Market.COUNTER)) do
                assert(want[row.id], row.id .. " is standing stock and is not on the declared list")
                got[row.id] = true
            end
            for id in pairs(want) do
                assert(got[id], id .. " is declared standing stock and is not on the counter")
            end
        end,
    },
    {
        name = "a company that has recruited nobody is sold draughts and no blades",
        fn = function()
            local p = Player.new()
            local out = ids(rack(p, 1, Market.COUNTER))
            assert(#out == #DRAUGHTS,
                "an unrecruited company sees " .. #DRAUGHTS .. " draughts and no blade; got " .. #out)
            for i, id in ipairs(out) do
                assert(id == DRAUGHTS[i], "expected " .. DRAUGHTS[i] .. " got " .. id)
            end
        end,
    },
    {
        name = "recruiting a house puts that class's blades out, and only that class's",
        fn = function()
            local p = Player.new()
            recruit(p, "bastion") -- Rowan, and the knight's three

            local seen = {}
            for _, row in ipairs(rack(p, 1, Market.COUNTER)) do
                local def = Item.defs[row.id]
                if def.type == "weapon" then seen[#seen + 1] = row.id end
            end
            assert(#seen > 0, "recruiting a house puts its blades on the counter")
            for _, id in ipairs(seen) do
                assert(Item.classOf(Item.defs[id]) == "knight",
                    id .. " is out with only the Bastion recruited, and it is not a knight's")
            end

            -- ...and the draughts never moved, because a need is not gated.
            local draughts = 0
            for _, row in ipairs(rack(p, 1, Market.COUNTER)) do
                if Item.defs[row.id].type == "consumable" then draughts = draughts + 1 end
            end
            assert(draughts == #DRAUGHTS,
                "the draughts stand whoever has joined; got " .. draughts .. " of " .. #DRAUGHTS)
        end,
    },
    {
        name = "today's rack is three rolled rows, none of them plain kit",
        fn = function()
            local p = Player.new()
            recruitAll(p)

            local today = rack(p, 1, Market.TODAY)
            assert(#today == Market.ROTATION,
                "the rotation deals " .. Market.ROTATION .. " rows; got " .. #today)
            for _, row in ipairs(today) do
                assert(not Market.isStaple(Item.defs[row.id]),
                    row.id .. " is standing stock and cannot also be dealt as today's")
            end
        end,
    },
    {
        name = "today's rack is dealt first: the perishable rack takes the top of the counter",
        fn = function()
            -- The standing rack will be there tomorrow and the day after; the three rolled rows will
            -- not. So the rack that is gone by morning is the one the eye lands on, and nothing has to
            -- be scrolled past to reach it.
            local p = Player.new()
            recruitAll(p)

            local stock = Market.stock(p, 5)
            assert(#stock > Market.ROTATION, "the counter carries both racks")
            for i = 1, Market.ROTATION do
                assert(stock[i].rack == Market.TODAY,
                    "row " .. i .. " is off the " .. tostring(stock[i].rack) .. " rack, not today's")
            end
            for i = Market.ROTATION + 1, #stock do
                assert(stock[i].rack == Market.COUNTER,
                    "the standing rack follows today's, unbroken; row " .. i .. " is not on it")
            end
        end,
    },
    {
        name = "the rotation is the same all day, and different tomorrow",
        fn = function()
            local p = Player.new()
            local a, b = ids(rack(p, 7, Market.TODAY)), ids(rack(p, 7, Market.TODAY))
            for i, id in ipairs(a) do
                assert(b[i] == id, "asking twice on one day must deal the same rows")
            end

            -- Not an assertion about any one pair of days -- three rows out of a pool of hundreds
            -- could collide -- but the roll must move at all across a span a player would notice.
            local moved = false
            for day = 2, 12 do
                local other = ids(rack(p, day, Market.TODAY))
                for i, id in ipairs(a) do
                    if other[i] ~= id then moved = true break end
                end
                if moved then break end
            end
            assert(moved, "the rotation must turn over inside a fortnight")
        end,
    },
    {
        name = "nothing on the counter is locked, and the whole of it fits in a player's head",
        fn = function()
            local p = Player.new()
            recruitAll(p)
            local stock = Market.stock(p, 3)

            for _, row in ipairs(stock) do
                assert(not row.locked, row.id .. " is greyed on a counter that lists no ladder")
                assert(row.rack, row.id .. " is on the counter off no rack")
                assert((row.price or 0) > 0, row.id .. " is out with no price on it")
            end

            -- THE CEILING, and it is the whole complaint. The counter listed 485 rows before this;
            -- the number a player can hold is the number of decisions they can compare.
            assert(#stock <= 30, "the counter is out with " .. #stock .. " rows, which is a catalogue")
        end,
    },
    {
        name = "the shop asks the market, rather than the shelf the seven houses had",
        fn = function()
            -- A SOURCE SCAN, because ui/panels/shop.lua bakes fonts at construction and this rule is
            -- about which function the panel calls rather than about anything it draws. The bug being
            -- pinned was exactly this and nothing else: a complete model, no caller.
            local src = assert(love.filesystem.read("ui/panels/shop.lua"), "shop panel is readable")
            assert(src:find("Market%.stock%(", 1, false),
                "the shop must ask Market.stock what is on the counter")
            assert(src:find("self%.def%.sellsAll", 1, false),
                "the buy list must route a sellsAll vendor to the market builder")
        end,
    },
    {
        name = "a rack is announced when its companion joins, once, and only ever for stock that is out",
        fn = function()
            local p = Player.new()

            -- The opening morning is absorbed silently: what is already out is not news.
            Market.markOpened(p)

            local before = {}
            for id in pairs(p.newStock or {}) do before[id] = true end

            recruit(p, "bastion")
            local opened = Market.markOpened(p)
            assert(opened and #opened.items > 0, "joining a companion opens their class's rack")

            local counter = {}
            for _, row in ipairs(rack(p, 1, Market.COUNTER)) do counter[row.id] = true end
            for _, id in ipairs(opened.items) do
                assert(not before[id], id .. " was announced twice")
                assert(counter[id], id .. " was dotted and is not on the counter")
                assert(Player.isNew(p, Player.NEW_STOCK, id), id .. " was reported and not marked")
            end

            assert(Market.markOpened(p) == nil, "the same rack is never announced a second time")
        end,
    },
}
