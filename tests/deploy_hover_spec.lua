-- THE DEPLOYMENT PHASE'S DOCKED HOVER BOXES (ui/deploy_phase.lua's hoverDock): which of the two --
-- the ground, and the body standing on it -- gets the column when the column cannot hold both.
--
-- It shipped holding the fight's rule, that terrain never yields and the occupant is the valve, and on
-- this screen that valve was shut almost all the time: the phase stacks five control plates down the
-- same column (Loadout, Potions, Reset Line, Auto, the bell), which leaves 388px of a 720 screen, and
-- a three-pool body's readout measures 293 against a terrain box of 105-122. Ten pixels over, and the
-- box describing the thing the phase is FOR was dropped without a mark -- so hovering a caster, a
-- healer or an elite answered with "Open Ground. Flat, open field." and nothing else.
--
-- Driven through hoverDock rather than drawHover, which is why the arrangement is decided apart from
-- the drawing: the plan IS what the player gets, and it can be read here without a window.
--
-- Constructed by hand rather than through DeployPhase.new, as tests/deploy_input_spec.lua does and for
-- the same reason (the constructor builds fonts, and love.graphics.newFont throws under the headless
-- runner). Fonts are stubbed as every geometry spec here stubs them.

local Scale = require("scale")
local Character = require("models.character")
local DeployPhase = require("ui.deploy_phase")
local TileTooltip = require("ui.tile_tooltip")

-- Face metrics MEASURED off the shipped fonts rather than invented: the chrome serif stands 21px at
-- the tooltip's title size and the data sans 17px at its body size. A stub that rounded both to 15
-- made every box short enough to fit the column it does not fit -- a spec that would have passed on
-- the very bug it was written for. Keyed on the FACE rather than the size, because the theme floors
-- both sizes on its way through (Theme.MIN_BODY), so the number asked for is not the number used.
local function withFonts(fn)
    local gfx = love.graphics
    local real = gfx.newFont
    local function face(path)
        local body = type(path) == "string" and path:find("ui%-body") ~= nil
        return {
            getHeight = function() return body and 17 or 21 end,
            getWidth = function(_, s) return #tostring(s or "") * 6 end,
            getWrap = function(self, text, limit)
                local w = self:getWidth(text)
                local out = {}
                for i = 1, math.max(1, math.ceil(w / math.max(1, limit))) do out[i] = tostring(text) end
                return math.min(w, limit), out
            end,
        }
    end
    gfx.newFont = function(path) return face(path) end
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

-- The live campaign stack: kitting, drinking, the reset, the auto switch (Tactics unlocked) and the
-- bell. Five plates is the tallest this column ever stands, and it is what an ordinary fight opens on.
local function phase(column)
    return setmetatable({
        column = column or { x = 16, y = 104, w = 130 },
        placed = { { char = "knight", x = 1, y = 1 } },
        roster = {},
        allowAuto = true,
        autoBattle = false,
        autoSpeed = 1,
        speedSteps = { 1, 2, 3 },
        onLoadout = function() end,
        onPotions = function() end,
        map = { size = 48, cols = 8, rows = 8, cursor = { x = 1, y = 1 } },
    }, DeployPhase)
end

-- A body on the board, at `pools` pools: two is an ordinary swordarm (health + stamina), three is
-- anybody who casts -- and three is what the dropped box was always about.
local function body(pools)
    local char = Character.instantiate("character_knight")
    char.stats.health = { current = 42, max = 42 }
    char.stats.stamina = { current = 13, max = 13 }
    char.stats.mana = pools >= 3 and { current = 12, max = 12 } or { current = 0, max = 0 }
    return { char = char, side = "enemy", statuses = {} }
end

local GROUND = { cell = { type = "ground" } }
-- The desktop board's bounds, as states/battle.lua hands them down: the column is 320 wide, the boxes
-- dock into it at 288, and the host's own ceiling clears the Settings and board-turn plates.
local BOUNDS = { x = 320, w = 658, dockW = 288, dockTop = 104 }

return {
    {
        name = "a caster's readout stands, whatever else has to give way for it",
        fn = function()
            withFonts(function()
                inSpace(1280, 720, function()
                    local p = phase()
                    local unit = body(3)
                    local info = { unit = unit }
                    local plan = p:hoverDock(BOUNDS, GROUND, info)
                    local budget = Scale.HEIGHT - 8 - plan.dockTop
                    local objH = TileTooltip.measure(info, plan.W) + plan.gap
                    assert(objH <= budget, string.format(
                        "the fixture no longer fits the column at all (%d in %d) -- the case this "
                        .. "spec is about has moved", objH, budget))
                    assert(plan.occupant, string.format(
                        "hovering a three-pool body before the bell shows NO readout of it: its %dpx "
                        .. "box was dropped from a %dpx column, on the one screen whose subject is "
                        .. "reading the enemy line", objH, budget))
                end)
            end)
        end,
    },
    {
        name = "an ordinary body and its ground both stand",
        fn = function()
            withFonts(function()
                inSpace(1280, 720, function()
                    local plan = phase():hoverDock(BOUNDS, GROUND, { unit = body(2) })
                    assert(plan.occupant, "the body yielded with room to spare")
                    assert(plan.terrain, "the ground yielded with room to spare")
                end)
            end)
        end,
    },
    {
        name = "an empty tile is all ground",
        fn = function()
            withFonts(function()
                inSpace(1280, 720, function()
                    local plan = phase():hoverDock(BOUNDS, GROUND, nil)
                    assert(plan.terrain, "an empty tile stopped describing its ground")
                    assert(not plan.occupant, "an empty tile is describing an occupant")
                end)
            end)
        end,
    },
    {
        name = "the control stack floors the boxes only in the column it stands in",
        fn = function()
            withFonts(function()
                inSpace(880, 450, function()
                    -- The short space puts the controls in the FAR column (battle's deployControlRect)
                    -- while the boxes stay at dockX. A ceiling read off that stack would throw away
                    -- half of a column the stack is nowhere near.
                    local far = phase({ x = 880 - 302 + 16, y = 16, w = 130 })
                    local near = phase({ x = 16, y = 16, w = 130 })
                    local bounds = { x = 0, w = 250, dockW = 218, dockTop = 104 }
                    assert(far:hoverDock(bounds, GROUND, nil).dockTop == 104,
                        "the docked boxes are clearing a control stack in the other column")
                    assert(near:hoverDock(bounds, GROUND, nil).dockTop > 104,
                        "the docked boxes would ride up over the controls they share a column with")
                end)
            end)
        end,
    },
    {
        name = "a box too tall for its column is not drawn off the bottom of the screen",
        fn = function()
            withFonts(function()
                -- A column with barely a plate's worth of room under the ceiling: nothing tall can
                -- stand in it, and the ground -- which always fits -- is the half that can be read.
                inSpace(1280, 400, function()
                    local p = phase()
                    local plan = p:hoverDock(BOUNDS, GROUND, { unit = body(3) })
                    assert(plan.terrain, "the ground gave way in a column that can only hold the ground")
                    assert(not plan.occupant,
                        "a readout taller than its column is being drawn off the bottom of the screen")
                end)
            end)
        end,
    },
}
