-- The tutorial's instruction panel: the mentor talking the player through a fight while it is being
-- fought.
--
--   TutorialPrompt.draw(combat, prompt, opts)
--     prompt = { speaker = <character id>, text = "..." }  (nil -> nothing is drawn)
--     opts.box    = { x, y, w, h }  -- the PANEL: a rect she speaks from, off the board
--     opts.map    -- the board, which switches her to a BUBBLE over the speaker's own head
--     opts.bounds -- where that bubble may live; opts.avoid -- what it should not cover
--
-- TWO SHAPES, ONE VOICE, AND THE SPACE DECIDES WHICH.
--
-- On a desktop she speaks from a panel in the gutter under the board. That is the better of the two
-- whenever it is available: the board is the thing the player is being taught to read, and a panel
-- off the board can stay up for the whole lesson without ever covering a tile. The gutter is free
-- (only the toggle-able combat log shares it), so nothing is paid for it.
--
-- On a handheld there is no gutter to have -- the board takes the whole short axis by design
-- (states/battle.lua's boardTop) -- and a panel there has to be laid over the board's foot, which
-- covers two rows of tiles for the length of the fight AND puts the words as far from the speaker as
-- the screen allows. A bubble over her head costs a third of that area, follows her as she moves, and
-- says who is talking by pointing at her instead of by carrying a name plate and a bust that a phone
-- has no room for. So the phone gets the bubble.
--
-- ...and it is HER bubble, not the coach's. The lesson speaks twice about everything (see
-- data/tutorials/village.lua): Rowan says the fiction and ui/coach_bubble.lua says which control to
-- press. Two bubbles are now on one board, so the register has to carry the difference that the
-- position used to: hers is the panel's own dark ground, bronze frame and display serif, exactly the
-- chrome she wears on a desktop; the coach's is gold, sans, key-capped and rings its target. Same
-- geometry underneath -- CoachBubble.place is shared, so neither drifts -- and nothing else.
--
-- WHICH IS ALSO WHY THE RECT IS AN ARGUMENT rather than measured here. The panel's box used to be
-- derived from `leftMargin / rightMargin / boardBottom`, which is the desktop's arrangement written
-- into the widget -- and on a handheld it produced a negative height and the mentor went silent for
-- the whole lesson with nothing on screen to say so.
--
-- The panel's chrome -- fill, frame, bust, name plate, and the rect the line is laid out in -- is
-- ui/speech_box.lua, which the lesson's OPENING SCENE draws through as well (ui/dialogue.lua in
-- `overScene` mode). Those two speak from the same rectangle seconds apart, so they are one object
-- rather than two that agree.
--
-- No love.graphics at require-time.

local CoachBubble = require("ui.coach_bubble")
local Scale = require("scale")
local SpeechBox = require("ui.speech_box")
local Theme = require("ui.theme")

local TutorialPrompt = {}

-- A short ease-in when the line changes, so a new instruction announces itself as new rather than
-- silently swapping text under the player's eyes.
local FADE = 0.18
local shownText, age

-- The bubble's own metrics. Wider than the coach's 330 because this is prose rather than an
-- instruction -- "There's more to the north. Slay them both before they do even more damage." is
-- three rows at 260 and two at 340 -- and a board is 448 across, so 340 still leaves a flank.
local BUBBLE_W = 340
local BUBBLE_PAD = 10

-- Her face, at the size the coach's was raised to for the same reason: 13pt lands at roughly 11 CSS
-- pixels on a handset, under the glance floor, and this is the sentence a first-time player is being
-- asked to act on. The display serif rather than the body face -- it is what she speaks in
-- everywhere else in the game, and it is half of what separates her bubble from the coach's.
--
-- Rebuilt on the space epoch rather than memoized once, for the reason ui/coach_bubble.lua's fonts()
-- carries: a session that changes spaces -- which is every browser session, since the fit is measured
-- after the first frames land -- otherwise keeps whichever face it happened to build first.
local bubbleFont, fontEpoch
local function font()
    if not bubbleFont or fontEpoch ~= Scale.spaceEpoch then
        bubbleFont = Theme.display(Scale.inHandheldSpace and 18 or 16)
        fontEpoch = Scale.spaceEpoch
    end
    return bubbleFont
end

local function findUnit(combat, charId)
    for _, u in ipairs(combat.units) do
        if u.alive and u.char.id == charId then return u end
    end
    return nil
end

-- The panel: the desktop shape, in the gutter under the board.
local function drawPanel(unit, text, alert, box, alpha)
    local x, y, w, h = box.x, box.y, box.w, box.h
    -- A correction ("not that -- do as I showed you") borders in the hostile red, so a player who
    -- clicked something the lesson won't take sees the panel change and not just re-read as usual.
    -- Everything else wears the ordinary panel edge, which is the whole point: an instruction is not
    -- a different kind of thing from the scene that opened the fight.
    SpeechBox.draw(x, y, w, h, {
        name = unit.char.name or "?",
        bust = true,
        portrait = unit.char.portrait,
        accent = alert and Theme.accentWeapon or nil,
        alpha = alpha,
    })

    -- The line, laid out in the shared text rect at the shared size -- so it lands on exactly the
    -- pixel the opening scene's last line came off.
    local tx, ty, tw, th = SpeechBox.textArea(x, y, w, h)
    love.graphics.setFont(SpeechBox.font(th))
    Theme.set(Theme.ink, alpha)
    love.graphics.printf(text, tx, ty, tw, "left")
    love.graphics.setColor(1, 1, 1)
