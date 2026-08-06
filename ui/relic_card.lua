-- The shared LOOK of a relic wherever one is shown: its moral colour, the faceted gem that marks it, and
-- the badge row that names its axes. The panels that draw relics -- the Reliquary's pick-one offer
-- (ui/panels/relic_offer.lua) and the Sin's Altar reveal (ui/panels/relic_reveal.lua) -- each had its own
-- copy of the palette and the gem. One reader here keeps a Virtue reading the same cool jade in both, the
-- twin of models/relic.lua's Relic.info being the one reader for a relic's TEXT.

local RelicCard = {}

-- Alignment palettes: a Virtue reads cool jade, a Vice warm crimson, so the two halves of the shelf never
-- read alike. Tier tints the tier badge only -- a rare glints gold, a common stays neutral steel.
RelicCard.VIRTUE = { 0.42, 0.80, 0.62 }
RelicCard.VICE   = { 0.90, 0.44, 0.40 }
RelicCard.RARE   = { 0.86, 0.74, 0.36 }
RelicCard.COMMON = { 0.62, 0.66, 0.74 }

-- The accent for a Relic.info table (or anything carrying `.alignment`).
function RelicCard.accentOf(info)
    return (info and info.alignment == "vice") and RelicCard.VICE or RelicCard.VIRTUE
end

function RelicCard.tierColorOf(info)
    return (info and info.tier == "rare") and RelicCard.RARE or RelicCard.COMMON
end

-- The faceted gem, the same mark the overworld marker uses. `cx` is its horizontal centre, `top` its top
-- edge. Facet lines are drawn only on a gem big enough to carry them -- at 22px the two hairs would just
-- muddy the silhouette.
function RelicCard.gem(cx, top, w, h, accent)
    local a = accent or RelicCard.VIRTUE
    love.graphics.setColor(a[1], a[2], a[3], 1)
    love.graphics.polygon("fill", cx, top, cx + w / 2, top + h * 0.38, cx, top + h, cx - w / 2, top + h * 0.38)
    if w < 30 then return end
    love.graphics.setColor(a[1] * 0.5, a[2] * 0.5, a[3] * 0.5, 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(cx - w / 2, top + h * 0.38, cx + w / 2, top + h * 0.38)
    love.graphics.line(cx, top, cx, top + h)
end

-- One outlined badge chip. Returns its width so a caller can lay a row out left to right.
function RelicCard.badge(x, y, label, color, font)
    local w = font:getWidth(label) + 16
    local h = font:getHeight() + 6
    love.graphics.setColor(color[1], color[2], color[3], 0.18)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(color[1], color[2], color[3], 0.9)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
    love.graphics.setFont(font)
    love.graphics.print(label, x + 8, y + 3)
    return w
end

-- The badge row for a relic -- alignment, tier, and affinity when it has a side -- centred on `cx`. A
-- relic whose affinity is "both" shows two chips; the row is built the same way either way.
function RelicCard.badges(cx, y, info, font)
    info = info or {}
    local accent = RelicCard.accentOf(info)
    local labels = {
        { info.alignment == "vice" and "VICE" or "VIRTUE", accent },
        { (info.tier or "common"):upper(), RelicCard.tierColorOf(info) },
    }
    if info.affinity and info.affinity ~= "both" then
        labels[#labels + 1] = { info.affinity:upper(), RelicCard.COMMON }
    end
    local totalW = 0
    for _, l in ipairs(labels) do totalW = totalW + font:getWidth(l[1]) + 16 + 8 end
    local x = cx - totalW / 2
    for _, l in ipairs(labels) do x = x + RelicCard.badge(x, y, l[1], l[2], font) + 8 end
    return font:getHeight() + 6
end

return RelicCard
