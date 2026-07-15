-- Small modal "how many?" picker: choose an integer in [1, max] and confirm, or cancel. Used by
-- ui/panels/loadout.lua when a stash consumable holds more than one and the player drags/places it
-- onto a character, so they can split off part of the stack rather than moving the whole thing.
--
-- Self-contained and stateless about what it moves: it just reports a chosen count. The host owns
-- the popup reference and clears it in the callbacks (this widget never dismisses itself).
--
-- Follows the project's three-input standard and is fully mouse-only playable: click the -/+ steppers
-- or drag the slider, click Move / Cancel / the X (mouse); Left/Right (or Up/Down) adjust, Enter
-- confirms, Esc cancels (keyboard); D-pad adjusts, A confirms, B cancels (gamepad). The wheel nudges
-- the value while the pointer is anywhere over the box.
--
--   local popup = QuantityPopup.new({
--       max = stack.quantity, value = stack.quantity, title = "Move how many?", label = item.name,
--       onConfirm = function(n) ... end, onCancel = function() ... end,
--   })

local CloseButton = require("ui.close_button")
local Scale = require("scale")

local QuantityPopup = {}
QuantityPopup.__index = QuantityPopup

local BOX_W, BOX_H = 340, 210

local function pointIn(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function QuantityPopup.new(opts)
    opts = opts or {}
    local self = setmetatable({}, QuantityPopup)
    self.max = math.max(1, opts.max or 1)
    self.value = math.max(1, math.min(self.max, opts.value or self.max))
    self.title = opts.title or "How many?"
    self.label = opts.label
    self.onConfirm = opts.onConfirm
    self.onCancel = opts.onCancel

    self.titleFont = love.graphics.newFont(20)
    self.labelFont = love.graphics.newFont(14)
    self.valueFont = love.graphics.newFont(34)
    self.btnFont = love.graphics.newFont(16)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    local rowY = self.boxY + 116
    self.minusBtn = { x = self.boxX + 24, y = rowY, w = 34, h = 30 }
    self.plusBtn = { x = self.boxX + BOX_W - 58, y = rowY, w = 34, h = 30 }
    local trackX = self.minusBtn.x + self.minusBtn.w + 12
    self.track = { x = trackX, y = rowY + 10, w = self.plusBtn.x - trackX - 12, h = 10 }

    local btnW = (BOX_W - 56) / 2
    local btnY = self.boxY + BOX_H - 48
    self.confirmBtn = { x = self.boxX + 24, y = btnY, w = btnW, h = 34 }
    self.cancelBtn = { x = self.confirmBtn.x + btnW + 8, y = btnY, w = btnW, h = 34 }

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    self.hover = nil     -- which button the mouse is over (for highlight)
    self.dragging = false -- dragging the slider thumb
    return self
end

function QuantityPopup:setValue(v)
    self.value = math.max(1, math.min(self.max, math.floor(v + 0.5)))
end

function QuantityPopup:adjust(delta)
    self:setValue(self.value + delta)
end

function QuantityPopup:confirm()
    if self.onConfirm then self.onConfirm(self.value) end
end

function QuantityPopup:cancel()
    if self.onCancel then self.onCancel() end
end

-- Map a pixel x on the slider track to a value in [1, max].
function QuantityPopup:valueAt(px)
    local t = (px - self.track.x) / self.track.w
    t = math.max(0, math.min(1, t))
    self:setValue(1 + t * (self.max - 1))
end

function QuantityPopup:update() end

function QuantityPopup:draw()
    -- Dim behind this nested modal (the loadout panel stays visible underneath).
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setColor(0.14, 0.15, 0.21)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(self.title, self.boxX, self.boxY + 16, BOX_W, "center")

    if self.label then
        love.graphics.setFont(self.labelFont)
        love.graphics.setColor(0.75, 0.78, 0.86)
        love.graphics.printf(self.label, self.boxX, self.boxY + 46, BOX_W, "center")
    end

    -- The chosen count, big and centered, with the max for context.
    love.graphics.setFont(self.valueFont)
    love.graphics.setColor(0.95, 0.95, 0.97)
    love.graphics.printf(self.value .. " / " .. self.max, self.boxX, self.boxY + 66, BOX_W, "center")

    self:drawStepper(self.minusBtn, "-")
    self:drawStepper(self.plusBtn, "+")

    -- Slider: a filled portion up to value, on a dim track.
    love.graphics.setColor(0.22, 0.24, 0.32)
    love.graphics.rectangle("fill", self.track.x, self.track.y, self.track.w, self.track.h, 5, 5)
    local t = (self.max > 1) and (self.value - 1) / (self.max - 1) or 1
    love.graphics.setColor(0.55, 0.7, 0.95)
    love.graphics.rectangle("fill", self.track.x, self.track.y, self.track.w * t, self.track.h, 5, 5)
    -- Thumb.
    local tx = self.track.x + self.track.w * t
    love.graphics.setColor(0.9, 0.92, 0.98)
    love.graphics.circle("fill", tx, self.track.y + self.track.h / 2, 8)

    self:drawButton(self.confirmBtn, "Move", { 0.30, 0.55, 0.32 }, { 0.45, 0.75, 0.48 })
    self:drawButton(self.cancelBtn, "Cancel", { 0.30, 0.24, 0.28 }, { 0.6, 0.5, 0.55 })

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

function QuantityPopup:drawStepper(r, glyph)
    local hot = self.hover == r
    love.graphics.setColor(hot and 0.30 or 0.22, hot and 0.34 or 0.24, hot and 0.44 or 0.32)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
    love.graphics.setColor(0.6, 0.65, 0.78)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.95, 0.97)
    love.graphics.printf(glyph, r.x, r.y + 3, r.w, "center")