end

-- The bubble: the handheld shape, over the speaker's own head.
--
-- No name plate and no bust, deliberately. ui/speech_box.lua argues that the bust makes the plate
-- redundant -- the face is unmistakably the speaker -- and the tail is a stronger version of the same
-- argument: it does not merely show who is talking, it shows WHERE they are standing, which on a
-- board is the more useful half. A plate here would cost two rows of the words to name somebody the
-- player is already looking at.
local function drawBubble(unit, text, alert, map, opts, alpha)
    local ux, uy = map:cellToPixel(unit.x, unit.y)
    local anchor = { x = ux, y = uy, w = map.size, h = map.size }

    -- Measured at the widest the bubble may be, then SHRUNK to the longest line -- and laid out at
    -- the shrunk width, not the measured one. Printing at the measurement width into a narrower box
    -- is what spills text past a border (ui/coach_bubble.lua learned this the hard way); the extra
    -- pixel absorbs the rounding between measured and rendered advance widths.
    local f = font()
    local bounds = opts.bounds
    local maxW = BUBBLE_W
    if bounds then maxW = math.min(maxW, math.max(140, bounds.w - BUBBLE_PAD * 2)) end
    local wrapW, lines = f:getWrap(text, maxW - BUBBLE_PAD * 2)
    local w = math.min(maxW, math.ceil(wrapW) + 1 + BUBBLE_PAD * 2)
    local h = BUBBLE_PAD * 2 + #lines * f:getHeight()

    -- OVER HER HEAD FIRST, and the flanks after. "Above" is what the player reads as somebody
    -- speaking; a box beside a body reads as a label on it. It yields to the sides only when there is
    -- no room overhead -- she is standing on the top row -- or when above is the placement that
    -- would bury the most of what the lesson is about (opts.avoid carries the other bodies and the
    -- tile the coach is pointing at).
    local side, x, y = CoachBubble.place(w, h, anchor, {
        prefer = "above", bounds = bounds, avoid = opts.avoid,
    })
    local bx1, by1, bx2, by2, tipX, tipY = CoachBubble.tail(side, x, y, w, h, anchor)

    -- THE EDGE IS STEPPED UP ONE NOTCH from the panel's, and only because the ground changed.
    -- Theme.frame is a quiet bronze authored to RECEDE against a panel face, which is exactly right
    -- in the gutter and invisible over a lit board -- the box read as a shadow with no border at all.
    -- Theme.muted is the same bronze family a shade brighter, so it holds against flagstone without
    -- reaching for the coach's gold, which is the one colour on this screen that has to keep meaning
    -- "press this". The fill and the serif are unchanged: those are what say the words are hers.
    local accent = alert and Theme.accentWeapon or Theme.muted
    Theme.set(Theme.panel, 0.94 * alpha)
    love.graphics.rectangle("fill", x, y, w, h, Theme.R, Theme.R)
    love.graphics.polygon("fill", bx1, by1, bx2, by2, tipX, tipY)

    Theme.set(accent, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, Theme.R, Theme.R)
    -- The tail's two flanks only: stroking its base would draw a line across the box's own edge.
    love.graphics.line(bx1, by1, tipX, tipY, bx2, by2)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(f)
    Theme.set(Theme.ink, alpha)
    love.graphics.printf(text, x + BUBBLE_PAD, y + BUBBLE_PAD, w - BUBBLE_PAD * 2, "left")
    love.graphics.setColor(1, 1, 1)
end

function TutorialPrompt.draw(combat, prompt, opts)
    if not (prompt and prompt.text and combat) then
        shownText = nil
        return
    end
    local unit = findUnit(combat, prompt.speaker)
    if not unit then return end -- the speaker fell; the lesson reconciles itself on the next turn
    opts = opts or {}
    -- A panel rect with no room in it is not drawn at all. A box the caller could not find space for
    -- draws as a frame and a name plate with nothing legible between them, which reads as a bug
    -- rather than as silence -- and it is exactly what the short space produced back when this file
    -- measured its own rect off the board's bottom edge.
    local box, map = opts.box, opts.map
    if not map and not (box and box.w > 0 and box.h > 0) then return end

    if prompt.text ~= shownText then
        shownText = prompt.text
        age = 0
    end
    age = math.min((age or FADE) + love.timer.getDelta(), FADE)
    -- A correction snaps in at full strength. The ease-in suits a new instruction, but the one line
    -- that most needs to be noticed is the one answering a click the lesson just refused -- fading
    -- that up from nothing is exactly backwards.
    local alpha = prompt.alert and 1 or (age / FADE)

    if map then
        drawBubble(unit, prompt.text, prompt.alert, map, opts, alpha)
    else
        drawPanel(unit, prompt.text, prompt.alert, box, alpha)
    end
end

return TutorialPrompt
