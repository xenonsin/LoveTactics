-- One status-effect badge: the rounded box plus the status def's `abbr`, tinted with the def's
-- `color`. Shared by the battlefield badges (ui/battle_map.lua) and the turn-order strip
-- (ui/combat_panel.lua) so a status reads identically wherever it appears.
--
-- The label is squeezed horizontally when it is wider than the badge. love.graphics.printf never
-- breaks a single word, so a 3-character abbr ("Hst", "Brn") simply overflowed both edges of the
-- 15px box it was centred in; scaling it down keeps it inside the border instead.

local StatusBadge = {}

local PAD = 2 -- px kept clear of the badge's border on each side

local labelFont
local function font()
    labelFont = labelFont or love.graphics.newFont(10)
    return labelFont
end

-- The badge's short label: the def's `abbr`, falling back to the first letter of its name.
function StatusBadge.label(st)
    return (st.def and st.def.abbr) or (st.name or "?"):sub(1, 1)
end

function StatusBadge.draw(st, x, y, w, h)
    local col = (st.def and st.def.color) or { 0.82, 0.82, 0.88 }
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)
    love.graphics.setColor(col[1], col[2], col[3], 0.95)
    love.graphics.rectangle("line", x, y, w, h, 3, 3)

    local f = font()
    local label = StatusBadge.label(st)
    local tw, th = f:getWidth(label), f:getHeight()
    -- Squeeze to the badge's inner width; never stretch a short label up to it.
    local sx = math.min(1, (w - PAD * 2) / math.max(tw, 1))

    love.graphics.setFont(f)
    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.print(label, x + (w - tw * sx) / 2, y + (h - th) / 2, 0, sx, 1)
end

return StatusBadge
