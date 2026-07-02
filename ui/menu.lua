-- Reusable vertical menu widget.
--
-- Handles mouse, keyboard, and gamepad navigation so every UI screen gets all
-- three input methods for free. Construct with a list of items and forward the
-- relevant LÖVE callbacks to it:
--
--   local Menu = require("ui.menu")
--   local menu = Menu.new({
--       { label = "Start Game", action = function() ... end },
--       { label = "Exit",       action = function() love.event.quit() end },
--   })
--
--   -- in your state:
--   menu:update(dt)
--   menu:draw()
--   menu:mousemoved(x, y)
--   menu:mousepressed(x, y, button)
--   menu:keypressed(key)
--   menu:gamepadpressed(joystick, button)

local Menu = {}
Menu.__index = Menu

local DEFAULTS = {
    buttonWidth = 260,
    buttonHeight = 60,
    spacing = 24,
    startY = nil,           -- nil = vertically centered
    centerX = nil,          -- nil = horizontally centered on the window
    axisThreshold = 0.5,    -- analog stick deflection needed to register a move
}

function Menu.new(items, opts)
    opts = opts or {}
    local self = setmetatable({}, Menu)
    self.items = items
    self.selected = 1
    self.buttonWidth = opts.buttonWidth or DEFAULTS.buttonWidth
    self.buttonHeight = opts.buttonHeight or DEFAULTS.buttonHeight
    self.spacing = opts.spacing or DEFAULTS.spacing
    self.startY = opts.startY
    self.centerX = opts.centerX
    self.font = opts.font or love.graphics.newFont(24)
    self.axisThreshold = opts.axisThreshold or DEFAULTS.axisThreshold
    self.axisActive = false  -- edge detection so a held stick moves one step
    return self
end

-- Recompute button rectangles, centered horizontally.
function Menu:layout()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local count = #self.items
    local totalH = count * self.buttonHeight + (count - 1) * self.spacing
    local startY = self.startY or (screenH / 2 - totalH / 2)
    local centerX = self.centerX or (screenW / 2)

    for i, item in ipairs(self.items) do
        item.x = centerX - self.buttonWidth / 2
        item.y = startY + (i - 1) * (self.buttonHeight + self.spacing)
        item.w = self.buttonWidth
        item.h = self.buttonHeight
    end
end

local function isInside(item, px, py)
    return item.x and px >= item.x and px <= item.x + item.w
        and py >= item.y and py <= item.y + item.h
end

-- Move the selection by delta, wrapping around the ends.
function Menu:moveSelection(delta)
    local count = #self.items
    self.selected = (self.selected - 1 + delta) % count + 1
end

function Menu:activate()
    local item = self.items[self.selected]
    if item and item.action then item.action() end
end

function Menu:update(dt)
    self:layout()

    -- Analog stick navigation (left stick Y), with edge detection so holding
    -- the stick advances one item per push rather than racing through them.
    local moved = false
    for _, joystick in ipairs(love.joystick.getJoysticks()) do
        if joystick:isGamepad() then
            local y = joystick:getGamepadAxis("lefty")
            if y <= -self.axisThreshold then
                if not self.axisActive then self:moveSelection(-1) end
                moved = true
            elseif y >= self.axisThreshold then
                if not self.axisActive then self:moveSelection(1) end
                moved = true
            end
        end
    end
    self.axisActive = moved
end

function Menu:draw()
    love.graphics.setFont(self.font)
    for i, item in ipairs(self.items) do
        local active = (i == self.selected)

        if active then
            love.graphics.setColor(0.35, 0.40, 0.55)
        else
            love.graphics.setColor(0.20, 0.23, 0.32)
        end
        love.graphics.rectangle("fill", item.x, item.y, item.w, item.h, 8, 8)

        if active then
            love.graphics.setColor(0.95, 0.85, 0.55)
        else
            love.graphics.setColor(0.5, 0.55, 0.7)
        end
        love.graphics.rectangle("line", item.x, item.y, item.w, item.h, 8, 8)

        love.graphics.setColor(0.95, 0.95, 0.95)
        love.graphics.printf(item.label, item.x, item.y + item.h / 2 - 14, item.w, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

-- Mouse hover updates the selection so all three input methods stay in sync.
function Menu:mousemoved(x, y)
    for i, item in ipairs(self.items) do
        if isInside(item, x, y) then
            self.selected = i
            return
        end
    end
end

function Menu:mousepressed(x, y, button)
    if button ~= 1 then return end
    for i, item in ipairs(self.items) do
        if isInside(item, x, y) then
            self.selected = i
            self:activate()
            return
        end
    end
end

function Menu:keypressed(key)
    if key == "up" or key == "w" then
        self:moveSelection(-1)
    elseif key == "down" or key == "s" then
        self:moveSelection(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:activate()
    end
end

function Menu:gamepadpressed(joystick, button)
    if button == "dpup" then
        self:moveSelection(-1)
    elseif button == "dpdown" then
        self:moveSelection(1)
    elseif button == "a" or button == "start" then
        self:activate()
    end
end

return Menu
