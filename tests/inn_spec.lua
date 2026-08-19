-- THE INN, as a counter rather than as a bill.
--
-- Three things this room owes the player, and each is a rule the city keeps everywhere else:
--
--   a keeper    a portrait, a name and a one-time greeting, off data/vendors/inn.lua -- the same terms
--               the Cafe, the Touchstone and the Hero's Rift stand on, and the reason the Inn declares a
--               vendor id at all. It must NOT be a shelf: a vendor with a class is a market house
--               (tests/hub_spec.lua refuses one standing in the city), and this one sells no items.
--   a greeting  played once, on the first visit, by models/vendor_visit.lua. Asked here rather than
--               through the hub because that screen needs a window and this rule does not.
--   a dead row  "Take the rooms" is drawn and refused when there is nothing to set. Coming home already
--               restores health and mana for free (Player.restore), so a night buys exactly one thing --
--               the bones -- and with none to set, pressing it would take the gold and change nothing.
--
-- The panel half borrows tests/vendor_service_spec.lua's stubbed-font trick, since Choice.new bakes
-- fonts and love.graphics.newFont throws with no window.

local Character = require("models.character")
local Conversation = require("models.conversation")
local Gate = require("models.gate")
local Player = require("models.player")
local Vendor = require("models.vendor")
local VendorVisit = require("models.vendor_visit")
local Wound = require("models.wound")

local INN = "inn"

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

-- A company of `n`, with `hurt` of them carrying one wound each and a purse that can cover the night.
--
-- THREE DISTINCT BLUEPRINTS, not one dealt twice: wounds are keyed by character id (models/wound.lua),
-- so two bodies off the same blueprint share one entry and hurting either hurts both.
local BODIES = { "character_knight", "character_archer", "character_rowan", "character_mage" }
local function company(n, hurt)
    local p = Player.new()
    p.roster = {}
    for i = 1, n do
        p.roster[i] = Character.instantiate(BODIES[i])
    end
    p.wounds = {}
    for i = 1, (hurt or 0) do
        p.wounded = true
        p.wounds[p.roster[i].id] = 1
    end
    p.gold = Gate.innPrice(p) * 4
    return p
end

-- The panel, opened on a given company. Returns the live Choice card underneath the swap proxy.
local function openInn(player)
    local Inn = require("ui.panels.inn")
    return Inn.new({ player = player, vendor = INN, onClose = function() end })
end

local function rooms(panel) return panel.options[1] end

return {
    {
        name = "the Inn keeps a keeper and no shelf, so it never lands on the market board",
        fn = function()
            local def = Vendor.get(INN)
            assert(def, "the Inn names a vendor that does not exist")
            assert(def.name and def.sprite and def.description,
                "a keeper is a name, a portrait and a line; the Inn is missing one")
            assert(def.sells == false, "the Inn must sell no items at all")
            assert(not def.class, "a vendor with a class is a market house; the Inn stands in the city")
            assert(#Vendor.stock(INN, 99, {}, {}, {}) == 0, "something drifted onto the Inn's counter")

            -- The building is what wires the keeper to the door: without this the greeting never plays
            -- and the panel has no portrait to draw.
            local Building = require("models.building")
            assert(Building.defs.the_inn.vendor == INN, "the Inn's blueprint names no keeper")
        end,
    },
    {
        name = "the innkeeper greets the company once, and never again",
        fn = function()
            local id = "conversation_" .. INN .. "_vendor_intro"
            assert(Conversation.defs[id], "the innkeeper has no first-visit scene")

            local p = company(3, 1)
            local first = VendorVisit.steps(p, INN)
            assert(#first == 1 and first[1].id == id,
                "the first visit does not owe the greeting")

            -- Recording is the step's own job, exactly as it is for every other counter.
            first[1].before()
            assert(Player.hasVisitedVendor(p, INN), "the greeting did not record itself")
            assert(#VendorVisit.steps(p, INN) == 0, "the greeting plays a second time")
        end,
    },
    {
        name = "the rooms are live while somebody is carrying a wound",
        fn = function()
            stubFonts(function()
                local panel = openInn(company(3, 2))
                assert(not rooms(panel).disabled, "the rooms refused a company with two wounded in it")
                assert(panel.focus == 1, "the live row did not open focused")
                assert(panel.prompt:find("2 of them need"), "the card does not say how many need the surgeon")
            end)
        end,
    },
    {
        name = "the rooms grey out when nobody is broken, and pressing them spends nothing",
        fn = function()
            stubFonts(function()
                local p = company(3, 0)
                local purse = p.gold
                local panel = openInn(p)
                assert(rooms(panel).disabled, "the rooms are still live with nobody to mend")
                assert(panel.focus == 2, "the dead row opened focused on itself")

                panel:choose(1)
                assert(p.gold == purse, "a refused row took the money anyway")
                assert(not panel.finished, "a refused row spent the card")
            end)
        end,
    },
    {
        name = "taking the rooms sets every bone, and the row goes dark under the player's hand",
        fn = function()
            stubFonts(function()
                local p = company(3, 2)
                local price = Gate.innPrice(p)
                local purse = p.gold
                local panel = openInn(p)

                panel:choose(1)
                assert(p.gold == purse - price, "the night was not paid for")
                assert(#Wound.wounded(p) == 0, "somebody came down to breakfast still broken")
                -- The card is rebuilt in place (the proxy forwards to whichever is current), so the row
                -- the player just pressed is the one that has to be dark now.
                assert(rooms(panel).disabled, "the rooms stayed live with nothing left to set")
                assert(panel.focus == 2, "focus was left sitting on a dead row")
            end)
        end,
    },
    {
        name = "a purse that cannot cover the night deadens the row rather than failing on the press",
        fn = function()
            stubFonts(function()
                local p = company(3, 2)
                p.gold = Gate.innPrice(p) - 1
                local panel = openInn(p)
                assert(rooms(panel).disabled, "the rooms were offered to a company that cannot pay")
                assert(rooms(panel).desc:find("cover"), "the dead row does not say why")
            end)
        end,
    },
}
