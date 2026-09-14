-- The victory panel's BOX, against the space it is actually drawn in (ui/panels/battle_summary.lua).
--
-- This panel grows with the fight: a banner, the purse, an experience bar and a technique block per
-- body, a grid of loot, the action row, the review button. In the 1280x720 space it was authored in
-- there is room for all of it and the box simply gets taller. The fight is also played in the short
-- handheld space (880x450 -- states/battle.lua's handheldSpace), where a rich victory came out some
-- 550 tall and centred: the close X went off the top and the ACTION ROW went off the bottom. That is
-- not a clipped decoration -- it is the way out of the screen, on the one device with no Esc key
-- standing behind it.
--
-- So what is pinned here is that the exits are always ON the screen, and that the panel never draws
-- its own way out across its own contents (contentRelY <= buttonRelY -- the bench's single line
-- escaped the first cut of the budget and put Continue through the loot labels).
--
-- Fonts are stubbed, as every geometry spec here stubs them (`t.window = false`, so newFont throws).
-- What is under test is arithmetic; the typography is what the screenshots in the commit are for.

local Scale = require("scale")

local function withFonts(fn)
    local gfx = love.graphics
    local real = gfx.newFont
    local face = {
        getHeight = function() return 18 end,
        getWidth = function(_, s) return #tostring(s or "") * 8 end,
        getWrap = function(self, text, limit)
            local lines = { tostring(text) }
            return self:getWidth(text), lines
        end,
    }
    gfx.newFont = function() return face end
    local ok, err = pcall(fn)
    gfx.newFont = real
    if not ok then error(err, 0) end
end

-- Put a space on the table, run the case in it, and always put the old one back: these are module
-- globals, and a spec that leaves 880x450 behind changes the arithmetic under every spec after it.
-- `inHandheldSpace` is derived exactly as scale.lua derives it (applySpace: the short space is the
-- one whose height IS Scale.HANDHELD_H), so a case does not have to remember to set two things and
-- cannot set them to disagree.
local function inSpace(w, h, fn)
    local ow, oh, oflag = Scale.WIDTH, Scale.HEIGHT, Scale.inHandheldSpace
    Scale.WIDTH, Scale.HEIGHT = w, h
    Scale.inHandheldSpace = (h == Scale.HANDHELD_H)
    local ok, err = pcall(fn)
    Scale.WIDTH, Scale.HEIGHT, Scale.inHandheldSpace = ow, oh, oflag
    assert(ok, err)
end

-- THE RICHEST ORDINARY VICTORY: coin, six distinct drops, a bar and four technique rows for each of
-- four bodies, the bench's share, and both exits. Anything that fits this fits a quieter fight.
local function richWin()
    local bodies = { "Knight", "Archer", "Mage", "Rogue" }
    local xp, tech = {}, {}
    for i, name in ipairs(bodies) do
        local char = { id = "char" .. i, name = name }
        xp[i] = { char = char, name = name, gain = 30 + i, from = 370, to = 400,
                  fromLevel = 3, toLevel = 4 }
        tech[i] = { char = char, name = name, rungs = {}, houses = {
            { key = "warrior", amount = 14 }, { key = "ranger", amount = 9 },
            { key = "mage", amount = 6 }, { key = "rogue", amount = 4 },
        } }
    end
    return {
        result = "win",
        -- Six DISTINCT drops, so the grid is six cards rather than one card reading "x6". Every id
        -- here is one another spec already exercises: naming an id in a test file is what
        -- tests/item_coverage_spec.lua counts as coverage, and a geometry fixture must not be what
        -- takes an item off that backlog.
        spoils = { gold = 340, loot = {
            "consumable_acid_bomb", "consumable_ball_bearings", "consumable_battle_tonic",
            "consumable_smoke_bomb", "weapon_iron_dagger", "armor_chainmail",
        } },
        technique = tech, experience = xp, benchShare = 12,
        encounter = { name = "Rift Mouth" },
        actions = { { label = "Continue", onSelect = function() end } },
        onReviewLog = function() end,
    }
end

local function build(opts)
    -- Required INSIDE the font stub: the module is cached, but new() builds its faces per panel.
    return require("ui.panels.battle_summary").new(opts)
end

local function inside(r, w, h)
    return r.x >= 0 and r.y >= 0 and r.x + r.w <= w and r.y + r.h <= h
end

return {
    {
        name = "every way out of the victory panel is on a handheld screen",
        fn = function()
            withFonts(function()
                inSpace(880, 450, function()
                    local p = build(richWin())
                    assert(p.boxY >= 0 and p.boxY + p.boxH <= 450,
                        string.format("the box hangs off the screen: y=%d h=%d in 880x450",
                            p.boxY, p.boxH))
                    assert(inside(p.closeButton, 880, 450),
                        string.format("the close X is off the screen at y=%.0f", p.closeButton.y))
                    for i, btn in ipairs(p.buttons) do
                        assert(inside(btn, 880, 450), string.format(
                            "action %d ('%s') is off the screen at y=%.0f -- with no Esc key on a "
                            .. "handheld, that is a panel that cannot be dismissed",
                            i, tostring(p.actions[i] and p.actions[i].label), btn.y))
                    end
                    assert(p.reviewButton == nil or inside(p.reviewButton, 880, 450),
                        "the review button is off the screen")
                end)
            end)
        end,
    },
    {
        name = "the action row never draws across the tally it is under",
        fn = function()
            withFonts(function()
                for _, space in ipairs({ { 880, 450 }, { 1280, 720 }, { 1024, 450 } }) do
                    inSpace(space[1], space[2], function()
                        local p = build(richWin())
                        assert(p.contentRelY <= p.buttonRelY, string.format(
                            "in %dx%d the tally runs to %d and the action row starts at %d -- "
                            .. "Continue is drawn over the loot", space[1], space[2],
                            p.contentRelY, p.buttonRelY))
                    end)
                end
            end)
        end,
    },
    {
        name = "the loot row widens before it takes a second row, but only where it must",
        fn = function()
            withFonts(function()
                -- Short: height is the scarce axis and the space is wide, so six cards go in one row.
                inSpace(880, 450, function()
                    local p = build(richWin())
                    assert(p.perRow >= 6, "six cards should fit one row in the short space, got "
                        .. tostring(p.perRow))
                end)
                -- Tall: four to a row is the authored look, and the desktop keeps it whatever drops.
                inSpace(1280, 720, function()
                    local p = build(richWin())
                    assert(p.perRow == 4,
                        "the desktop row is a LOOK, not a fit; it should stay four, got "
                        .. tostring(p.perRow))
                end)
            end)
        end,
    },
    {
        name = "a handheld victory screen carries no per-body bars at all",
        fn = function()
            withFonts(function()
                inSpace(880, 450, function()
                    local p = build(richWin())
                    assert(p.blocks == nil, "the per-body section is a desktop reading")
                    assert(not p.hasXp, "no experience bars on a handheld")
                    assert(p.benchShare == nil, "the bench line belongs to the section that went")
                end)
                -- ...and it is the SPACE that decides, not the haul: a quiet win with nothing in the
                -- way keeps no bars either, so the screen answers the same way every fight.
                inSpace(880, 450, function()
                    local quiet = richWin()
                    quiet.spoils = { gold = 12 }
                    local p = build(quiet)
                    assert(p.blocks == nil,
                        "a small haul left room and the bars came back -- the rule is the space")
                end)
            end)
        end,
    },
    {
        name = "the desktop panel still tells the whole story",
        fn = function()
            withFonts(function()
                inSpace(1280, 720, function()
                    local p = build(richWin())
                    -- The per-body section is the grower that gives way in a short space; in the one
                    -- the panel was authored for it must still be there, bars and bench line alike.
                    assert(p.blocks and #p.blocks > 0, "the experience section vanished on a desktop")
                    assert(p.hasXp, "the bars vanished on a desktop")
                    assert(p.benchShare, "the bench line vanished on a desktop")
                end)
            end)
        end,
    },
}
