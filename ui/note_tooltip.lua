-- The note tooltip: a titled block of prose, for hanging an explanation off a section caption.
--
--   NoteTooltip.draw("Technique", { "para one", "para two" }, mx, my, maxRight)
--
-- The other tooltips in ui/ all itemise a THING -- an item's stats, a status's rules, a stat's sources.
-- This one answers "what is this section even counting?", which is a question a player asks once and
-- then never again, and which a heading has no room to answer on its own. Kin to them in shape
-- (measure / paint / draw, ui/material_tooltip.lua's), deliberately plainer in content: a title and
-- wrapped paragraphs, no columns, no figures.

local Theme = require("ui.theme")
local Scale = require("scale")

local NoteTooltip = {}

NoteTooltip.WIDTH = 250
local PAD = 9
local GAP = 6                                   -- between paragraphs

local function fonts()
    return Theme.body(12), Theme.body(11)
end

function NoteTooltip.measure(title, paragraphs)
    if not (paragraphs and #paragraphs > 0) then return nil end

    local body, small = fonts()
    local innerW = NoteTooltip.WIDTH - PAD * 2

    -- Wrap up front so the box is exactly as tall as its text: a fixed height would either clip a long
    -- paragraph or leave a dead band under a short one, and this text is authored, not generated.
    local blocks = {}
    local h = PAD + small:getHeight() + 5
    for i, text in ipairs(paragraphs) do
        local _, lines = body:getWrap(text, innerW)
        local n = math.max(1, #lines)
        blocks[i] = n
        h = h + n * body:getHeight() + (i < #paragraphs and GAP or 0)
    end

    return { w = NoteTooltip.WIDTH, h = h + PAD, title = title,
             paragraphs = paragraphs, lines = blocks }
end

function NoteTooltip.paint(layout, bx, by)
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
    love.graphics.printf(string.upper(layout.title or ""), x, y, innerW, "left")
    y = y + small:getHeight() + 5

    love.graphics.setFont(body)
    Theme.set(Theme.ink)
    for i, text in ipairs(layout.paragraphs) do
        love.graphics.printf(text, x, y, innerW, "left")
        y = y + layout.lines[i] * body:getHeight() + GAP
    end

    love.graphics.setColor(1, 1, 1)
    return { x = bx, y = by, w = w, h = h }
end

function NoteTooltip.draw(title, paragraphs, mx, my, maxRight)
    local layout = NoteTooltip.measure(title, paragraphs)
    if not layout then return nil end
    maxRight = maxRight or Scale.WIDTH

    local bx = mx + 14
    local maxX = maxRight - layout.w - 4
    if bx > maxX then bx = mx - layout.w - 14 end
    bx = math.max(4, math.min(bx, maxX))
    local by = math.max(4, math.min(my + 16, Scale.HEIGHT - layout.h - 4))

    return NoteTooltip.paint(layout, bx, by)
end

return NoteTooltip
