-- THE INN, as a counter rather than as a bill.
--
-- Three things this room owes the player, and each is a rule the city keeps everywhere else:
--
--   a keeper    a mark, a name and a one-time greeting, off data/vendors/inn.lua -- the same terms
--               the Cafe, the Touchstone and the Crossing stand on, and the reason the Inn declares a
--               vendor id at all. It must NOT be a shelf: a vendor with a class is a market house
--               (tests/hub_spec.lua refuses one standing in the city), and this one sells no items.
--   a greeting  played once, on the first visit, by models/vendor_visit.lua. Asked here rather than
--               through the hub because that screen needs a window and this rule does not.
--   a dead row  "Take the rooms" is drawn and refused when there is nothing to set. Coming home already
--               restores health and mana for free (Player.restore), so a night buys exactly one thing --
--               the bones -- and with none to set, pressing it would take the gold and change nothing.
--   a purse     the gold the company is carrying, in the keeper pane, where every shelf in the city
--               prints it. The bill climbs per head, so the decision is what the night leaves behind.
--
-- And one row, not two: the X, Esc and B are the way out of every panel in the game, so a "Not tonight"
-- card beside the rooms was the same door drawn twice.
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
            -- A keeper is a NAME, a MARK and a LINE. It used to be a name, a *portrait* and a line, and
            -- the portrait was the one of the three that never existed: no vendor art was ever
            -- commissioned, so every counter drew a lettered plate where the face went. The panes are
            -- gone (ui/vendor_icons.lua drawNamed) and the house's own glyph rides on the name instead,
            -- so the thing to assert is that this counter HAS a mark -- which, unlike the sprite path,
            -- is a claim about something that is actually drawn.
            local VendorIcons = require("ui.vendor_icons")
            assert(def.name and def.description,
                "a keeper is a name and a line; the Inn is missing one")
            assert(VendorIcons.has(INN), "the Inn has no mark, so its panel would title itself blank")
            assert(def.sells == false, "the Inn must sell no items at all")
            assert(not def.class, "a vendor with a class is a market house; the Inn stands in the city")
            assert(#Vendor.stock(INN, 99, {}, {}, {}) == 0, "something drifted onto the Inn's counter")

            -- The building is what wires the keeper to the door: without this the greeting never plays
            -- and the panel has no keeper to title itself with.
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

                panel:choose(1)
                assert(p.gold == purse, "a refused row took the money anyway")
                assert(not panel.finished, "a refused row spent the card")
            end)
        end,
    },
    {
        name = "taking the rooms rests the company, sets no bone, and stays available",
        fn = function()
            stubFonts(function()
                local p = company(3, 2)
                local price = Gate.innPrice(p)
                local purse = p.gold
                local panel = openInn(p)

                panel:choose(1)
                assert(p.gold == purse - price, "the night was not paid for")
                -- A NIGHT SETS NO BONES. It used to clear the whole ledger for this one bill; mending
                -- is a bed now, per wound and a day each (models/gate.lua Gate.lodge).
                assert(#Wound.wounded(p) > 0, "a bed is not a surgeon")
                -- The card is rebuilt in place (the proxy forwards to whichever is current). The row stays
                -- LIVE, because a night is worth taking again tomorrow -- it is not a one-shot repair.
                assert(rooms(panel), "the rooms are still on offer")
            end)
        end,
    },
    {
        -- The way out is the X in the corner, Esc and B -- the same exit every panel in the game keeps.
        -- A "Not tonight" row was the door drawn twice, and this is what stops it coming back.
        name = "the card offers the rooms and nothing else, and still lets the player leave",
        fn = function()
            stubFonts(function()
                local closed = false
                local Inn = require("ui.panels.inn")
                local panel = Inn.new({ player = company(3, 2), vendor = INN,
                    onClose = function() closed = true end })
                assert(#panel.options == 1, "the Inn's card carries a row that is not the rooms")

                panel:close()
                assert(closed, "the only way out of the Inn does not open")
            end)
        end,
    },
    {
        -- What is really being decided at a counter whose price climbs per head: whether the night
        -- leaves enough for the day after it. The keeper pane prints it where every shelf prints it.
        name = "the purse is on the card, and it moves when the night is paid for",
        fn = function()
            stubFonts(function()
                local p = company(3, 2)
                local price = Gate.innPrice(p)
                local purse = p.gold
                local panel = openInn(p)
                assert(panel.keeper.gold == purse, "the Inn does not show what the company is carrying")

                panel:choose(1)
                assert(panel.keeper.gold == purse - price,
                    "the purse still says what it held before the night")
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
