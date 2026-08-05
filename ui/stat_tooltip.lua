-- The stat-source tooltip: where one number on a character sheet actually comes from.
--
--   StatTooltip.draw(parts, "Attack", mx, my, maxRight)
--
-- `parts` is Party.statSources -- { label, value } per contributor, the body itself first and then one
-- row per piece of gear that moves the stat. The sheet prints a stat and says nothing about how it got
-- there, which is fine while the answer is "the blueprint" and useless the moment a body has eleven
-- levels and a full grid.
--
-- NO TOTAL ROW. The parts sum to the figure already printed on the sheet (Party.statTotal reads this
-- same list), so a total here would restate a number the player is looking at -- and the tooltip is
-- anchored to that very row, which is as close as a caption can get. An earlier draft carried two
-- subtotals, "On the sheet" and "In the field", because the sheet used to print the body WITHOUT its
-- gear and the difference had to be spelt out. The sheet prints the effective figure now, so the
-- discrepancy those rows existed to explain no longer exists.
--
-- Follows ui/material_tooltip.lua's shape: measure() lays it out, paint() pins it, draw() does the
-- ordinary "near the cursor, flipped and clamped" case.

local Theme = require("ui.theme")
local Scale = require("scale")

local StatTooltip = {}

StatTooltip.WIDTH = 208
local PAD = 9
local ROW = 15

local function fonts()
    return Theme.body(12), Theme.body(11)
end

-- A signed figure, always carrying its sign: a bare "6" in a column of contributions reads as a total.
local function signed(v)
    return (v > 0 and "+" or "") .. tostring(v)
end

-- Lay the box out. Nil only when there is genuinely no such stat on this body, so a caller can hand us
-- anything.
--
-- A ROW WITH NO GEAR ON IT STILL GETS A BOX, showing its one part. Suppressing that case was the first
-- cut -- "Base 4" under a row already reading "Magic 4" looked like a box that had wasted a hover -- but
-- it makes the tooltip unreliable, and an unreliable tooltip is worse than a redundant one: a player who
-- points at Magic, gets nothing, and cannot tell whether the answer is "nothing modifies this" or
-- "hovering does not work here" has been taught to stop pointing at things. The single row says it: one
-- source, and it is the body.
function StatTooltip.measure(parts, label)
    if not parts or #parts == 0 then return nil end

    local _, small = fonts()
    local h = PAD + small:getHeight() + 5 + #parts * ROW + PAD
    return { w = StatTooltip.WIDTH, h = h, label = label, parts = parts }
end

function StatTooltip.paint(layout, bx, by)
    if not layout then return nil end
    local body, small = fonts()
    local w, h = layout.w, layout.h
    local innerW = w - PAD * 2
    local x, y = bx + PAD, by + PAD

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, w, h, 4, 4)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", bx, by, w, h, 4, 4)

    love.graphics.setFont(small)
    Theme.set(Theme.muted)
    love.graphics.printf(string.upper(layout.label), x, y, innerW, "left")
    y = y + small:getHeight() + 5

    love.graphics.setFont(body)
    for i, p in ipairs(layout.parts) do
        -- The body's own figure is a QUANTITY and every piece of gear is a MODIFIER, so only the gear
        -- wears a sign -- and the sign is the whole reading on those rows, which is why a penalty is
        -- allowed to take the hostile red rather than being left to the minus glyph alone.
        local first = i == 1
        Theme.set(first and Theme.muted or (p.value > 0 and Theme.accentAmber or Theme.accentWeapon))
        love.graphics.print(Theme.ellipsize(p.label, body, innerW - 46), x, y)
        if first then Theme.set(Theme.ink) end
        love.graphics.printf(first and tostring(p.value) or signed(p.value), x, y, innerW, "right")
        y = y + ROW
    end

    love.graphics.setColor(1, 1, 1)
    return { x = bx, y = by, w = w, h = h }
end

function StatTooltip.draw(parts, label, mx, my, maxRight)
    local layout = StatTooltip.measure(parts, label)
    if not layout then return nil end
    maxRight = maxRight or Scale.WIDTH

    local bx = mx + 14
    local maxX = maxRight - layout.w - 4
    if bx > maxX then bx = mx - layout.w - 14 end
    bx = math.max(4, math.min(bx, maxX))
    local by = math.max(4, math.min(my + 16, Scale.HEIGHT - layout.h - 4))

    return StatTooltip.paint(layout, bx, by)
end

return StatTooltip
