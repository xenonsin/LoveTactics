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
-- A row may also carry a `value` -- a string, or a function returning one -- which turns it from a
-- button into a SETTING: the label sits left, the value right, and left/right (or the d-pad's
-- horizontal axis) work it as well as Enter does. `adjust(dir)` handles a row with more than two
-- states; without one, both directions just run `action`, which is all a toggle needs. The value is
-- read at draw time rather than baked into the label, so flipping a preference needs no rebuild.
-- states/settings.lua is the whole of it in practice.
--
--   -- in your state:
--   menu:update(dt)
--   menu:draw()
--   menu:mousemoved(x, y)
--   menu:mousepressed(x, y, button)
--   menu:keypressed(key)
--   menu:gamepadpressed(joystick, button)

local Scale = require("scale")
local Sound = require("models.sound")
local Theme = require("ui.theme")

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

local VALUE_PAD = 18 -- inset of a setting row's label and value from its button border

-- A setting row that carries `sliderFraction`/`sliderSet` draws as a SLIDER: a thin track along the
-- bottom of the row whose fill shows the level, and a click anywhere on it sets that level. This is
-- what lets a mouse LOWER a volume -- clicking a position -- rather than only nudging it up by
-- activating the row. Both the draw and the hit-test read the track from here so they cannot drift.
local SLIDER_H = 4
local function sliderTrack(item)
    return item.x + VALUE_PAD, item.y + item.h - 9, item.w - VALUE_PAD * 2, SLIDER_H
end

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
    self.font = opts.font or Theme.display(24)
    self.axisThreshold = opts.axisThreshold or DEFAULTS.axisThreshold
    self.axisActive = false  -- edge detection so a held stick moves one step

    -- A screen showing two menus side by side (the main menu and its debug column) must show only
    -- ONE highlighted row, or neither reads as the thing Enter will press. Unfocused menus keep
    -- their selection but draw it flat; `setFocused` moves the highlight between them.
    self.focused = true

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
--
-- The blip is fired here rather than at each of the five input paths that move a selection (arrows,
-- WASD, the analog stick, a gamepad d-pad, the mouse crossing a new row), so keyboard and pad and
-- mouse cannot drift apart on which movements are audible. Silent until the file exists; see
-- models/sound.lua.
function Menu:moveSelection(delta)
    local count = #self.items
    if count == 0 then return end
    local before = self.selected
    self.selected = (self.selected - 1 + delta) % count + 1
    self:scrollToSelection()
    if self.selected ~= before then Sound.play("ui.move") end
end

function Menu:setFocused(focused)
    self.focused = focused and true or false
end

-- The row currently under the highlight, so a screen can draw whatever belongs beside the list --
-- the settings screen's description of the option being looked at.
function Menu:selectedItem()
    return self.items[self.selected]
end

-- A row's current value as a string, or nil when it is a plain button. Read fresh every frame: a
-- setting row's value is a live reading of the preference, not a copy taken when the menu was built.
function Menu.valueOf(item)
    local value = item and item.value
    if type(value) == "function" then value = value(item) end
    if value == nil then return nil end
    return tostring(value)
end

function Menu:activate()
    local item = self.items[self.selected]
    if not (item and item.action) then return end
    -- A row with an `adjust` fires its own sound as it steps (the volume sliders play into the level
    -- they are setting), so it is not given the generic confirm on top of that.
    if not item.adjust then Sound.play("ui.confirm") end
    item.action()
end

-- Work the selected row sideways: `adjust` for a row with several states, else `action`, which is
-- everything a two-state toggle needs. A plain button ignores both directions rather than firing --
-- pressing left on "Exit To Desktop" must not exit.
function Menu:adjustSelection(dir)
    local item = self.items[self.selected]
    if not item then return end
    if item.adjust then
        item.adjust(dir)
    elseif Menu.valueOf(item) and item.action then
        item.action()
    end
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
    Theme.set(Theme.muted)
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
            local active = (i == self.selected) and self.focused

            -- Selected row: raised (lighter) plate + bone-gold border + gold label; unselected: an
            -- inset plate with the frame trim and ink label.
            Theme.set(active and Theme.panel or Theme.panel2)
            love.graphics.rectangle("fill", item.x, item.y, item.w, item.h, Theme.R, Theme.R)
            love.graphics.setLineWidth(active and 1.5 or 1)
            Theme.set(active and Theme.accentAmber or Theme.frame)
            love.graphics.rectangle("line", item.x, item.y, item.w, item.h, Theme.R, Theme.R)
            love.graphics.setLineWidth(1)

            -- A slider row draws its level as a filled track along the bottom edge, so the value the
            -- number states is also shown as a position the mouse can click to.
            if item.sliderFraction then
                local tx, ty2, tw, th2 = sliderTrack(item)
                local frac = math.max(0, math.min(1, item.sliderFraction() or 0))
                Theme.set(Theme.frame, 0.6)
                love.graphics.rectangle("fill", tx, ty2, tw, th2, th2 / 2, th2 / 2)
                Theme.set(Theme.accentAmber)
                love.graphics.rectangle("fill", tx, ty2, tw * frac, th2, th2 / 2, th2 / 2)
            end

            Theme.set(active and Theme.accentAmber or Theme.ink)
            local th = self.font:getHeight()
            local ty = item.y + item.h / 2 - th / 2
            local value = Menu.valueOf(item)
            if value then
                -- A setting row: label left, value right, both inset from the border. Centering the
                -- label would put every row's text in a different place relative to its value, and a
                -- column of settings is read by scanning that value column.
                love.graphics.printf(item.label, item.x + VALUE_PAD, ty, item.w - VALUE_PAD * 2, "left")
                Theme.set(Theme.accentAmber)
                love.graphics.printf(value, item.x + VALUE_PAD, ty, item.w - VALUE_PAD * 2, "right")
            else
                love.graphics.printf(item.label, item.x, ty, item.w, "center")
            end
        end
    end
    self:drawScrollHints()
    love.graphics.setColor(1, 1, 1)
end

-- Mouse hover updates the selection so all three input methods stay in sync, and sounds the SAME
-- cursor-move cue keyboard/pad navigation does when it lands on a NEW row -- so hovering a button is
-- audible without the two input paths drifting on which movements make a sound. Silent while the
-- pointer sits still on a row (the selection only changes on a crossing) and off the list entirely.
function Menu:mousemoved(x, y)
    for i, item in ipairs(self.items) do
        if isInside(item, x, y) then
            if self.selected ~= i then
                self.selected = i
                Sound.play("ui.move")
            end
            return
        end
    end
end

function Menu:mousepressed(x, y, button)
    if button ~= 1 then return end
    for i, item in ipairs(self.items) do
        if isInside(item, x, y) then
            self.selected = i
            -- A slider row is SET by the click position (so the mouse can go down as well as up); a
            -- plain row or toggle is activated as before.
            if item.sliderSet then
                local tx, _, tw = sliderTrack(item)
                item.sliderSet((x - tx) / tw)
            else
                self:activate()
            end
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
    elseif key == "left" or key == "a" then
        self:adjustSelection(-1)
    elseif key == "right" or key == "d" then
        self:adjustSelection(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:activate()
    end
end

function Menu:gamepadpressed(joystick, button)
    if button == "dpup" then
        self:moveSelection(-1)
    elseif button == "dpdown" then
        self:moveSelection(1)
    elseif button == "dpleft" then
        self:adjustSelection(-1)
    elseif button == "dpright" then
        self:adjustSelection(1)
    elseif button == "a" or button == "start" then
        self:activate()
    end
end

return Menu
