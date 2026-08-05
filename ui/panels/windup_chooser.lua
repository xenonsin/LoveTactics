-- The wind-up depth slider: a small tooltip-sized control that pops up ON the tile a chargeable
-- signature (The First Motion) is aimed at, the moment the swing is confirmed there. The depth is a
-- decision made AT the swing rather than a background scroll knob nobody could find. The blow does not
-- commit until this does -- the check commits it at the chosen depth, a click-off / Esc backs out.
--
-- It is deliberately tiny and anchored to the target: the board and the turn-order strip stay fully
-- visible behind it, because they ARE the preview. Sliding the depth -- or merely RESTING the pointer
-- on a rung -- writes battle.windup live, so the host's timeline slides the channel's resolve slot
-- along the strip (states/battle.lua refreshView) and the board footprint updates as the ladder fills
-- -- the player reads the trade (harder hit vs. longer, breakable tell) off the same board they are
-- fighting on, not off a wall of numbers in a modal. Hover previews cost nothing: only the check
-- commits, and it commits the CHOSEN depth, so the whole ladder can be walked before spending a click.
--
-- Three-input + mouse-only by construction: click or drag the rungs (or scroll) to size it and the
-- check to commit; arrows/+- and Enter on a keyboard; D-pad/bumpers and A on a pad; Esc / B / right-
-- click / click-off cancels.
local Theme = require("ui.theme")
local Scale = require("scale")
local InputMode = require("input_mode")
local Glyphs = require("ui.glyphs")

local WindupChooser = {}
WindupChooser.__index = WindupChooser

local RUNG_W, RUNG_H, RUNG_GAP = 16, 20, 3
local PAD = 8
local READOUT_H = 16
local CHECK_W = 24
local GAP = 8 -- between ladder and the check

-- opts:
--   lo, hi       the wind-up range in TOTAL ticks (floor .. cap); lo rungs are the base commitment
--   depth        initial depth (defaults to lo)
--   anchorX/Y    the aimed tile's CENTRE in screen space; tileSize its size (to clear the tile)
--   damageAt     optional fn(depth) -> { primary = n, total = n, count = k } | nil, priced per depth
--   onChange     fn(depth) -- every slide AND every hovered rung, so the host previews it (battle.windup
--                             + strip). Never a commitment: onConfirm is the only thing that swings.
--   onConfirm    fn(depth) -- commit the swing at this depth
--   onCancel     fn()      -- back out, staying armed
function WindupChooser.new(opts)
    opts = opts or {}
    local self = setmetatable({}, WindupChooser)
    self.lo = math.max(0, opts.lo or 0)
    self.hi = math.max(self.lo, opts.hi or self.lo)
    self.depth = math.max(self.lo, math.min(self.hi, opts.depth or self.lo))
    self.damageAt = opts.damageAt
    self.onChange = opts.onChange
    self.onConfirm = opts.onConfirm
    self.onCancel = opts.onCancel

    -- The face is fetched in draw, not here: Theme.body memoizes per size (and re-bakes on a resize),
    -- and baking a font needs a window -- which the headless suite has none of. The geometry below is
    -- all fixed constants, so nothing in here needs to measure text.

    -- Geometry: a readout line over a row of `hi` rungs, with a commit check to their right.
    self.ladderW = self.hi * RUNG_W + (self.hi - 1) * RUNG_GAP
    self.w = PAD * 2 + self.ladderW + GAP + CHECK_W
    self.h = PAD * 2 + READOUT_H + 4 + RUNG_H

    -- Anchor above the tile like a tooltip, clamped on-screen; drop below the tile if it would clip the
    -- top edge. `belowMouse`-style flip keeps the whole control visible without ever covering the tile.
    local half = (opts.tileSize or 48) / 2
    local ax, ay = opts.anchorX or Scale.WIDTH / 2, opts.anchorY or Scale.HEIGHT / 2
    self.tailUp = false
    self.x = math.floor(ax - self.w / 2)
    self.y = math.floor(ay - half - self.h - 10)
    if self.y < 8 then
        self.y = math.floor(ay + half + 10) -- below the tile instead
        self.tailUp = true
    end
    self.x = math.max(8, math.min(Scale.WIDTH - self.w - 8, self.x))
    self.tailX = math.max(self.x + 12, math.min(self.x + self.w - 12, math.floor(ax)))

    self.ladderX = self.x + PAD
    self.ladderY = self.y + PAD + READOUT_H + 4
    self.checkRect = { x = self.ladderX + self.ladderW + GAP, y = self.ladderY, w = CHECK_W, h = RUNG_H }

    self.hoverRung = nil
    self.hoverCheck = false
    self.dragging = false
    -- Price the opening depth without publishing it: the host set battle.windup to the floor when it
    -- raised this panel, so an onChange here would only tell it what it already did.
    self.shown = self.depth
    self.dmg = self.damageAt and self.damageAt(self.depth) or nil
    return self
