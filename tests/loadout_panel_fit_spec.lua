-- The Loadout panel's BOX and its four columns, against the space it is drawn in (ui/panels/party.lua).
--
-- This is the widest screen in the game -- 1160x650 of rail, focus sheet, member grid and stash -- and
-- it is opened from the deployment phase as well as from the city. A fight on a handheld is played in
-- an 880x450 space (states/battle.lua's handheldSpace), where a 1160x650 box centres at (-140, -100):
-- it covers the screen entirely, its close X sits off the top, and the click-off escape in
-- mousepressed has no outside left to land in. On a device with no Esc key that is a panel which
-- opens and does not shut.
--
-- What is pinned here: the box and the X are on the screen, the four columns are inside the box and
-- do not overlap, the grid stays square and the stash keeps enough columns to be a stash. The
-- arrangement it reaches to do that -- a smaller grid cell, and the focus sheet dropped where it
-- cannot be seated -- is the panel's own business and is asserted only where a number would
-- otherwise be free to go silly.
--
-- Fonts are stubbed, as every geometry spec here stubs them (`t.window = false`, so newFont throws).

local Scale = require("scale")
local Character = require("models.character")

local function withFonts(fn)
    local gfx = love.graphics
    local real = gfx.newFont
    local face = {
        getHeight = function() return 18 end,
        getWidth = function(_, s) return #tostring(s or "") * 8 end,
        getWrap = function(self, text, limit) return self:getWidth(text), { tostring(text) } end,
    }
    gfx.newFont = function() return face end
    local ok, err = pcall(fn)
    gfx.newFont = real
    if not ok then error(err, 0) end
end

local function inSpace(w, h, fn)
    local ow, oh, oflag = Scale.WIDTH, Scale.HEIGHT, Scale.inHandheldSpace
    Scale.WIDTH, Scale.HEIGHT = w, h
    Scale.inHandheldSpace = (h == Scale.HANDHELD_H)
    local ok, err = pcall(fn)
    Scale.WIDTH, Scale.HEIGHT, Scale.inHandheldSpace = ow, oh, oflag
    assert(ok, err)
end

-- A company of four with a stash behind it: the panel reads `player.roster` and `player.stash`, and
-- the tabs it builds (Tactics, the Roll) want a character apiece.
local function build()
    local Party = require("ui.panels.party")
    local roster = {}
    for i = 1, 4 do roster[i] = Character.instantiate("character_knight") end
    return Party.new({ player = { roster = roster, stash = {} }, onClose = function() end })
end

local function inside(r, w, h)
    return r.x >= 0 and r.y >= 0 and r.x + r.w <= w and r.y + r.h <= h
end

return {
    {
        name = "the Loadout box and its close X fit a handheld screen",
        fn = function()
            withFonts(function()
                inSpace(880, 450, function()
                    local p = build()
                    assert(inside({ x = p.boxX, y = p.boxY, w = p.boxW, h = p.boxH }, 880, 450),
                        string.format("the box hangs off the screen: %d,%d %dx%d in 880x450",
                            p.boxX, p.boxY, p.boxW, p.boxH))
                    assert(inside(p.closeButton, 880, 450), string.format(
                        "the close X is off the screen at %.0f,%.0f -- on a handheld that is the only "
                        .. "way out of this panel", p.closeButton.x, p.closeButton.y))
                end)
            end)
        end,
    },
    {
        name = "the four columns stay inside the box, in order, without overlapping",
        fn = function()
            withFonts(function()
                for _, space in ipairs({ { 880, 450 }, { 1120, 450 }, { 1280, 720 } }) do
                    inSpace(space[1], space[2], function()
                        local p = build()
                        local right = p.boxX + p.boxW - 24
                        local where = string.format(" (in %dx%d)", space[1], space[2])
                        assert(p.railX >= p.boxX + 20, "the rail starts outside the box" .. where)
                        -- The sheet is optional; where it is drawn it sits between rail and grid.
                        if p.focusW > 0 then
                            assert(p.focusX >= p.railX + p.railW,
                                "the focus sheet runs back over the rail" .. where)
                            assert(p.grid.x >= p.focusX + p.focusW,
                                "the grid runs over the focus sheet" .. where)
                        else
                            assert(p.grid.x >= p.railX + p.railW,
                                "the grid runs over the rail" .. where)
                        end
                        assert(p.pool.x >= p.grid.x + p.grid.gridW,
                            "the stash runs over the member grid" .. where)
                        assert(p.pool.x + p.pool.w <= right + 1,
                            "the stash runs off the right edge of the box" .. where)
                        -- ...and down: the grid and the stash both end above the prompt bar's band.
                        local floor = p.boxY + p.boxH - 40
                        assert(p.grid.y + p.grid.gridH <= floor,
                            "the member grid runs into the footer" .. where)
                        assert(p.pool.y + p.pool.h <= floor,
                            "the stash runs into the footer" .. where)
                    end)
                end
            end)
        end,
    },
    {
        name = "the member grid stays square and stays tappable, and the stash stays a grid",
        fn = function()
            withFonts(function()
                inSpace(880, 450, function()
                    local p = build()
                    assert(p.grid.gridW == p.grid.gridH,
                        "the 3x3 grid stopped being square: " .. p.grid.gridW .. "x" .. p.grid.gridH)
                    assert(p.grid.slot >= 56, "the cells shrank below a thumb: " .. p.grid.slot)
                    assert(p.pool.w >= 64 * 3 + 8 * 2,
                        "the stash lost a column and reads as a list: " .. p.pool.w)
                    assert(p.grid.gridW == Character.COLS * p.grid.slot + (Character.COLS - 1) * p.grid.gap,
                        "the grid's width stopped following its own cell")
                end)
            end)
        end,
    },
    {
        name = "the desktop keeps the panel exactly as it was authored",
        fn = function()
            withFonts(function()
                inSpace(1280, 720, function()
                    local p = build()
                    assert(p.boxW == 1160 and p.boxH == 650,
                        string.format("the authored box changed shape: %dx%d", p.boxW, p.boxH))
                    assert(p.grid.slot == 92, "the desktop cell is the authored 92, got " .. p.grid.slot)
                    assert(p.focusW == 300, "the desktop focus sheet is 300, got " .. p.focusW)
                    assert(not p.compact, "the desktop is not the squeezed arrangement")
                end)
            end)
        end,
    },
}
