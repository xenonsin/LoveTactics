-- Small clickable "X" close button for modal pop-up panels.
--
-- Modals are dismissable by keyboard (Esc) and gamepad (B), but a mouse-only
-- player needs a visible click target too. Panels place one of these in their
-- top-right corner and forward mouse events to it:
--
--   local btn = CloseButton.new(boxRight, boxTop)   -- anchored to a box corner
--   btn:draw()
--   btn:mousemoved(x, y)
--   if btn:mousepressed(x, y, button) then panel:close() end
--
-- `mousepressed` returns true when the click landed on the button, so the caller
-- can decide what closing means.

local CloseButton = {}
CloseButton.__index = CloseButton

local SIZE = 28
local MARGIN = 10   -- inset from the box's top-right corner

-- Anchor at the box's top-right corner (boxRight, boxTop). The button sits just
-- inside that corner.
function CloseButton.new(boxRight, boxTop)
    local self = setmetatable({}, CloseButton)
    self.x = boxRight - SIZE - MARGIN
    self.y = boxTop + MARGIN
    self.w = SIZE
    self.h = SIZE
    self.hovered = false
    return self
end

function CloseButton:contains(px, py)
    return px >= self.x and px <= self.x + self.w
        and py >= self.y and py <= self.y + self.h
end

function CloseButton:draw()
    if self.hovered then
        love.graphics.setColor(0.6, 0.25, 0.28)
    else
        love.graphics.setColor(0.25, 0.20, 0.24)
    end
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 6, 6)
    love.graphics.setColor(0.7, 0.55, 0.6)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 6, 6)

    -- The "X" glyph, drawn as two crossing lines so it needs no font.
    love.graphics.setColor(0.95, 0.9, 0.9)
    love.graphics.setLineWidth(2)
    local pad = 8
    love.graphics.line(self.x + pad, self.y + pad,
        self.x + self.w - pad, self.y + self.h - pad)
    love.graphics.line(self.x + self.w - pad, self.y + pad,
        self.x + pad, self.y + self.h - pad)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1)
end

function CloseButton:mousemoved(x, y)
    self.hovered = self:contains(x, y)
end

-- Returns true if the click landed on the button.
function CloseButton:mousepressed(x, y, button)
    return button == 1 and self:contains(x, y)
end

return CloseButton
