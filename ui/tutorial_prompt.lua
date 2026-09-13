-- The tutorial's instruction panel: the mentor talking the player through a fight while it is being
-- fought.
--
--   TutorialPrompt.draw(combat, prompt, opts)
--     prompt = { speaker = <character id>, text = "..." }  (nil -> nothing is drawn)
--     opts.box = { x, y, w, h }  -- the PANEL: a rect she speaks from, off the board
--
-- ONE SHAPE, AND IT NEEDS A GUTTER TO STAND IN.
--
-- She speaks from a panel under the board. That works because the gutter is free (only the
-- toggle-able combat log shares it) and because a panel off the board can stay up for the whole
-- lesson without ever covering a tile -- and the board is the thing the player is being taught to
-- read. Nothing is paid for it.
--
-- ON A HANDHELD THERE IS NO GUTTER TO HAVE: the board takes the whole short axis by design
-- (states/battle.lua's boardTop). A bubble over her own head was tried there and the geometry is
-- sound, but it is a second box laid on a 448-wide board that already carries the coach's, and once
-- position stops separating the two only register is left to do it. The lesson says everything twice
-- on purpose (data/tutorials/village.lua) -- she carries the fiction, ui/coach_bubble.lua carries the
-- control -- so where there is room for only one of them, the half that can be ACTED on stays and
-- this one drops. states/battle.lua simply does not call here in the short space; it is not a smaller
-- panel, it is silence.
--
-- WHICH IS ALSO WHY THE RECT IS AN ARGUMENT rather than measured here. The box used to be derived
-- from `leftMargin / rightMargin / boardBottom`, which is the desktop's arrangement written into the
-- widget -- and on a handheld it produced a negative height and the mentor went silent for the whole
-- lesson with a sliver of frame off the bottom edge to say so. The caller owns the geometry now
-- (states/battle.lua's speechRect), and the caller is also what decides she speaks at all.
--
-- The chrome -- fill, frame, bust, name plate, and the rect the line is laid out in -- is
-- ui/speech_box.lua, which the lesson's OPENING SCENE draws through as well (ui/dialogue.lua in
-- `overScene` mode). Those two speak from the same rectangle seconds apart, so they are one object
-- rather than two that agree.
--
-- No love.graphics at require-time.

local SpeechBox = require("ui.speech_box")
local Theme = require("ui.theme")

local TutorialPrompt = {}

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

function TutorialPrompt.draw(combat, prompt, opts)
    if not (prompt and prompt.text and combat) then
        shownText = nil
        return
    end
    local unit = findUnit(combat, prompt.speaker)
    if not unit then return end -- the speaker fell; the lesson reconciles itself on the next turn
    opts = opts or {}
    -- A rect with no room in it is not drawn at all. A box the caller could not find space for draws
    -- as a frame and a name plate with nothing legible between them, which reads as a bug rather than
    -- as silence -- and it is exactly what the short space produced back when this file measured its
    -- own rect off the board's bottom edge.
    local box = opts.box
    if not (box and box.w > 0 and box.h > 0) then return end

    if prompt.text ~= shownText then
        shownText = prompt.text
        age = 0
    end
    age = math.min((age or FADE) + love.timer.getDelta(), FADE)
    -- A correction snaps in at full strength. The ease-in suits a new instruction, but the one line
    -- that most needs to be noticed is the one answering a click the lesson just refused -- fading
    -- that up from nothing is exactly backwards.
    local alpha = prompt.alert and 1 or (age / FADE)

    drawPanel(unit, prompt.text, prompt.alert, box, alpha)
end

return TutorialPrompt