end

-- The depth being SHOWN, which is not always the one CHOSEN: resting the pointer on a rung previews
-- that hold -- the damage read-out reprices and onChange slides the strip's resolve slot -- without
-- spending the click. Nothing commits off a hover (onConfirm still swings at self.depth), so the whole
-- ladder can be walked and each rung's trade read before one is picked. The preview drops back to the
-- chosen depth the moment the pointer leaves the ladder. A drag is excluded: it is already driving
-- setDepth from the same pointer, and its loose grip deliberately tracks past the ladder's ends.
function WindupChooser:shownDepth()
    if self.hoverRung and not self.dragging then
        return math.max(self.lo, math.min(self.hi, self.hoverRung))
    end
    return self.depth
end

-- Reprice + republish whenever the shown depth moves, from either source. Gated on an actual change
-- because damageAt runs a full board preview -- a hover that rests on one rung must not re-run it on
-- every mousemoved, and the host must not be handed a depth it already has.
function WindupChooser:refresh()
    local d = self:shownDepth()
    if d == self.shown then return end
    self.shown = d
    self.dmg = self.damageAt and self.damageAt(d) or nil
    if self.onChange then self.onChange(d) end
end

function WindupChooser:setDepth(d)
    d = math.max(self.lo, math.min(self.hi, math.floor(d + 0.5)))
    if d == self.depth then return end
    self.depth = d
    self:refresh()
end

-- Keys, pad and wheel all step the CHOSEN depth, so they drop any hover preview riding over it --
-- otherwise a pointer left resting on rung 3 would go on showing 3 while the arrows moved the real
-- depth underneath it. The ring returns on the next mouse move.
function WindupChooser:adjust(delta)
    self.hoverRung = nil
    self:setDepth(self.depth + delta)
    self:refresh() -- setDepth no-ops at the ends; the cleared hover still has to fall back
end
function WindupChooser:confirm() if self.onConfirm then self.onConfirm(self.depth) end end
function WindupChooser:cancel() if self.onCancel then self.onCancel() end end
function WindupChooser:update(dt) end

function WindupChooser:rungX(i)
    return self.ladderX + (i - 1) * (RUNG_W + RUNG_GAP)
end

-- The rung under a pixel, clamped to the nearest one while the pointer is inside the ladder's vertical
-- band (so a drag past either end still tracks the last rung rather than dropping the grip).
--
-- A plain hover is bounded HORIZONTALLY too, which a drag is not: the check sits at the ladder's right
-- at the same height, and an unbounded read would call it rung `hi` -- lighting the top of the ladder
-- and previewing the deepest hold while the pointer rests on the button that commits the CHOSEN one.
-- The read-out and the swing must never disagree, so the ladder's reach ends with the ladder.
function WindupChooser:rungAt(x, y, loose)
    if not loose and (y < self.ladderY - 4 or y > self.ladderY + RUNG_H + 4) then return nil end
    if not loose and (x < self.ladderX - RUNG_GAP or x > self.ladderX + self.ladderW + RUNG_GAP) then
        return nil
    end
    for i = 1, self.hi do
        local rx = self:rungX(i)
        if x < rx + RUNG_W + RUNG_GAP / 2 then return math.max(1, i) end
    end
    return self.hi
end

