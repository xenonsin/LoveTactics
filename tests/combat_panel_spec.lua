-- THE COMBAT PANEL IS BUILT, not just loaded.
--
-- This file exists because of a specific, shipped regression. Removing Fall Back took an unrelated line
-- out with it -- `self.gridY = self.waitBtn.y - 14 - self.gridH`, which sat between two of that button's
-- fields -- and every battle from that commit forward died in CombatPanel.new with "attempt to perform
-- arithmetic on field 'gridY' (a nil value)". The suite stayed green through all of it.
--
-- It stayed green because tests/ui_load_spec.lua only REQUIRES each ui module, which proves the file
-- parses and touches no love.graphics at require-time. Neither claim says the widget can be constructed,
-- and construction is where a deleted field turns into a crash. One is a compile check, the other is a
-- unit test, and the project only had the first.
--
-- Fonts are stubbed rather than loaded: the suite runs with `t.window = false`, so love.graphics.newFont
-- throws. The stub is the same one the panel specs have always used -- enough of a font to measure text
-- with, which is all any of this geometry asks of one.

local CombatPanel = require("ui.combat_panel")
local Scale = require("scale")

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

-- The panel reads nothing off the combat in its constructor, so a bare table is the honest fixture:
-- what is under test is the geometry, and a real battle would only add ways for this to fail for
-- reasons that are not the panel's.
local function panel()
    return CombatPanel.new({ units = {}, bench = {} }, {})
end

return {
    {
        name = "the combat panel constructs, and every geometry field it lays out is a number",
        fn = function()
            stubFonts(function()
                local p = panel()

                -- Named one at a time rather than walked, so a failure says WHICH field went missing --
                -- which is the entire diagnostic value here. `gridY` is the one that actually broke.
                for _, field in ipairs({ "x", "w", "gridX", "gridY", "gridW", "gridH",
                                         "stripTop", "stripBottom" }) do
                    assert(type(p[field]) == "number",
                        "CombatPanel." .. field .. " is " .. type(p[field]) .. ", not a number -- a "
                            .. "field the constructor lays out has gone missing, and every battle in "
                            .. "the game dies opening this panel")
                end
                assert(type(p.waitBtn) == "table" and type(p.waitBtn.y) == "number",
                    "the bottom lane's button has no laid-out position")
            end)
        end,
    },
    {
        name = "the panel's stack reads top to bottom: strip, then grid, then the bottom lane",
        fn = function()
            stubFonts(function()
                local p = panel()

                -- ORDER, not values. The numbers are free to be tuned; what must hold is that the three
                -- bands stack in the order the panel is described in, because a field that comes back as
                -- the wrong KIND of number (a zero, a leftover) usually shows up here first rather than
                -- as a nil.
                assert(p.stripTop < p.stripBottom,
                    "the turn strip ends above where it starts: " .. p.stripTop .. " -> " .. p.stripBottom)
                assert(p.stripBottom < p.gridY,
                    "the item grid starts above the strip it sits under: " .. p.stripBottom
                        .. " -> " .. p.gridY)
                assert(p.gridY + p.gridH <= p.waitBtn.y,
                    "the item grid runs into the bottom lane: grid ends at " .. (p.gridY + p.gridH)
                        .. ", the button starts at " .. p.waitBtn.y)
                assert(p.waitBtn.y + p.waitBtn.h <= Scale.HEIGHT,
                    "the bottom lane hangs off the bottom of the 1280x720 space")
                assert(p.x + p.w <= Scale.WIDTH, "the panel hangs off the right edge")
            end)
        end,
    },
}
