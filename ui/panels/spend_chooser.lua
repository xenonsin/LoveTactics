-- The spend slider: the money twin of the wind-up chooser (ui/panels/windup_chooser.lua). It pops up ON
-- the tile a PURCHASABLE ability (The Gilded Wound) is aimed at, the moment the swing is confirmed there,
-- and lets the caster dial how much GOLD to pour into the blow -- ten gold per point of damage. The blow
-- does not commit until this does: the check commits it at the chosen amount, a click-off / Esc backs out
-- and leaves the aim armed.
--
-- A SLIDER, not a rung ladder. The wind-up chooser draws one rung per tick because a tell is a handful of
-- ticks; a purse can buy a couple of dozen points of damage, and two dozen rungs would not fit over a
-- tile. So the amount rides a short track with a handle, and the read-out carries the two numbers that
-- matter: the gold it will cost (amber) and the damage it buys (ink).
--
-- Three-input + mouse-only by construction: drag the handle or click the track (or scroll) to size it and
-- the check to commit; arrows/+- and Enter on a keyboard; D-pad/bumpers and A on a pad; Esc / B / right-
-- click / click-off cancels. The board and the turn-order strip stay fully visible behind it.
local Theme = require("ui.theme")
local Scale = require("scale")

local SpendChooser = {}
SpendChooser.__index = SpendChooser

local PAD = 8
local READOUT_H = 16
local TRACK_W, TRACK_H = 150, 8
local HANDLE_W, HANDLE_H = 10, 18
local CHECK_W = 24
local GAP = 10 -- between track and the check

-- opts:
--   lo, hi     the damage range the purse can buy (lo >= 1, hi = min(ability max, floor(gold/rate)))
--   value      initial damage (defaults to lo)
--   rate       gold per point of damage (The Gilded Wound: 10)
--   anchorX/Y  the aimed tile's CENTRE in screen space; tileSize its size (to clear the tile)
--   onChange   fn(value) -- called on every slide, so the host can mirror the armed spend
--   onConfirm  fn(value) -- commit the blow at this many points bought
--   onCancel   fn()      -- back out, staying armed
function SpendChooser.new(opts)
    opts = opts or {}
    local self = setmetatable({}, SpendChooser)
    self.lo = math.max(1, opts.lo or 1)
    self.hi = math.max(self.lo, opts.hi or self.lo)
    self.value = math.max(self.lo, math.min(self.hi, opts.value or self.lo))
    self.rate = math.max(1, opts.rate or 10)
    self.onChange = opts.onChange
    self.onConfirm = opts.onConfirm
    self.onCancel = opts.onCancel

    self.font = Theme.body(14)

    self.w = PAD * 2 + TRACK_W + GAP + CHECK_W
    self.h = PAD * 2 + READOUT_H + 6 + HANDLE_H

    -- Anchor above the tile like a tooltip, clamped on-screen; drop below if it would clip the top edge.
    local half = (opts.tileSize or 48) / 2
    local ax, ay = opts.anchorX or Scale.WIDTH / 2, opts.anchorY or Scale.HEIGHT / 2
    self.tailUp = false
    self.x = math.floor(ax - self.w / 2)
    self.y = math.floor(ay - half - self.h - 10)
    if self.y < 8 then
        self.y = math.floor(ay + half + 10)
        self.tailUp = true
    end
    self.x = math.max(8, math.min(Scale.WIDTH - self.w - 8, self.x))
    self.tailX = math.max(self.x + 12, math.min(self.x + self.w - 12, math.floor(ax)))

    self.trackX = self.x + PAD
    self.trackY = self.y + PAD + READOUT_H + 6 + HANDLE_H / 2 - TRACK_H / 2
    self.handleCY = self.trackY + TRACK_H / 2
    self.checkRect = { x = self.trackX + TRACK_W + GAP, y = self.handleCY - HANDLE_H / 2, w = CHECK_W, h = HANDLE_H }

    self.hoverCheck = false
    self.dragging = false
    return self
end

function SpendChooser:gold() return self.value * self.rate end

-- Handle centre x for the current value (or a given one).
function SpendChooser:handleX(v)
    v = v or self.value
    if self.hi == self.lo then return self.trackX + TRACK_W / 2 end
    return self.trackX + (v - self.lo) / (self.hi - self.lo) * TRACK_W
end

-- The value a pixel x maps to on the track, clamped and rounded.
function SpendChooser:valueAt(x)
    if self.hi == self.lo then return self.lo end
    local t = (x - self.trackX) / TRACK_W
    return math.max(self.lo, math.min(self.hi, math.floor(self.lo + t * (self.hi - self.lo) + 0.5)))
end

function SpendChooser:setValue(v)
    v = math.max(self.lo, math.min(self.hi, math.floor(v + 0.5)))
    if v == self.value then return end
    self.value = v
    if self.onChange then self.onChange(self.value) end
end

function SpendChooser:adjust(delta) self:setValue(self.value + delta) end
function SpendChooser:confirm() if self.onConfirm then self.onConfirm(self.value) end end
function SpendChooser:cancel() if self.onCancel then self.onCancel() end end
function SpendChooser:update(dt) end