local function pointIn(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function WindupChooser:draw()
    -- The box (no full-screen dim -- the board and strip behind it are the preview).
    Theme.plate(self.x, self.y, self.w, self.h, Theme.R)
    -- A little tail pointing at the tile it is sizing.
    Theme.set(Theme.panel)
    local tx = self.tailX
    if self.tailUp then
        love.graphics.polygon("fill", tx - 6, self.y, tx + 6, self.y, tx, self.y - 7)
    else
        love.graphics.polygon("fill", tx - 6, self.y + self.h, tx + 6, self.y + self.h, tx, self.y + self.h + 7)
    end

    -- Readout: the tell (hourglass + "lands in N") on the left, the damage the depth buys on the right.
    -- Both quote the SHOWN depth, so a hovered rung reads out its own hold and its own damage -- the
    -- same depth the strip's resolve slot has already slid to.
    local shown = self:shownDepth()
    local font = Theme.body(14)
    love.graphics.setFont(font)
    local ry = self.y + PAD
    Glyphs.hourglass(self.x + PAD, ry + 1, 12, 12, Theme.ink[1], Theme.ink[2], Theme.ink[3], 1)
    Theme.set(Theme.ink)
    love.graphics.print(tostring(shown), self.x + PAD + 16, ry - 1)
    local held = shown - self.lo
    if held > 0 then
        Theme.set(Theme.muted)
        love.graphics.print("+" .. held, self.x + PAD + 16 + font:getWidth(tostring(shown)) + 6, ry - 1)
    end
    local n = self.dmg and (self.dmg.primary or self.dmg.total)
    if n then
        Theme.set(Theme.accentAmber)
        love.graphics.printf(tostring(n), self.x, ry - 1, self.w - PAD, "right")
    end

    -- The rung ladder. Solid gold up to the depth the ladder AND the hover agree on; the band between
    -- them -- the ticks a hovered rung would add, or the ones it would give back -- fills at half
    -- weight, so the ladder shows the hold being considered without ever pretending it is chosen.
    local firm, loose = math.min(self.depth, shown), math.max(self.depth, shown)
    for i = 1, self.hi do
        local rx = self:rungX(i)
        local locked = i <= self.lo        -- the base commitment, never given up
        local fill = locked and Theme.frame or (i <= loose and Theme.accentAmber or Theme.slot)
        Theme.set(fill, (not locked and i > firm and i <= loose) and 0.45 or nil)
        love.graphics.rectangle("fill", rx, self.ladderY, RUNG_W, RUNG_H, 2, 2)
        if self.hoverRung == i then
            Theme.set(Theme.cursor)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", rx, self.ladderY, RUNG_W, RUNG_H, 2, 2)
            love.graphics.setLineWidth(1)
        end
    end

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

function WindupChooser:mousemoved(x, y)
    if self.dragging then
        if love.mouse.isDown(1) then
            self:setDepth(self:rungAt(x, y, true))
        else
            self.dragging = false
        end
    end
    self.hoverRung = self:rungAt(x, y)
    self.hoverCheck = pointIn(self.checkRect, x, y)
    self:refresh() -- a rung under the pointer previews itself; leaving the ladder restores the choice
end

-- Hand cursor over anything clickable; arrow otherwise (see ui/cursor.lua).
function WindupChooser:cursorKind(x, y)
    if self:rungAt(x, y) or pointIn(self.checkRect, x, y) then return "hand" end
    return "arrow"
end

function WindupChooser:mousepressed(x, y, button)
    if button == 2 then self:cancel() return end -- right-click backs out
    if button ~= 1 then return end
    if pointIn(self.checkRect, x, y) then self:confirm() return end
    local rung = self:rungAt(x, y)
    if rung then self:setDepth(rung); self.dragging = true; return end
    -- A click anywhere off the little box backs out (staying armed).
    if x < self.x or x > self.x + self.w or y < self.y or y > self.y + self.h then self:cancel() end
end

function WindupChooser:mousereleased(x, y, button)
    self.dragging = false
end

function WindupChooser:wheelmoved(dx, dy)
    if dy ~= 0 then self:adjust(dy > 0 and 1 or -1) end
end

function WindupChooser:keypressed(key)
    if key == "escape" then self:cancel()
    elseif key == "return" or key == "kpenter" or key == "space" then self:confirm()
    elseif key == "left" or key == "down" or key == "-" or key == "kp-" then self:adjust(-1)
    elseif key == "right" or key == "up" or key == "=" or key == "kp+" then self:adjust(1)
    end
end

function WindupChooser:gamepadpressed(joystick, button)
    if button == "b" then self:cancel()
    elseif button == "a" then self:confirm()
    elseif button == "dpleft" or button == "dpdown" or button == "leftshoulder" then self:adjust(-1)
    elseif button == "dpright" or button == "dpup" or button == "rightshoulder" then self:adjust(1)
    end
end

return WindupChooser
