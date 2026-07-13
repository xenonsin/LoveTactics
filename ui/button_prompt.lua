-- Context-sensitive control-hint bar: a row of small pills, each a button glyph (e.g. "A",
-- "LB/RB") followed by its action label. Text-only -- no controller art -- so it needs no assets
-- and reads the same regardless of pad brand. The host rebuilds the segment list as focus/state
-- changes and draws this wherever a footer hint belongs (see ui/panels/party.lua:drawPromptBar).
--
--   ButtonPrompt.draw({ { glyph = "A", label = "Equip" }, ... }, x, y, w, { align = "center" })
--
-- A segment may carry an explicit `color` (used for the glyph) so the caller can keep a semantic
-- tint -- confirm green, cancel red -- across modes where the glyph text changes (A vs. Enter).
--
-- Lazy fonts (newed on first draw) keep this require-safe under headless tests.

local ButtonPrompt = {}

local glyphFont, labelFont
local function fonts()
    glyphFont = glyphFont or love.graphics.newFont(12)
    labelFont = labelFont or love.graphics.newFont(13)
    return glyphFont, labelFont
end

-- Glyph tint by face button, matching the A=confirm / B=cancel color language the widgets use for
-- their cursor/pickup rings. Multi-key glyphs (LB/RB, D-pad) fall through to the neutral default.
local GLYPH_COLOR = {
    A = { 0.55, 0.90, 0.58 },
    B = { 0.95, 0.50, 0.47 },
    X = { 0.55, 0.70, 0.95 },
    Y = { 0.95, 0.82, 0.45 },
}
local DEFAULT_GLYPH = { 0.85, 0.87, 0.92 }
local LABEL_COLOR = { 0.62, 0.66, 0.74 }
local PILL_BG = { 0.20, 0.22, 0.28, 0.9 }

local PAD = 6      -- glyph-pill inner padding
local GAP = 6      -- glyph pill -> its label
local SEG_GAP = 18 -- between one segment and the next

-- Total pixel width of the rendered row, for centering/right-alignment.
local function rowWidth(segments, gf, lf)
    local w = 0
    for i, seg in ipairs(segments) do
        w = w + gf:getWidth(seg.glyph) + PAD * 2 + GAP + lf:getWidth(seg.label)
        if i < #segments then w = w + SEG_GAP end
    end
    return w
end

function ButtonPrompt.draw(segments, x, y, w, opts)
    if not segments or #segments == 0 then return end
    opts = opts or {}
    local gf, lf = fonts()
    local gh = gf:getHeight()
    local cx = x
    if opts.align == "center" then cx = x + (w - rowWidth(segments, gf, lf)) / 2
    elseif opts.align == "right" then cx = x + w - rowWidth(segments, gf, lf) end

    for _, seg in ipairs(segments) do
        local gw = gf:getWidth(seg.glyph) + PAD * 2
        love.graphics.setColor(PILL_BG[1], PILL_BG[2], PILL_BG[3], PILL_BG[4])
        love.graphics.rectangle("fill", cx, y - 2, gw, gh + 4, 4, 4)
        local gc = seg.color or GLYPH_COLOR[seg.glyph] or DEFAULT_GLYPH
        love.graphics.setFont(gf)
        love.graphics.setColor(gc[1], gc[2], gc[3])
        love.graphics.print(seg.glyph, cx + PAD, y)
        cx = cx + gw + GAP

        love.graphics.setFont(lf)
        love.graphics.setColor(LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3])
        love.graphics.print(seg.label, cx, y)
        cx = cx + lf:getWidth(seg.label) + SEG_GAP
    end
    love.graphics.setColor(1, 1, 1)
end

return ButtonPrompt
