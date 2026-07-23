-- The rest payoff, made visible. "A Moment's Rest" refills every resource on the roster
-- (Player.restore), but a silent refill teaches the player nothing about what a rest tile IS.
-- So the restore is banked UP FRONT (states/game.lua, before this opens) and this panel replays
-- it: each party member's HP bar animates from the wound they walked in with up to full, so the
-- one thing a rest does reads at a glance.
--
-- The bar values are DISPLAY-ONLY -- the live stats are already at max when this opens, so the
-- panel carries its own `from` snapshot and lerps from it. Dismissing early (close X, Continue,
-- Esc, gamepad B) can never cost the heal because the heal already happened; it only snaps the
-- bars to where they were always going. Mouse + keyboard + gamepad, and a clickable close for the
-- mouse-only player (ui/close_button.lua), like every other modal.
--
--   local panel = Rest.new({
--       entries = { { char = c, from = 12, max = 40 }, ... },  -- per party member, pre-rest HP
--       onDone  = function() ... end,                          -- Continue / close / Esc / B
--   })

local CloseButton = require("ui.close_button")
local Scale = require("scale")

local Rest = {}
Rest.__index = Rest

local BOX_W = 540
local ROW_H = 56
local HEADER_H = 96
local FOOTER_H = 74
local PORTRAIT = 40
local BAR_H = 16

-- How long the bars take to sweep to full, and the ease that makes the fill decelerate into place
-- (a linear crawl reads as a progress bar, not as mending). Cubic ease-out.
local FILL_TIME = 0.9
local function easeOut(t) local u = 1 - t return 1 - u * u * u end

function Rest.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Rest)
    self.entries = opts.entries or {}
    self.onDone = opts.onDone
    self.t = 0

    self.titleFont = love.graphics.newFont(28)
    self.bodyFont = love.graphics.newFont(16)
    self.smallFont = love.graphics.newFont(13)

    local rows = math.max(1, #self.entries)
    self.boxW = BOX_W
    self.boxH = HEADER_H + rows * ROW_H + FOOTER_H
    self.boxX = Scale.WIDTH / 2 - self.boxW / 2
    self.boxY = Scale.HEIGHT / 2 - self.boxH / 2

    self.closeButton = CloseButton.new(self.boxX + self.boxW, self.boxY)
    self.button = {
        x = self.boxX + self.boxW / 2 - 90,
        y = self.boxY + self.boxH - 56,
        w = 180,
        h = 40,
        hovered = false,
    }
    return self
end

-- Fraction of the fill animation elapsed (0 at open, 1 once the bars are full). Held separate from
-- `t` so a dismiss can force it to 1 and snap every bar home in one place.
function Rest:progress()
    return easeOut(math.min(1, self.t / FILL_TIME))
end

function Rest:done()
    if self.onDone then self.onDone() end
end

function Rest:update(dt)
    if self.t < FILL_TIME then self.t = self.t + dt end
end

local function drawPortrait(char, x, y, size)
    local sprite = char and char.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(size / sw, size / sh)
        love.graphics.draw(sprite, x + size / 2, y + size / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        love.graphics.setColor(0.3, 0.32, 0.4)
        love.graphics.rectangle("fill", x, y, size, size, 5, 5)
        love.graphics.setColor(0.9, 0.9, 0.95)
        love.graphics.printf(((char and char.name) or "?"):sub(1, 1), x, y + size / 2 - 10, size, "center")
    end
end

function Rest:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", self.boxX, self.boxY, self.boxW, self.boxH, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, self.boxW, self.boxH, 10, 10)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("A Moment's Rest", self.boxX, self.boxY + 22, self.boxW, "center")
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.72, 0.76, 0.84)
    love.graphics.printf("The party makes camp -- wounds mend and reserves return.",
        self.boxX + 30, self.boxY + 58, self.boxW - 60, "center")

    local p = self:progress()
    local rowY = self.boxY + HEADER_H
    for _, e in ipairs(self.entries) do
        self:drawRow(e, rowY, p)
        rowY = rowY + ROW_H
    end

    -- Continue button.
    local b = self.button
    love.graphics.setColor(b.hovered and 0.28 or 0.20, b.hovered and 0.38 or 0.26, b.hovered and 0.30 or 0.24)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6, 6)
    love.graphics.setColor(0.55, 0.75, 0.58)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 6, 6)
    love.graphics.setColor(0.95, 0.97, 0.95)
    love.graphics.setFont(self.bodyFont)
    love.graphics.printf("Continue", b.x, b.y + b.h / 2 - 9, b.w, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

function Rest:drawRow(e, rowY, p)
    local char, from, max = e.char, e.from, e.max
    local px = self.boxX + 30
    local py = rowY + (ROW_H - PORTRAIT) / 2

    love.graphics.setColor(0.09, 0.10, 0.14)
    love.graphics.rectangle("fill", px, py, PORTRAIT, PORTRAIT, 5, 5)
    love.graphics.setFont(self.bodyFont)
    drawPortrait(char, px, py, PORTRAIT)
    love.graphics.setColor(0.4, 0.44, 0.55)
    love.graphics.rectangle("line", px, py, PORTRAIT, PORTRAIT, 5, 5)

    local barX = px + PORTRAIT + 14
    local barW = self.boxX + self.boxW - 30 - barX
    local barY = rowY + ROW_H / 2 - 2

    -- Name above the bar.
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.88, 0.90, 0.95)
    love.graphics.print(char and char.name or "?", barX, rowY + 6)

    -- The animated HP value: from the wound walked in with, up to full.
    local shown = from + (max - from) * p
    local fillFrac = max > 0 and shown / max or 1
    local startFrac = max > 0 and from / max or 1

    -- Track.
    love.graphics.setColor(0.20, 0.22, 0.28)
    love.graphics.rectangle("fill", barX, barY, barW, BAR_H, 3, 3)
    -- The portion that was already there when we sat down reads dim; the mend that fills over it reads
    -- bright, so the eye lands on what the rest actually restored.
    love.graphics.setColor(0.24, 0.42, 0.28)
    love.graphics.rectangle("fill", barX, barY, barW * startFrac, BAR_H, 3, 3)
    love.graphics.setColor(0.42, 0.82, 0.48)
    love.graphics.rectangle("fill", barX, barY, barW * fillFrac, BAR_H, 3, 3)
    love.graphics.setColor(0.45, 0.55, 0.5)
    love.graphics.rectangle("line", barX, barY, barW, BAR_H, 3, 3)

    -- Numeric HP, counting up with the bar.
    love.graphics.setColor(0.92, 0.95, 0.93)
    love.graphics.printf(math.floor(shown + 0.5) .. " / " .. max, barX, barY + 1, barW - 6, "right")
end

local function inButton(b, x, y)
    return x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h
end

function Rest:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    self.button.hovered = inButton(self.button, x, y)
end

function Rest:cursorKind(x, y)
    if self.closeButton:contains(x, y) or inButton(self.button, x, y) then return "hand" end
    return "arrow"
end

function Rest:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) or inButton(self.button, x, y) then
        self:done()
    end
end

function Rest:keypressed(key)
    if key == "escape" or key == "return" or key == "kpenter" or key == "space" then
        self:done()
    end
end

function Rest:gamepadpressed(_, button)
    if button == "a" or button == "b" or button == "start" then
        self:done()
    end
end

return Rest
