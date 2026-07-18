-- The tutorial's instruction panel: the mentor talking the player through a fight while it is being
-- fought. A visual-novel text box in the gutter BELOW the board, with a name plate on its top edge
-- and the speaker's portrait standing at its right end.
--
--   TutorialPrompt.draw(combat, prompt, opts)
--     prompt = { speaker = <character id>, text = "..." }  (nil -> nothing is drawn)
--     opts   = { leftMargin, rightMargin, boardBottom }
--
-- Deliberately NOT a bubble floating over the speaker's head: the board is the thing the player is
-- being taught to read, and anything drawn on top of it hides the tiles the instruction is talking
-- about. The gutter under the board is free (only the toggle-able combat log shares it), so the
-- prompt can stay on screen for the whole lesson without ever covering a unit or a highlight.
--
-- The portrait is bottom-anchored and allowed to rise ABOVE the panel's top edge, the way a
-- visual-novel bust does -- it reads as someone leaning in over the battlefield rather than as a
-- picture in a slot. It is drawn behind the box so the overlap is the portrait's head only.
--
-- Art is loaded through models/sprite.lua, which is tolerant: a missing portrait yields the path
-- string instead of an Image, and the panel falls back to a tinted plate with the speaker's initial
-- (the same fallback ui/dialogue.lua uses). No love.graphics at require-time.

local Scale = require("scale")
local Colors = require("ui.colors")
local Sprite = require("models.sprite")
local utf8 = require("utf8")

local TutorialPrompt = {}

local nameFont, bodyFont, initialFont
local function fonts()
    nameFont = nameFont or love.graphics.newFont(15)
    bodyFont = bodyFont or love.graphics.newFont(16)
    initialFont = initialFont or love.graphics.newFont(40)
    return nameFont, bodyFont, initialFont
end

local PAD = 16
local GAP = 8            -- between the board's bottom edge and the panel
local BOTTOM = 12        -- between the panel and the bottom of the screen
local PORTRAIT_W = 118   -- the bust's slot at the panel's right end
local PLATE_H = 26

-- A short ease-in when the line changes, so a new instruction announces itself as new rather than
-- silently swapping text under the player's eyes.
local FADE = 0.18
local shownText, age

local function findUnit(combat, charId)
    for _, u in ipairs(combat.units) do
        if u.alive and u.char.id == charId then return u end
    end
    return nil
end

-- The speaker's bust, bottom-anchored at `baseY` and centred on `cx`.
--
-- Real art is allowed the full `bustH` and so rises above the panel's top edge, visual-novel style.
-- The fallback plate is held to `plateH` -- inside the panel -- instead: a bust that overflows reads
-- as someone leaning in, but a blank rectangle doing it just looks like a stray box. The plate
-- carries the first CHARACTER of the name (not the first byte -- a multibyte glyph must not be cut
-- apart), the same fallback ui/dialogue.lua uses.
local function drawPortrait(char, cx, baseY, bustH, plateH, alpha)
    local image = Sprite.load(char.portrait)
    if type(image) == "userdata" then
        local sw, sh = image:getDimensions()
        local scale = math.min(bustH / sh, PORTRAIT_W / sw)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(image, cx, baseY, 0, scale, scale, sw / 2, sh)
        return
    end
    local accent = Colors.PARTY
    local w = PORTRAIT_W
    love.graphics.setColor(accent[1] * 0.30, accent[2] * 0.34, accent[3] * 0.42, alpha)
    love.graphics.rectangle("fill", cx - w / 2, baseY - plateH, w, plateH, 8, 8)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.5 * alpha)
    love.graphics.rectangle("line", cx - w / 2, baseY - plateH, w, plateH, 8, 8)
    local _, _, big = fonts()
    love.graphics.setFont(big)
    love.graphics.setColor(0.9, 0.92, 0.96, alpha)
    local name = char.name or "?"
    local initial = name:sub(1, (utf8.offset(name, 2) or (#name + 1)) - 1)
    love.graphics.printf(initial, cx - w / 2, baseY - plateH / 2 - big:getHeight() / 2, w, "center")
end

function TutorialPrompt.draw(combat, prompt, opts)
    if not (prompt and prompt.text and combat) then
        shownText = nil
        return
    end
    local unit = findUnit(combat, prompt.speaker)
    if not unit then return end -- the speaker fell; the lesson reconciles itself on the next turn

    opts = opts or {}
    local name, body = fonts()

    if prompt.text ~= shownText then
        shownText = prompt.text
        age = 0
    end
    age = math.min((age or FADE) + love.timer.getDelta(), FADE)
    -- A correction snaps in at full strength. The ease-in suits a new instruction, but the one line
    -- that most needs to be noticed is the one answering a click the lesson just refused -- fading
    -- that up from nothing is exactly backwards.
    local alpha = prompt.alert and 1 or (age / FADE)

    -- The full free width between the left button column and the right combat panel, in the gutter
    -- under the board.
    local x = (opts.leftMargin or 0) + PAD
    local right = Scale.WIDTH - (opts.rightMargin or 0) - PAD
    local w = right - x
    local y = (opts.boardBottom or 0) + GAP
    local h = Scale.HEIGHT - BOTTOM - y

    -- A correction ("not that -- do as I showed you") borders in the refusal colour, so a player who
    -- clicked something the lesson won't take sees the panel change and not just re-read as usual.
    local accent = prompt.alert and Colors.ENEMY or Colors.PARTY
    love.graphics.setColor(0.08, 0.09, 0.13, 0.95 * alpha)
    love.graphics.rectangle("fill", x, y, w, h, 10, 10)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.85 * alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 10, 10)
    love.graphics.setLineWidth(1)

    -- Name plate straddling the top edge, near the left as in the reference framing.
    local speaker = unit.char.name or "?"
    love.graphics.setFont(name)
    local plateW = name:getWidth(speaker) + 32
    local plateX = x + 22
    love.graphics.setColor(0.14, 0.13, 0.19, 0.98 * alpha)
    love.graphics.rectangle("fill", plateX, y - PLATE_H / 2, plateW, PLATE_H, 6, 6)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.9 * alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", plateX, y - PLATE_H / 2, plateW, PLATE_H, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.95, 0.93, 0.85, alpha)
    love.graphics.printf(speaker, plateX, y - PLATE_H / 2 + 5, plateW, "center")

    -- The line itself, vertically centred in the room left of the portrait.
    local textW = w - PAD * 2 - PORTRAIT_W - PAD
    love.graphics.setFont(body)
    local _, lines = body:getWrap(prompt.text, textW)
    local textH = #lines * body:getHeight()
    love.graphics.setColor(0.93, 0.94, 0.97, alpha)
    love.graphics.printf(prompt.text, x + PAD + 8, y + (h - textH) / 2, textW, "left")

    -- The bust last, IN FRONT of the box: it stands at the panel's right end and rises over its top
    -- edge, which is the whole look. Drawn behind the box instead, the panel simply swallows it --
    -- only a sliver of head clears the top and the rest is under an opaque fill.
    drawPortrait(unit.char, x + w - PORTRAIT_W / 2 - PAD, y + h - 8, h + 78, h - 16, alpha)
    love.graphics.setColor(1, 1, 1)
end

return TutorialPrompt
