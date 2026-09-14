-- The potion panel's BOX, against the space it is actually drawn in (ui/panels/consumables.lua).
--
-- This panel is opened from two places in two different spaces: the overworld, which is the 1280x720
-- one it was authored in, and the deployment phase (states/battle.lua's openDeployPotions), which on
-- a handheld is 880x450. Centred at a fixed 860x576 it hung off both ends of the short one -- and the
-- piece that went off the top was the close X, on the one device that has no Esc key and no gamepad B
-- to fall back on. The click-off escape was no help either: the box covered the full width bar a
-- ten-pixel sliver down each side. The panel could be opened and not closed.
--
-- Constructed by hand rather than through Consumables.new, which builds fonts -- love.graphics.newFont
-- throws under the headless runner (see tests/ui_load_spec.lua). Everything pinned here is geometry,
-- which is the half with no window in it.

local Consumables = require("ui.panels.consumables")
local Scale = require("scale")

-- The fields layout() and clampScroll() read. The lists are deliberately longer than the short
-- space can show, since a squeezed window that cannot scroll is the other way to lose a row.
local function panel(members, entries)
    local p = setmetatable({}, Consumables)
    p.members = members or { {}, {}, {}, {} }
    p.entries = entries or { {}, {}, {}, {}, {}, {} }
    p.target, p.itemCursor = 1, 1
    p.memberScroll, p.itemScroll = 0, 0
    p:layout()
    return p
end

-- Put a space on the table, run the case in it, and always put the old one back -- these are module
-- globals, and a spec that leaves 880x450 behind changes the arithmetic under every spec after it.
local function inSpace(w, h, fn)
    local ow, oh, oe = Scale.WIDTH, Scale.HEIGHT, Scale.spaceEpoch
    Scale.WIDTH, Scale.HEIGHT = w, h
    Scale.spaceEpoch = oe + 1
    local ok, err = pcall(fn)
    Scale.WIDTH, Scale.HEIGHT, Scale.spaceEpoch = ow, oh, oe
    assert(ok, err)
end

local function inside(r, w, h)
    return r.x >= 0 and r.y >= 0 and r.x + r.w <= w and r.y + r.h <= h
end

return {
    {
        name = "the box and its close X fit the handheld space the fight is drawn in",
        fn = function()
            inSpace(880, 450, function()
                local p = panel()
                assert(inside({ x = p.boxX, y = p.boxY, w = p.boxW, h = p.boxH }, 880, 450),
                    string.format("the box hangs off the screen: %d,%d %dx%d in 880x450",
                        p.boxX, p.boxY, p.boxW, p.boxH))
                local c = p.closeButton
                assert(inside(c, 880, 450),
                    string.format("the close X is off the screen at %d,%d -- with no Esc key on a "
                        .. "handheld, that is a panel with no way out", c.x, c.y))
                -- ...and it is still a usable panel, not a sliver: a member to target and a flask to pour.
                assert(p:visibleMembers() >= 1, "no member row survived the squeeze")
                assert(p:visibleItems() >= 1, "no potion row survived the squeeze")
            end)
        end,
    },
    {
        name = "the squeezed lists still scroll, so nothing is lost with the rows",
        fn = function()
            inSpace(880, 450, function()
                local p = panel()
                assert(p:maxMemberScroll() > 0, "four members in a two-row window must be scrollable")
                assert(p:maxItemScroll() > 0, "six flasks in a four-row window must be scrollable")
                -- The window follows the cursor: targeting the last member must bring it into view.
                p.target = #p.members
                p:clampScroll()
                assert(p:memberRect(#p.members) ~= nil, "the targeted member scrolled out of sight")
            end)
        end,
    },
    {
        name = "the desktop space keeps the panel exactly as it was authored",
        fn = function()
            inSpace(1280, 720, function()
                local p = panel()
                assert(p.boxW == 860 and p.boxH == 576,
                    string.format("the authored box changed shape: %dx%d", p.boxW, p.boxH))
                assert(p.boxX == 210 and p.boxY == 72, "the box left centre")
                assert(p:visibleMembers() == 4,
                    "the company column promises four rows before it scrolls (MIN_MEMBER_ROWS)")
            end)
        end,
    },
    {
        name = "a space that changes under an open panel re-fits it",
        fn = function()
            -- A phone turned, or a window dragged across the handheld threshold. The panel is open
            -- throughout; only the space moves.
            inSpace(1280, 720, function()
                local p = panel()
                assert(p.boxH == 576, "opened in the tall space")
                Scale.WIDTH, Scale.HEIGHT = 880, 450
                Scale.spaceEpoch = Scale.spaceEpoch + 1
                p:update(0.016)
                assert(p.boxH < 576, "the panel kept the old space's height")
                assert(inside(p.closeButton, 880, 450),
                    "the close X went off the edge when the space changed under it")
            end)
        end,
    },
}
