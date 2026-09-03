-- The shared LOOK of a relic wherever one is shown: its rarity colour, the faceted gem that marks it, and
-- the badge that names its rung. The surfaces that draw relics -- the Reliquary's pick-one offer
-- (ui/panels/relic_offer.lua), the Altar's reveal (ui/panels/relic_reveal.lua) and the overworld tray
-- (ui/relic_strip.lua) -- each had its own copy of the palette and the gem. One reader here keeps a rare
-- reading the same gold in all three, the twin of models/relic.lua's Relic.info being the one reader for
-- a relic's TEXT.
--
-- COLOUR IS RARITY, and that is the whole scheme. It used to be MORALITY -- a cool jade Virtue against a
-- warm crimson Vice -- with rarity demoted to a small tint on one badge. That axis is deleted (see
-- models/relic.lua's header for the argument), and the colour it was spending is now doing the job it
-- should always have had: saying how good the thing is, at a glance, in a tray of thirty.
--
-- The three are pulled off ui/theme.lua's own register rather than invented here, so a relic sits in the
-- same world as every other panel: a quiet steel for the plain rung, the interface's jade for the middle,
-- and the spotlight gold -- the colour the whole UI reserves for what is FOCUSED or live -- for the top.
-- Gold reads as rank because nothing else on a map is allowed to use it.

local RelicCard = {}

RelicCard.COMMON   = { 0.62, 0.64, 0.68 } -- #9ea4ad  quiet steel: a flat number, no strings
RelicCard.UNCOMMON = { 0.42, 0.80, 0.62 } -- #6bcc9e  jade: a trade
RelicCard.RARE     = { 0.83, 0.73, 0.45 } -- #d4ba72  the spotlight gold: an inversion

-- The accent for a Relic.info table (or anything carrying `.tier`). An unknown tier reads as common,
-- which is the right default: a def that forgot to declare one IS a plain number.
function RelicCard.accentOf(info)
    local tier = info and info.tier
    if tier == "rare" then return RelicCard.RARE end
    if tier == "uncommon" then return RelicCard.UNCOMMON end
    return RelicCard.COMMON
end

-- Kept as a separate name because the badge and the frame are drawn by different callers, even though
-- both now resolve to the same colour. One place to change if the badge ever wants its own treatment.
function RelicCard.tierColorOf(info) return RelicCard.accentOf(info) end

-- The faceted gem, the same mark the overworld marker and the tray chip use. `cx` is its horizontal
-- centre, `top` its top edge. Facet lines are drawn only on a gem big enough to carry them -- at 22px the
-- two hairs would just muddy the silhouette.
function RelicCard.gem(cx, top, w, h, accent)
    local a = accent or RelicCard.COMMON
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

-- The badge row for a relic, centred on `cx`. ONE CHIP where there used to be three.
--
-- The old row named alignment, tier and affinity -- and two of those are gone. Alignment does not exist;
-- affinity ("combat" / "overworld" / "both") was a second taxonomy nothing meaningfully filtered on and
-- said nothing a player could act on, so it went with it. What is left is the rung, which is the only
-- classification the shelf has and the only one worth a chip.
--
-- A relic already held shows its count instead of a second badge, because at the moment of the offer
-- that is the only other fact that changes the decision.
function RelicCard.badges(cx, y, info, font, held)
    info = info or {}
    local labels = { { (info.tier or "common"):upper(), RelicCard.accentOf(info) } }
    if held and held > 0 then
        labels[#labels + 1] = { "HELD x" .. held, RelicCard.RARE }
    end
    local totalW = 0
    for _, l in ipairs(labels) do totalW = totalW + font:getWidth(l[1]) + 16 + 8 end
    local x = cx - totalW / 2
    for _, l in ipairs(labels) do x = x + RelicCard.badge(x, y, l[1], l[2], font) + 8 end
    return font:getHeight() + 6
end

-- THE DWELL SURFACE, shared by every place a relic can be hovered: the overworld tray
-- (ui/relic_strip.lua) and the Merchant's relic shelf (ui/panels/merchant.lua). Name, rung, the text
-- resolved AT THE CURRENT STACK, and the standing price if it has one.
--
-- Here rather than in either caller because it is the same reading in both, and because the alternative
-- was the shop growing its own copy -- at which point a relic held twice would say "+3 damage" in the
-- tray and "+1 damage" on the shelf, which is the exact failure the stack-aware blurb exists to prevent.
--
-- `info` must carry `id` for the blurb to resolve its magnitude; without one the authored text is used.
-- Draws at (x, y), clamped so a relic near an edge does not push its reading off screen. Returns the
-- height used.
function RelicCard.tooltip(x, y, info, count, opts)
    opts = opts or {}
    local Relic = require("models.relic")
    local Theme = require("ui.theme")
    local Scale = require("scale")

    local nameFont = Theme.display(15)
    local bodyFont = Theme.body(12)
    local W, PAD = opts.width or 250, 8

    -- `opts.at` is the stack the READING quotes; `count` is the stack actually held. They part on an
    -- OFFER surface: the Merchant's shelf quotes what buying would leave the company on (held + 1), the
    -- same number relic_offer's cards quote, while the badge below still says what the run carries.
    local at = opts.at or count
    local key = info.id or info.def or info
    local blurb = Relic.blurbAt(key, at)
    -- The price resolved at THAT stack too, not the authored base -- a card reading "-3 defense" over a
    -- relic held twice is the same broken promise as one reading "+3 damage" over it.
    local cost = Relic.costAt(key, at) or info.cost
    local _, blurbLines = bodyFont:getWrap(blurb, W - PAD * 2)
    local costLines = {}
    if cost then _, costLines = bodyFont:getWrap(cost, W - PAD * 2) end

    local h = PAD + nameFont:getHeight() + 2 + bodyFont:getHeight() + 4
        + #blurbLines * bodyFont:getHeight()
        + (#costLines > 0 and (4 + #costLines * bodyFont:getHeight()) or 0) + PAD

    local tx = math.min(x, Scale.WIDTH - W - 8)
    local ty = math.min(math.max(8, y), Scale.HEIGHT - h - 8)

    local accent = RelicCard.accentOf(info)
    love.graphics.setColor(0.06, 0.065, 0.075, 0.97)
    love.graphics.rectangle("fill", tx, ty, W, h, 4, 4)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.85)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", tx, ty, W, h, 4, 4)

    local cy = ty + PAD
    love.graphics.setFont(nameFont)
    love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 1)
    love.graphics.print(info.name or "Relic", tx + PAD, cy)
    cy = cy + nameFont:getHeight() + 2

    love.graphics.setFont(bodyFont)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.9)
    local tag = (info.tier or "common"):upper()
    if (count or 0) > 1 then tag = tag .. "   x" .. count end
    love.graphics.print(tag, tx + PAD, cy)
    cy = cy + bodyFont:getHeight() + 4

    love.graphics.setColor(Theme.muted[1], Theme.muted[2], Theme.muted[3], 1)
    love.graphics.printf(blurb, tx + PAD, cy, W - PAD * 2, "left")
    cy = cy + #blurbLines * bodyFont:getHeight()

    if #costLines > 0 then
        cy = cy + 4
        love.graphics.setColor(0.90, 0.44, 0.40, 1)
        love.graphics.printf(cost, tx + PAD, cy, W - PAD * 2, "left")
    end
    return h
