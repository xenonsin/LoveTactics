-- Run-relic strip: an always-on read of what the expedition is carrying (models/relic.lua), the twin of
-- the party HP/mana strip on the other corner. Drawn top-right on the overworld while routing, so the
-- snowball you're building is legible at a glance -- each relic a small gem chip coloured by its moral
-- tier (a cool Virtue, a warm Vice), with its banked counter when it is accumulating toward a payoff.
-- Hovering a chip (mouse) opens a tooltip with the full text and, for a Vice, its standing cost.
--
--   RelicStrip.draw(relicState, rightX, topY, mx, my)   -- mx/my in logical space, nil off-mouse
--
-- Purely a reader over Relic.info / Relic.bankedCount; it never mutates the run.

local Relic = require("models.relic")
local Theme = require("ui.theme")

local RelicStrip = {}

local VIRTUE = { 0.42, 0.80, 0.62 }
local VICE   = { 0.90, 0.44, 0.40 }

local ROW_H = 26
local GEM = 12
local WIDTH = 210
local PAD = 8

local function accentOf(info) return (info and info.alignment == "vice") and VICE or VIRTUE end

-- A small faceted gem, the shared relic mark, at (cx, cy) with half-size `r`.
local function gem(cx, cy, r, a)
    love.graphics.setColor(a[1], a[2], a[3], 1)
    love.graphics.polygon("fill", cx, cy - r, cx + r * 0.8, cy - r * 0.1, cx, cy + r, cx - r * 0.8, cy - r * 0.1)
end

-- The height the strip will occupy for a run holding `n` relics (0 when empty -- nothing is drawn).
function RelicStrip.height(n)
    if not n or n == 0 then return 0 end
    return 22 + n * ROW_H
end

-- Draw the strip and, if the mouse is over a chip, its tooltip. `rightX` is the right edge to align to.
function RelicStrip.draw(relicState, rightX, topY, mx, my)
    local held = Relic.held(relicState)
    if #held == 0 then return end

    local x = rightX - WIDTH
    local hovered

    -- Header.
    love.graphics.setFont(Theme.body(12))
    love.graphics.setColor(0.6, 0.64, 0.72)
    love.graphics.printf("RELICS", x, topY, WIDTH - PAD, "right")

    local nameFont = Theme.body(14)
    for i, entry in ipairs(held) do
        local info = Relic.info(entry.def) or {}
        local ry = topY + 20 + (i - 1) * ROW_H
        local rect = { x = x, y = ry, w = WIDTH, h = ROW_H - 4 }
        local over = mx and mx >= rect.x and mx <= rect.x + rect.w and my >= rect.y and my <= rect.y + rect.h
        if over then hovered = { entry = entry, info = info, y = ry } end

        local accent = accentOf(info)
        love.graphics.setColor(0.10, 0.11, 0.14, over and 0.9 or 0.6)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 5, 5)
        love.graphics.setColor(accent[1], accent[2], accent[3], over and 0.9 or 0.4)
        love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 5, 5)

        gem(rect.x + PAD + GEM / 2, rect.y + rect.h / 2, GEM / 2, accent)

        -- Name, fit to the remaining width (never scaled -- a scaled font blurs; long names step down).
        local bank = Relic.bankedCount(entry.id, relicState.scratch and relicState.scratch[entry.id])
        local counterW = bank and (nameFont:getWidth("  " .. bank)) or 0
        local avail = WIDTH - (PAD * 2 + GEM + 8) - counterW - PAD
        local font, name = Theme.fitText(Theme.body, info.name or entry.id, avail, 14, 11)
        love.graphics.setFont(font)
        love.graphics.setColor(0.9, 0.9, 0.94)
        love.graphics.print(name, rect.x + PAD + GEM + 8, rect.y + rect.h / 2 - font:getHeight() / 2)

        if bank then
            love.graphics.setFont(nameFont)
            love.graphics.setColor(accent[1], accent[2], accent[3], 0.95)
            local label = tostring(bank)
            love.graphics.print(label, rect.x + rect.w - PAD - nameFont:getWidth(label),
                rect.y + rect.h / 2 - nameFont:getHeight() / 2)
        end
    end

    if hovered then RelicStrip.drawTooltip(hovered.info, x, hovered.y) end
    love.graphics.setColor(1, 1, 1)
end

-- A compact tooltip to the LEFT of a hovered chip: name, alignment/tier line, blurb, and a Vice's cost.
function RelicStrip.drawTooltip(info, stripX, rowY)
    local w = 240
    local titleFont, bodyFont, tagFont = Theme.body(15), Theme.body(13), Theme.body(11)
    local _, blurbLines = bodyFont:getWrap(info.blurb or "", w - 20)
    local costLines = 0
    if info.alignment == "vice" and info.cost then
        local _, cl = bodyFont:getWrap("Cost: " .. info.cost, w - 20)
        costLines = #cl
    end
    local h = 14 + titleFont:getHeight() + tagFont:getHeight() + 6
        + math.max(1, #blurbLines) * bodyFont:getHeight() + 8
        + (costLines > 0 and (costLines * bodyFont:getHeight() + 6) or 0) + 10

    local x = stripX - w - 8
    local y = math.max(8, rowY)
    local accent = accentOf(info)

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.9)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)

    local cy = y + 8
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.96, 0.95, 0.92)
    love.graphics.print(info.name or "Relic", x + 10, cy)
    cy = cy + titleFont:getHeight() + 2

    love.graphics.setFont(tagFont)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.95)
    local tag = (info.alignment == "vice" and "VICE" or "VIRTUE") .. "  ·  " .. (info.tier or "common"):upper()
    love.graphics.print(tag, x + 10, cy)
    cy = cy + tagFont:getHeight() + 6

    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.82, 0.83, 0.88)
    love.graphics.printf(info.blurb or "", x + 10, cy, w - 20, "left")
    cy = cy + math.max(1, #blurbLines) * bodyFont:getHeight() + 8

    if costLines > 0 then
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.95)
        love.graphics.printf("Cost: " .. info.cost, x + 10, cy, w - 20, "left")
    end
end

return RelicStrip
