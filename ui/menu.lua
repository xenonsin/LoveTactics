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

local Scale = require("scale")

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

    -- Scrolling. `maxVisible` caps how many rows are drawn at once; the rest scroll past.
    -- nil (the default) means "show everything", which is what a short fixed menu wants.
    self.maxVisible = opts.maxVisible
    self.scroll = 0 -- index of the row above the first visible one
    return self
end

-- How many rows are on screen at once.
function Menu:visibleCount()
    if not self.maxVisible then return #self.items end
    return math.min(self.maxVisible, #self.items)
end

function Menu:canScroll()
    return self.maxVisible ~= nil and #self.items > self.maxVisible
end

-- Clamp the scroll window, then slide it just far enough to keep `selected` inside it. The
-- selection leads and the window follows -- never the other way round.
function Menu:scrollToSelection()
    if not self:canScroll() then
        self.scroll = 0
        return
    end
    local maxScroll = #self.items - self.maxVisible
    if self.selected <= self.scroll then
        self.scroll = self.selected - 1
    elseif self.selected > self.scroll + self.maxVisible then
        self.scroll = self.selected - self.maxVisible
    end
    self.scroll = math.max(0, math.min(maxScroll, self.scroll))
end

-- Scroll by `delta` rows without moving the selection (the mouse wheel).
function Menu:scrollBy(delta)
    if not self:canScroll() then return end
    local maxScroll = #self.items - self.maxVisible
    self.scroll = math.max(0, math.min(maxScroll, self.scroll + delta))
end

-- Is this row currently inside the scroll window?
function Menu:isVisible(index)
    return index > self.scroll and index <= self.scroll + self:visibleCount()
end

-- Recompute button rectangles, centered horizontally. Rows outside the scroll window get no
-- rect at all (`x = nil`), which takes them out of hit-testing and drawing for free.
function Menu:layout()
    local screenW = Scale.WIDTH
    local screenH = Scale.HEIGHT
    local shown = self:visibleCount()
    local totalH = shown * self.buttonHeight + (shown - 1) * self.spacing
    local startY = self.startY or (screenH / 2 - totalH / 2)
    local centerX = self.centerX or (screenW / 2)

    for i, item in ipairs(self.items) do
        if self:isVisible(i) then
            local row = i - self.scroll - 1
            item.x = centerX - self.buttonWidth / 2
            item.y = startY + row * (self.buttonHeight + self.spacing)
            item.w = self.buttonWidth
            item.h = self.buttonHeight
        else
            item.x, item.y = nil, nil
        end
    end
end

local function isInside(item, px, py)
    return item.x and px >= item.x and px <= item.x + item.w
        and py >= item.y and py <= item.y + item.h
end

-- Move the selection by delta, wrapping around the ends, dragging the scroll window along.
function Menu:moveSelection(delta)
    local count = #self.items
    if count == 0 then return end
    self.selected = (self.selected - 1 + delta) % count + 1
    self:scrollToSelection()
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

-- A caret above / below the list when there are rows scrolled out of sight, so the list never
-- silently hides its own contents.
function Menu:drawScrollHints()
    if not self:canScroll() then return end
    local first = self.items[self.scroll + 1]
    local last = self.items[self.scroll + self:visibleCount()]
    if not (first and first.x and last and last.x) then return end

    local cx = first.x + first.w / 2
    love.graphics.setColor(0.5, 0.55, 0.7)
    if self.scroll > 0 then
        love.graphics.polygon("fill", cx - 7, first.y - 8, cx + 7, first.y - 8, cx, first.y - 16)
    end
    if self.scroll + self:visibleCount() < #self.items then
        local by = last.y + last.h
        love.graphics.polygon("fill", cx - 7, by + 8, cx + 7, by + 8, cx, by + 16)
    end
end

function Menu:draw()
    love.graphics.setFont(self.font)
    for i, item in ipairs(self.items) do
        if item.x then
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
            local th = self.font:getHeight()
            love.graphics.printf(item.label, item.x, item.y + item.h / 2 - th / 2, item.w, "center")
        end
    end
    self:drawScrollHints()
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

-- True when the point is over any visible menu item, so a state can show the hand cursor there.
function Menu:mouseOverItem(x, y)
    for _, item in ipairs(self.items) do
        if isInside(item, x, y) then return true end
    end
    return false
end

-- Wheel scrolls the window without moving the selection, the way a list is expected to behave.
function Menu:wheelmoved(dx, dy)
    self:scrollBy(-dy)
end

function Menu:keypressed(key)
    if key == "up" or key == "w" then
        self:moveSelection(-1)
    elseif key == "down" or key == "s" then
        self:moveSelection(1)
    elseif key == "pageup" then
        self:moveSelection(-self:visibleCount())
    elseif key == "pagedown" then
        self:moveSelection(self:visibleCount())
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
