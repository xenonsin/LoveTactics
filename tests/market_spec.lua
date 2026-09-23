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

-- THE QUEST BLUEPRINTS ARE GONE, AND SO IS WHAT THEY WERE COVERING. data/quests was deleted
-- with the seven house postings (92ff549d), which took companion recruitment, the market's openers,
-- Saber's debut and every `slot_01` with it. The cases below had no data left to run against and
-- were removed on 2026-09-23 rather than left red. Each one is listed so the hole is findable:
--
--   * a company that has recruited nobody is sold draughts and no blades
--   * a rack is announced when its companion joins, once, and only ever for stock that is out
--   * a rolled row is one each: bought today, it is greyed where it stood
--   * no ladder is greyed on the counter, and the whole of it fits in a player's head
--   * recruiting a house puts that class's blades out, and only that class's
--   * the market's door dots for its own counter, and goes out when that counter is read
--   * the market's room is marked off its own counter, not off the shelf
--   * the standing rack is the declared plain kit, and nothing else is on it
--   * today's rack is dealt first: the perishable rack takes the top of the counter
--   * today's rack is three rolled rows, none of them plain kit
--   * what was bought today is inert tomorrow, however the roll falls
--
-- Nothing above is a rule that was decided against; it is coverage that lost its subject. When the
-- replacement for the postings lands, these are the cases it owes back.

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
        -- WHAT THE COUNTER IS BANDED AGAINST, and it is one thing: the deepest floor this company has
        -- ever stood on. Two halves, and the first is a deletion -- the tier used to be the highest of
        -- depth, the roster's best class level and its spread, so a company that had never gone down
        -- could still open the deep end of the counter by levelling at home.
        name = "the counter's tier is the deepest floor reached, and nothing else moves it",
        fn = function()
            local Descent = require("models.descent")
            local p = Player.new()
            assert(Market.tier(p) == 0, "a company that has never gone down bands at nought")

            -- A body several rungs up its class, still having descended nowhere. Written straight onto
            -- the ladder the tier used to read, so the case fails if either reading comes back.
            local char = assert(p.roster and p.roster[1], "a new company has a body to level")
            char.technique = char.technique or {}
            char.technique.knight = Class.classLevelCost(Class.CLASS_LEVEL_CAP)
            assert(Class.classLevel(char, "knight") == Class.CLASS_LEVEL_CAP,
                "the fixture has to actually stand at the top of a ladder")
            assert(Market.tier(p) == 0,
                "class levels are practice, not a place: they must not band the counter")

            -- ...AND IN THE RIFT'S OWN UNIT. A floor is worth two levels, so the fourth floor bands at
            -- seven and not at four -- which is the ladder the floors themselves deal their finds on.
            Descent.reached(p, 4)
            assert(Market.tier(p) == Descent.floorLevel({ floor = 4 }),
                "the counter bands on what the floor is worth, not on its number")

            -- Monotone and capped: the record does not fall when the company climbs out, and the tier
            -- and a rung stay the same unit however deep the rift goes.
            Descent.reached(p, 2)
            assert(Market.tier(p) == Descent.floorLevel({ floor = 4 }), "a record is not lowered")
            Descent.reached(p, 15)
            assert(Market.tier(p) == Class.CLASS_LEVEL_CAP, "the tier is a rung and stops where rungs do")
        end,
    },
}
