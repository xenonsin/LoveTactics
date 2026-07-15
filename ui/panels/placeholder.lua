-- Generic "coming soon" pop-up panel, used by buildings whose real UI isn't
-- built yet. Panels are modal overlays owned by a state: the state forwards
-- input while one is open and calls the panel's own close path (escape /
-- gamepad B) which invokes `onClose`.
--
--   local panel = Placeholder.new({ title = "Blacksmith", onClose = fn })
--   panel:update(dt); panel:draw()
--   panel:mousepressed(x, y, button); panel:keypressed(key)
--   panel:gamepadpressed(joystick, button)

local CloseButton = require("ui.close_button")
local Scale = require("scale")
local InputMode = require("input_mode")

local Placeholder = {}
Placeholder.__index = Placeholder

local BOX_W, BOX_H = 460, 220

function Placeholder.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Placeholder)
    self.title = opts.title or "Building"
    self.onClose = opts.onClose
    self.titleFont = love.graphics.newFont(32)
    self.bodyFont = love.graphics.newFont(18)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

function Placeholder:close()
    if self.onClose then self.onClose() end
end

function Placeholder:update(dt) end

function Placeholder:draw()
    -- Dim the city behind the panel.
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(self.title, self.boxX, self.boxY + 40, BOX_W, "center")

    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.85, 0.85, 0.9)
    love.graphics.printf("Coming soon.", self.boxX, self.boxY + 110, BOX_W, "center")
    love.graphics.setColor(0.55, 0.6, 0.7)
    -- Show the glyph for the device last used: pad button only in gamepad mode, keyboard/mouse otherwise.
    local hint = InputMode.isGamepad() and "B to close" or "Click X, or Esc to close"
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 40, BOX_W, "center")

    self.closeButton:draw()

    love.graphics.setColor(1, 1, 1)
end

local function isInsideBox(self, x, y)
    return x >= self.boxX and x <= self.boxX + BOX_W
        and y >= self.boxY and y <= self.boxY + BOX_H
end

function Placeholder:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
end

-- Hand over the one button this panel has (the close X); arrow over the rest. See ui/cursor.lua.
function Placeholder:cursorKind(x, y)
    return self.closeButton:contains(x, y) and "hand" or "arrow"
end

function Placeholder:mousepressed(x, y, button)
    if button ~= 1 then return end
    -- The close button, or any click outside the panel box, dismisses the modal.
    if self.closeButton:mousepressed(x, y, button) or not isInsideBox(self, x, y) then
        self:close()
    end
end

function Placeholder:keypressed(key)
    if key == "escape" then self:close() end
end

function Placeholder:gamepadpressed(joystick, button)
    if button == "b" then self:close() end
end

return Placeholder
