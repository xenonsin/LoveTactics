-- The over-the-board speech panel: the one box the game speaks from while a fight is on screen.
--
-- TWO CALLERS, AND THEY MUST BE ONE OBJECT.
--   * ui/dialogue.lua in `overScene` mode -- a scripted scene played over the frozen board (the
--     lesson's opening, staged there by states/battle.lua).
--   * ui/tutorial_prompt.lua -- the mentor's live instruction while the fight is being fought.
-- states/battle.lua already hands both of them the same rectangle (the free gutter under the board),
-- because a lesson hands off from the opening scene to the standing instruction mid-breath and the
-- words must not move an inch when it does. That got the POSITION right and left the two panels
-- looking like two different games: one wore the theme's bronze frame and serif line, the other a
-- blue border, a hand-mixed fill, rounder corners, a sans line, and its name plate on the other end
-- of the box. This module is the chrome behind both, so "the same panel" is structural rather than a
-- pair of comments asking two files to stay in step.
--
--   local tx, ty, tw, th = SpeechBox.textArea(x, y, w, h)
--   SpeechBox.draw(x, y, w, h, { name = "Rowan", portrait = char.portrait, accent = ..., alpha = ... })
--   love.graphics.setFont(SpeechBox.font(th)) -- then print the line into that rect yourself
--
-- It draws the panel, the bust and the name plate and stops there: the line itself belongs to the
-- caller, because one of them reveals it a character at a time and pages it, and the other swaps it
-- whole. Both lay it out in `textArea`, which is what keeps them identical.
--
-- Lazy fonts (nothing at require-time) keep it load-safe under tests/ui_load_spec.

local Theme = require("ui.theme")
local Sprite = require("models.sprite")
local utf8 = require("utf8")

local SpeechBox = {}

-- The bust's slot at the panel's right end, and the inset everything keeps from the box's edges.
-- Fire Emblem's side: the line reads out from the left margin TOWARD the face, instead of the eye
-- having to jump the portrait to reach the first word.
SpeechBox.PORTRAIT_W = 118
SpeechBox.PAD = 16

-- Insets for the spoken line. The top is a bare 12 rather than the full-screen box's 22 because the
-- name plate straddles the top edge at a FIXED place here (the left end), reaching exactly 12 into
-- the box -- so the first row starts flush under it, which is how a plate and the line it heads want
-- to sit anyway. The full-screen box needs the extra 10 because its plate floats to wherever the
-- speaker is standing and can land anywhere along that edge.
local TEXT_X = 24
local TEXT_TOP = 12
local TEXT_BOTTOM = 12

-- How the line is set. The face is the theme's display serif at the same size a full-screen scene
-- uses -- but the gutter under an 8x8 board is only about a hundred pixels tall, and at 22pt that is
-- ONE row per page: the village opening read out a clause at a time, a click per clause. So the size
-- is chosen by measurement instead of authored: the largest face in the ladder that fits ROWS rows in
-- the room actually available. A roomier gutter (a shallower board) keeps the full 22 and simply
-- shows more; the cramped one steps down until three rows fit. Measured, never scaled -- see the
-- project rule on Theme.fitText.
local MAX_SIZE, MIN_SIZE, ROWS = 22, 15, 3

-- Left edge of the bust's column. Everything else in the box stops short of it, so one place decides
-- where that column is.
function SpeechBox.bustLeft(x, w)
    return x + w - SpeechBox.PAD - SpeechBox.PORTRAIT_W
end

-- The rectangle the spoken line lays out in, as x, y, w, h -- the single source of truth for both
-- callers, and (in the dialogue's case) for pagination as well as drawing, so a page is measured
-- against exactly the box it renders into.
function SpeechBox.textArea(x, y, w, h)
    local tx = x + TEXT_X
    local tw = SpeechBox.bustLeft(x, w) - SpeechBox.PAD - tx
    return tx, y + TEXT_TOP, tw, h - TEXT_TOP - TEXT_BOTTOM
end

-- The face the line is set in, for a text area `textH` tall. See MAX_SIZE above.
function SpeechBox.font(textH)
    for size = MAX_SIZE, MIN_SIZE, -1 do
        local f = Theme.display(size)
        if math.floor(textH / f:getHeight()) >= ROWS then return f end
    end
    return Theme.display(MIN_SIZE)
end

-- The speaker's bust, bottom-anchored at `baseY` and centred on `cx`.
--
-- Real art gets the full height and so rises ABOVE the panel's top edge, visual-novel style -- it
-- reads as someone leaning in over the battlefield rather than as a picture in a slot. The letter
-- fallback is held INSIDE the box instead: a bust that overflows reads as a person, but a blank
-- rectangle doing it just looks like a stray box.
--
-- `portrait` is either a loaded image or the path to one; models/sprite.lua is tolerant and yields
-- the path string back when the art is missing, which is what routes it to the fallback plate.
local function drawBust(portrait, name, cx, baseY, bustH, plateH, alpha)
    local image = portrait
    if type(image) == "string" then image = Sprite.load(image) end
    local w = SpeechBox.PORTRAIT_W
    if type(image) == "userdata" then
        local sw, sh = image:getDimensions()
        local scale = math.min(bustH / sh, w / sw)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(image, cx, baseY, 0, scale, scale, sw / 2, sh)
        return
    end
    Theme.set(Theme.slot, alpha)
    love.graphics.rectangle("fill", cx - w / 2, baseY - plateH, w, plateH, Theme.R, Theme.R)
    Theme.set(Theme.frame, alpha)
    love.graphics.rectangle("line", cx - w / 2, baseY - plateH, w, plateH, Theme.R, Theme.R)
    local font = Theme.display(64)
    love.graphics.setFont(font)
    Theme.set(Theme.muted, alpha)
    -- First CHARACTER of the name (not the first byte) -- a multibyte glyph must not be cut apart.
    local label = name or "?"
    local initial = label:sub(1, (utf8.offset(label, 2) or (#label + 1)) - 1)
    love.graphics.printf(initial, cx - w / 2, baseY - plateH / 2 - font:getHeight() / 2, w, "center")
end

-- The panel: fill, border, bust, name plate. The caller prints the line into `textArea` afterwards.
--
--   opts.name     -- the speaker's display name (nil -> no plate, which is what an unattributed
--                    announcement wants)
--   opts.bust     -- whether the speaker stands at the right end at all. Separate from `portrait`
--                    because the two absences mean different things: a narrator who is not on the
--                    board has no bust, while a party member whose art has not landed yet has one
--                    and it falls back to a letter tile.
--   opts.portrait -- a loaded image or a path to one (nil -> the letter fallback)
--   opts.accent   -- the border colour, for a panel that has something to say about itself (the
--                    tutorial's correction borders in the hostile red). Defaults to Theme.frame,
--                    which is the ordinary panel edge every other plate in the game wears.
--   opts.alpha    -- 0..1, for a fade-in
function SpeechBox.draw(x, y, w, h, opts)
    opts = opts or {}
    local alpha = opts.alpha or 1
    local accent = opts.accent or Theme.frame

    Theme.set(Theme.panel, 0.94 * alpha)
    love.graphics.rectangle("fill", x, y, w, h, Theme.R, Theme.R)
    Theme.set(accent, alpha)
    love.graphics.rectangle("line", x, y, w, h, Theme.R, Theme.R)

    -- The bust IN FRONT of the box: drawn behind it the opaque fill swallows everything but a sliver
    -- of head.
    if opts.bust then
        drawBust(opts.portrait, opts.name,
            SpeechBox.bustLeft(x, w) + SpeechBox.PORTRAIT_W / 2, y + h - 8, h + 78, h - 16, alpha)
    end

    -- The name plate straddling the top edge, at the LEFT end -- the corner the line itself starts
    -- from. It was pinned over the bust first, on the reasoning that a plate should point at the face
    -- it names; but the bust is already unmistakably the speaker, so out there the plate labels
    -- something that needs no label and leaves the words with no header. At the left it reads as the
    -- heading of the sentence under it, which is what a name over a line of speech is for.
    if opts.name then
        local font = Theme.display(20)
        love.graphics.setFont(font)
        local plateW = font:getWidth(opts.name) + 36
        local plateX = x + 22
        local plateY = y - 20
        Theme.set(Theme.slot, alpha)
        love.graphics.rectangle("fill", plateX, plateY, plateW, 32, Theme.R, Theme.R)
        Theme.set(accent, alpha)
        love.graphics.rectangle("line", plateX, plateY, plateW, 32, Theme.R, Theme.R)
        Theme.set(Theme.accentAmber, alpha)
        love.graphics.printf(opts.name, plateX, plateY + 5, plateW, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

return SpeechBox