end

-- The gem-and-letterform chip a relic wears wherever it is small: the tray, and a shop row's icon slot.
-- `size` is the box it fills. Art debt stated plainly -- there are no relic icons in the tree, so the
-- mark is a stand-in and this is the one place that changes when they land.
function RelicCard.chip(x, y, size, info, count, opts)
    opts = opts or {}
    local Theme = require("ui.theme")
    local accent = RelicCard.accentOf(info)
    local alpha = opts.dim or 1

    love.graphics.setColor(0.07, 0.07, 0.08, 0.7 * alpha)
    love.graphics.rectangle("fill", x, y, size, size, 3, 3)
    love.graphics.setColor(accent[1], accent[2], accent[3], (opts.hot and 1 or 0.55) * alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, size, size, 3, 3)

    RelicCard.gem(x + size / 2, y + 3, size - 8, size - 7, { accent[1] * alpha, accent[2] * alpha, accent[3] * alpha })

    if info.mark then
        local f = Theme.body(math.max(9, math.floor(size * 0.38)))
        love.graphics.setFont(f)
        love.graphics.setColor(0.04, 0.04, 0.05, 0.95 * alpha)
        love.graphics.printf(info.mark, x, y + 3 + (size - 7) * 0.38 - f:getHeight() / 2, size, "center")
    end

    if (count or 0) > 1 then
        local f = Theme.body(math.max(9, math.floor(size * 0.34)))
        love.graphics.setFont(f)
        local label = "x" .. count
        local w = f:getWidth(label) + 4
        local bx, by = x + size - w, y + size - f:getHeight() - 1
        love.graphics.setColor(0.05, 0.05, 0.06, 0.9 * alpha)
        love.graphics.rectangle("fill", bx, by, w, f:getHeight() + 1, 2, 2)
        love.graphics.setColor(Theme.accentAmber[1], Theme.accentAmber[2], Theme.accentAmber[3], alpha)
        love.graphics.print(label, bx + 2, by)
    end
end

return RelicCard