local function pointIn(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- A small coin: an amber disc with a darker rim, so the gold figure reads as money at a glance.
local function drawCoin(cx, cy, r)
    Theme.set(Theme.accentAmber)
    love.graphics.circle("fill", cx, cy, r)
    Theme.set(Theme.panel)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx, cy, r)
    love.graphics.setLineWidth(1)
end

function SpendChooser:draw()
    Theme.plate(self.x, self.y, self.w, self.h, Theme.R)
    -- The tail pointing at the tile it is pricing.
    Theme.set(Theme.panel)
    local tx = self.tailX
    if self.tailUp then
        love.graphics.polygon("fill", tx - 6, self.y, tx + 6, self.y, tx, self.y - 7)
    else
        love.graphics.polygon("fill", tx - 6, self.y + self.h, tx + 6, self.y + self.h, tx, self.y + self.h + 7)
    end

    -- Read-out: the gold (coin + amount) on the left, the damage it buys on the right.
    love.graphics.setFont(self.font)
    local ry = self.y + PAD
    drawCoin(self.x + PAD + 5, ry + 6, 5)
    Theme.set(Theme.accentAmber)
    love.graphics.print(tostring(self:gold()) .. "g", self.x + PAD + 14, ry - 1)
    Theme.set(Theme.ink)
    love.graphics.printf(tostring(self.value) .. " dmg", self.x, ry - 1, self.w - PAD, "right")

    -- The track.
    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", self.trackX, self.trackY, TRACK_W, TRACK_H, 3, 3)
    -- The filled portion up to the handle, in amber (the coin already spent, visually).
    local hx = self:handleX()
    Theme.set(Theme.accentAmber)
    love.graphics.rectangle("fill", self.trackX, self.trackY, math.max(0, hx - self.trackX), TRACK_H, 3, 3)
    -- The handle.
    Theme.set(self.dragging and Theme.accentAmber or Theme.frame)
    love.graphics.rectangle("fill", hx - HANDLE_W / 2, self.handleCY - HANDLE_H / 2, HANDLE_W, HANDLE_H, 2, 2)
    Theme.set(Theme.ink)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", hx - HANDLE_W / 2, self.handleCY - HANDLE_H / 2, HANDLE_W, HANDLE_H, 2, 2)

    -- The commit check.
    local cr = self.checkRect
    Theme.set(self.hoverCheck and Theme.accentAmber or Theme.frame)
    love.graphics.rectangle("fill", cr.x, cr.y, cr.w, cr.h, 2, 2)
    Theme.set(self.hoverCheck and Theme.slot or Theme.ink)
    love.graphics.setLineWidth(2)
    love.graphics.line(cr.x + 6, cr.y + cr.h / 2, cr.x + cr.w / 2 - 1, cr.y + cr.h - 6)
    love.graphics.line(cr.x + cr.w / 2 - 1, cr.y + cr.h - 6, cr.x + cr.w - 5, cr.y + 6)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1)
end

-- Is a pixel on (or near) the track's grabbable band?
function SpendChooser:onTrack(x, y)
    return x >= self.trackX - HANDLE_W and x <= self.trackX + TRACK_W + HANDLE_W
        and y >= self.trackY - 8 and y <= self.trackY + TRACK_H + 8
end

function SpendChooser:mousemoved(x, y)
    if self.dragging then
        if love.mouse.isDown(1) then
            self:setValue(self:valueAt(x))
        else
            self.dragging = false
        end
    end
    self.hoverCheck = pointIn(self.checkRect, x, y)
end

function SpendChooser:cursorKind(x, y)
    if self:onTrack(x, y) or pointIn(self.checkRect, x, y) then return "hand" end
    return "arrow"
end

function SpendChooser:mousepressed(x, y, button)
    if button == 2 then self:cancel() return end -- right-click backs out
    if button ~= 1 then return end
    if pointIn(self.checkRect, x, y) then self:confirm() return end
    if self:onTrack(x, y) then self:setValue(self:valueAt(x)); self.dragging = true; return end
    -- A click anywhere off the little box backs out (staying armed).
    if x < self.x or x > self.x + self.w or y < self.y or y > self.y + self.h then self:cancel() end
end

function SpendChooser:mousereleased(x, y, button)
    self.dragging = false
end

function SpendChooser:wheelmoved(dx, dy)
    if dy ~= 0 then self:adjust(dy > 0 and 1 or -1) end
end

function SpendChooser:keypressed(key)
    if key == "escape" then self:cancel()
    elseif key == "return" or key == "kpenter" or key == "space" then self:confirm()
    elseif key == "left" or key == "down" or key == "-" or key == "kp-" then self:adjust(-1)
    elseif key == "right" or key == "up" or key == "=" or key == "kp+" then self:adjust(1)
    elseif key == "pageup" then self:adjust(5)
    elseif key == "pagedown" then self:adjust(-5)
    elseif key == "home" then self:setValue(self.lo)
    elseif key == "end" then self:setValue(self.hi)
    end
end

function SpendChooser:gamepadpressed(joystick, button)
    if button == "b" then self:cancel()
    elseif button == "a" then self:confirm()
    elseif button == "dpleft" or button == "dpdown" then self:adjust(-1)
    elseif button == "dpright" or button == "dpup" then self:adjust(1)
    elseif button == "leftshoulder" then self:adjust(-5)
    elseif button == "rightshoulder" then self:adjust(5)
    end
end

return SpendChooser
