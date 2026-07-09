-- Shared hover tooltip for a status effect: a dark panel showing the status's name,
-- description, and remaining duration, positioned near the mouse and clamped on-screen.
-- Both the battlefield badges (ui/battle_map.lua) and the turn-order strip (ui/combat_panel.lua)
-- expose a statusAt(px, py) hit-test; the owning battle state picks whichever is hovered and
-- draws it here, last, so the tooltip sits above the board AND the panel.

local Scale = require("scale")

local StatusTooltip = {}

local titleFont, bodyFont
local function fonts()
    titleFont = titleFont or love.graphics.newFont(14)
    bodyFont = bodyFont or love.graphics.newFont(12)
    return titleFont, bodyFont
end

-- Round a duration to 1 decimal place, dropping a trailing ".0" so whole turns read as "3".
local function fmtDuration(n)
    local rounded = math.floor((tonumber(n) or 0) * 10 + 0.5) / 10
    return (rounded % 1 == 0) and tostring(math.floor(rounded)) or string.format("%.1f", rounded)
end

-- Draw the tooltip for `status` anchored near (mx, my). `maxRight` caps the box's right edge so
-- it never slides under a side panel (defaults to the screen width). No-op when status is nil.
function StatusTooltip.draw(status, mx, my, maxRight)
    if not status then return end
    local def = status.def or {}
    local name = def.name or status.name or "Status"
    local desc = def.description
    local col = def.color or { 0.9, 0.9, 0.95 }
    local title, body = fonts()
    local lineH = body:getHeight()

    local pad, w = 8, 220
    local innerW = w - pad * 2
    maxRight = maxRight or Scale.WIDTH
    local descLines = desc and select(2, body:getWrap(desc, innerW)) or {}
    -- A self-expiring status (e.g. Defending "until next turn") carries a meaningless countdown,
    -- so it opts out of the duration line -- its description already conveys the timing.
    local showDuration = not def.hideDuration
    -- Height: title + description lines + duration line, plus padding and small section gaps.
    local h = pad + title:getHeight() + 4
        + (#descLines > 0 and (#descLines * lineH + 4) or 0)
        + (showDuration and lineH or 0) + pad

    -- Position near the cursor; flip left and clamp so the box stays within [4, maxRight].
    local bx = mx + 14
    local maxX = maxRight - w - 4
    if bx > maxX then bx = mx - w - 14 end
    bx = math.max(4, math.min(bx, maxX))
    local by = math.max(4, math.min(my + 16, Scale.HEIGHT - h - 4))

    love.graphics.setColor(0.08, 0.09, 0.12, 0.96)
    love.graphics.rectangle("fill", bx, by, w, h, 6, 6)
    love.graphics.setColor(col[1], col[2], col[3], 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bx, by, w, h, 6, 6)

    local ty = by + pad
    love.graphics.setFont(title)
    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.print(name, bx + pad, ty)
    ty = ty + title:getHeight() + 4

    love.graphics.setFont(body)
    if #descLines > 0 then
        love.graphics.setColor(0.85, 0.86, 0.9, 1)
        love.graphics.printf(desc, bx + pad, ty, innerW, "left")
        ty = ty + #descLines * lineH + 4
    end

    if showDuration then
        love.graphics.setColor(0.65, 0.68, 0.75, 1)
        love.graphics.print("Duration: " .. fmtDuration(status.remaining), bx + pad, ty)
    end
    love.graphics.setColor(1, 1, 1)
end

return StatusTooltip