end

function QuantityPopup:drawButton(r, text, fill, border)
    local hot = self.hover == r
    local f = hot and 1.25 or 1
    love.graphics.setColor(fill[1] * f, fill[2] * f, fill[3] * f)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
    love.graphics.setColor(border[1], border[2], border[3])
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
    love.graphics.setFont(self.btnFont)
    love.graphics.setColor(0.97, 0.97, 0.98)
    love.graphics.printf(text, r.x, r.y + r.h / 2 - 10, r.w, "center")
end

function QuantityPopup:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    self.hover = nil
    for _, r in ipairs({ self.minusBtn, self.plusBtn, self.confirmBtn, self.cancelBtn }) do
        if pointIn(r, x, y) then self.hover = r break end
    end
    if self.dragging then self:valueAt(x) end
end

-- Hand over any of the popup's controls (close X, -, +, confirm, cancel, or the draggable track);
-- arrow over the rest of the box. See ui/cursor.lua.
function QuantityPopup:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    for _, r in ipairs({ self.minusBtn, self.plusBtn, self.confirmBtn, self.cancelBtn }) do
        if pointIn(r, x, y) then return "hand" end
    end
    local track = { x = self.track.x - 8, y = self.track.y - 10, w = self.track.w + 16, h = self.track.h + 20 }
    return pointIn(track, x, y) and "hand" or "arrow"
end

function QuantityPopup:mousepressed(x, y, button)
    if button ~= 1 then return true end
    if self.closeButton:mousepressed(x, y, button) then self:cancel() return true end
    if pointIn(self.minusBtn, x, y) then self:adjust(-1) return true end
    if pointIn(self.plusBtn, x, y) then self:adjust(1) return true end
    if pointIn(self.confirmBtn, x, y) then self:confirm() return true end
    if pointIn(self.cancelBtn, x, y) then self:cancel() return true end
    -- A grab on (or near) the track starts a drag and jumps the value to the pointer.
    local hit = { x = self.track.x - 8, y = self.track.y - 10, w = self.track.w + 16, h = self.track.h + 20 }
    if pointIn(hit, x, y) then
        self.dragging = true
        self:valueAt(x)
        return true
    end
    -- Clicking outside the box cancels (matches the other modals' click-away dismiss).
    if not pointIn({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then
        self:cancel()
    end
    return true -- always swallow: this popup is modal over the panel beneath it
end

function QuantityPopup:mousereleased()
    self.dragging = false
end

function QuantityPopup:wheelmoved(dy)
    if dy ~= 0 then self:adjust(dy > 0 and 1 or -1) end
end

function QuantityPopup:keypressed(key)
    if key == "left" or key == "a" or key == "down" or key == "s" then
        self:adjust(-1)
    elseif key == "right" or key == "d" or key == "up" or key == "w" then
        self:adjust(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:confirm()
    elseif key == "escape" then
        self:cancel()
    elseif key:match("^[0-9]$") then
        -- Direct set for the common small counts; ignored when out of range.
        local n = tonumber(key)
        if n >= 1 and n <= self.max then self:setValue(n) end
    end
end

function QuantityPopup:gamepadpressed(_, button)
    if button == "dpleft" or button == "dpdown" then
        self:adjust(-1)
    elseif button == "dpright" or button == "dpup" then
        self:adjust(1)
    elseif button == "a" then
        self:confirm()
    elseif button == "b" then
        self:cancel()
    end
end

return QuantityPopup
