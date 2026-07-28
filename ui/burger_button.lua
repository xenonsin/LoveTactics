-- Small clickable "burger" button that opens a screen's system menu.
--
-- The mouse half of a pause menu. Keyboard and gamepad reach the same menu with Esc and Start, but a
-- mouse-only player needs a visible target -- the project standard is that every screen is fully
-- playable with the mouse alone, and "press Escape" is not a mouse affordance.
--
--   local btn = BurgerButton.new(x, y)          -- top-left corner of the button
--   btn:draw()
--   btn:mousemoved(x, y)
--   if btn:mousepressed(x, y, button) then openMenu() end
--
-- `mousepressed` returns true when the click landed on it, so the caller decides what opening means.
-- Deliberately the same shape as ui/close_button.lua: the two are a pair (one opens the modal, one
-- shuts it), and a second widget with a different contract would be one more thing to remember.

local Theme = require("ui.theme")

local BurgerButton = {}
BurgerButton.__index = BurgerButton

local SIZE = 34
local BAR_INSET = 9    -- from the button's left/right edge to the bars
local BAR_H = 3
local BAR_GAP = 6

-- Anchored by its own top-left corner rather than to a box, since this one sits on the screen rather
-- than inside a panel.
function BurgerButton.new(x, y)
    local self = setmetatable({}, BurgerButton)
    self.x, self.y = x, y
    self.w, self.h = SIZE, SIZE
    self.hovered = false
    return self
end

function BurgerButton:contains(px, py)
    return px >= self.x and px <= self.x + self.w
        and py >= self.y and py <= self.y + self.h
end

function BurgerButton:draw()
    -- Sits over a painted city, so it carries its own slightly translucent plate rather than trusting
    -- the background behind it to be dark enough for the bars to read.
    Theme.set(self.hovered and Theme.panel or Theme.panel2, self.hovered and 0.95 or 0.85)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, Theme.R, Theme.R)
    Theme.set(self.hovered and Theme.accentAmber or Theme.frame)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, Theme.R, Theme.R)

    -- Three bars, drawn as rectangles so the glyph needs no font.
    Theme.set(self.hovered and Theme.accentAmber or Theme.ink)
    local barW = self.w - BAR_INSET * 2
    local stack = BAR_H * 3 + BAR_GAP * 2
    local top = self.y + (self.h - stack) / 2
    for i = 0, 2 do
        love.graphics.rectangle("fill", self.x + BAR_INSET, top + i * (BAR_H + BAR_GAP),
            barW, BAR_H, 1, 1)
    end

    love.graphics.setColor(1, 1, 1)
end

function BurgerButton:mousemoved(x, y)
    self.hovered = self:contains(x, y)
end

-- Returns true if the click landed on the button.
function BurgerButton:mousepressed(x, y, button)
    return button == 1 and self:contains(x, y)
end

return BurgerButton
