-- The bench chooser: who comes on. A small tile-anchored card that pops up over the acting unit (or over
-- the tile a reinforcement is landing on) listing everyone waiting off the board, and hands the picked
-- one back to the caller. The twin of ui/panels/windup_chooser.lua and ui/panels/spend_chooser.lua in
-- shape and manners -- a decision made AT the place it happens, over a board that stays fully visible --
-- and it is deliberately the same widget for both routes onto the field:
--
--   ROTATE     -- the acting unit trades places with the pick, and the turn ends (Combat.rotate)
--   REINFORCE  -- a slot has opened and the pick fills it for free (Combat.reinforce)
--
-- One card, because the question is identical: which of these people. What differs is the price, and the
-- price is stated in the title rather than in a second panel.
--
-- Three-input + mouse-only by construction: click a row (or its portrait) to pick; arrows/W-S and Enter on
-- a keyboard; D-pad and A on a pad; Esc / B / right-click / click-off cancels. A row for someone who
-- cannot come in right now is drawn dim with its reason, and refuses the pick.
local Theme = require("ui.theme")
local Scale = require("scale")
local CloseButton = require("ui.close_button")
local Colors = require("ui.colors")

local BenchChooser = {}
BenchChooser.__index = BenchChooser

local PAD = 10
local TITLE_H = 26 -- the title line, with room under it before the first row's cursor ring
local ROW_H = 34
local PORTRAIT = 26
local W = 220

-- opts:
--   entries    the bench, a list of { char = <instance>, ... } (models/combat.lua's combat.bench)
--   title      what picking costs, in a few words ("Rotate -- costs this turn")
--   mandatory  this pick cannot be declined: the last-stand prompt, raised when nothing of the player's
--              is standing. There is no turn to hand back and no other way to reach one, so the X is
--              not drawn and every cancel is swallowed. See states/battle.lua's offerLastStand.
--   anchorX/Y  the tile's CENTRE in screen space; tileSize its size (so the card clears the tile)
--   onPick     fn(index) -- the chosen bench index
--   onCancel   fn()
function BenchChooser.new(opts)
    opts = opts or {}
    local self = setmetatable({}, BenchChooser)
    self.entries = opts.entries or {}
    self.title = opts.title or "Send in"
    self.mandatory = opts.mandatory
    self.onPick = opts.onPick
    self.onCancel = opts.onCancel
    self.cursor = 1
    self.hover = nil

    self.titleFont = Theme.display(14)
    self.font = Theme.body(13)
    self.smallFont = Theme.body(11)

    self.w = W
    self.h = PAD * 2 + TITLE_H + math.max(1, #self.entries) * ROW_H

    -- Anchored above the tile like a tooltip, clamped on-screen; drops below if it would clip the top.
    local half = (opts.tileSize or 48) / 2
    local ax, ay = opts.anchorX or Scale.WIDTH / 2, opts.anchorY or Scale.HEIGHT / 2
    self.x = math.floor(ax - self.w / 2)
    self.y = math.floor(ay - half - self.h - 10)
    if self.y < 8 then self.y = math.floor(ay + half + 10) end
    self.x = math.max(8, math.min(Scale.WIDTH - self.w - 8, self.x))
    self.y = math.max(8, math.min(Scale.HEIGHT - self.h - 8, self.y))

    self.close = CloseButton.new(self.x + self.w, self.y)
    return self
end

function BenchChooser:rowRect(i)
    return self.x + PAD, self.y + PAD + TITLE_H + (i - 1) * ROW_H, self.w - PAD * 2, ROW_H - 4
end

function BenchChooser:rowAt(px, py)
    for i = 1, #self.entries do
        local x, y, w, h = self:rowRect(i)
        if px >= x and px <= x + w and py >= y and py <= y + h then return i end
    end
    return nil
end

function BenchChooser:contains(px, py)
    return px >= self.x and px <= self.x + self.w and py >= self.y and py <= self.y + self.h
end

function BenchChooser:cancel()
    if self.mandatory then return end
    if self.onCancel then self.onCancel() end
end

function BenchChooser:pick(i)
    local entry = self.entries[i]
    if not entry then return end
    if self.onPick then self.onPick(i) end
end

-- ---- Draw ------------------------------------------------------------------

local function drawPortrait(char, x, y, size, font)
    local sprite = char and char.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(size / sw, size / sh)
        love.graphics.draw(sprite, x + size / 2, y + size / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        love.graphics.setColor(0.30, 0.32, 0.40)
        love.graphics.rectangle("fill", x, y, size, size, 4, 4)
        love.graphics.setFont(font)
        love.graphics.setColor(0.90, 0.90, 0.95)
        love.graphics.printf(((char and char.name) or "?"):sub(1, 1), x, y + size / 2 - 8, size, "center")
    end
end

function BenchChooser:draw()
    Theme.plate(self.x, self.y, self.w, self.h, Theme.R)

    -- Inset from the right so the title never runs under the X.
    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.print(Theme.ellipsize(self.title, self.titleFont, self.w - PAD * 2 - 20),
        self.x + PAD, self.y + PAD)

    if #self.entries == 0 then
        love.graphics.setFont(self.font)
        Theme.set(Theme.muted)
        love.graphics.printf("Nobody is on the bench.", self.x + PAD, self.y + PAD + TITLE_H + 6,
            self.w - PAD * 2, "center")
    end

    for i, entry in ipairs(self.entries) do
        local x, y, w, h = self:rowRect(i)
        local char = entry.char
        local focused = (self.hover == i) or (self.cursor == i)
        if focused then
            Theme.set(Theme.cursor)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x - 2, y - 2, w + 4, h + 4, 5, 5)
            love.graphics.setLineWidth(1)
        end

        drawPortrait(char, x, y + (h - PORTRAIT) / 2, PORTRAIT, self.font)

        local tx = x + PORTRAIT + 8
        love.graphics.setFont(self.font)
        love.graphics.setColor(0.90, 0.91, 0.96)
        love.graphics.print(Theme.ellipsize(char.name or "?", self.font, w - PORTRAIT - 12), tx, y + 2)

        -- The one number that decides who you send in: how much of them is left.
        local hp = char.stats and char.stats.health
        if type(hp) == "table" and (hp.max or 0) > 0 then
            local frac = math.max(0, math.min(1, (hp.current or 0) / hp.max))
            local barW = w - PORTRAIT - 12
            love.graphics.setColor(0.10, 0.11, 0.15)
            love.graphics.rectangle("fill", tx, y + h - 12, barW, 5, 2, 2)
            love.graphics.setColor(Colors.PARTY[1], Colors.PARTY[2], Colors.PARTY[3])
            love.graphics.rectangle("fill", tx, y + h - 12, barW * frac, 5, 2, 2)
            love.graphics.setFont(self.smallFont)
            Theme.set(Theme.muted)
            love.graphics.printf(math.floor(hp.current or 0) .. " / " .. math.floor(hp.max),
                tx, y + h - 26, barW, "right")
        end
    end

    if not self.mandatory then self.close:draw() end
    love.graphics.setColor(1, 1, 1)
end

-- ---- Input -----------------------------------------------------------------

function BenchChooser:mousemoved(x, y)
    if not self.mandatory then self.close:mousemoved(x, y) end
    self.hover = self:rowAt(x, y)
end

function BenchChooser:mousepressed(x, y, button)
    if button == 2 then self:cancel() return true end
    if button ~= 1 then return false end
    if not self.mandatory and self.close:mousepressed(x, y, button) then self:cancel() return true end
    local i = self:rowAt(x, y)
    if i then self:pick(i) return true end
    -- A click anywhere off the card backs out, the way every other tile-anchored chooser does.
    if not self:contains(x, y) then self:cancel() end
    return true
end

function BenchChooser:keypressed(key)
    if key == "escape" then self:cancel()
    elseif key == "return" or key == "kpenter" or key == "space" then self:pick(self.cursor)
    elseif key == "up" or key == "w" then self.cursor = math.max(1, self.cursor - 1)
    elseif key == "down" or key == "s" then self.cursor = math.min(#self.entries, self.cursor + 1)
    end
end

function BenchChooser:gamepadpressed(_, button)
    if button == "b" then self:cancel()
    elseif button == "a" then self:pick(self.cursor)
    elseif button == "dpup" then self.cursor = math.max(1, self.cursor - 1)
    elseif button == "dpdown" then self.cursor = math.min(#self.entries, self.cursor + 1)
    end
end

function BenchChooser:wheelmoved(_, dy)
    if dy > 0 then self.cursor = math.max(1, self.cursor - 1)
    elseif dy < 0 then self.cursor = math.min(#self.entries, self.cursor + 1) end
end

function BenchChooser:cursorKind(x, y)
    if not self.mandatory and self.close:contains(x, y) then return "hand" end
    return self:rowAt(x, y) and "hand" or "arrow"
end

return BenchChooser
