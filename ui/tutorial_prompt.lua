-- The tutorial's instruction panel: the mentor talking the player through a fight while it is being
-- fought.
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
-- The panel itself -- fill, frame, bust, name plate, and the rect the line is laid out in -- is
-- ui/speech_box.lua, which the lesson's OPENING SCENE draws through as well (ui/dialogue.lua in
-- `overScene` mode). The two speak from the same rectangle seconds apart, so they are one object
-- rather than two that agree: this file owns the mentor's line and nothing about how the box looks.
--
-- No love.graphics at require-time.

local Scale = require("scale")
local SpeechBox = require("ui.speech_box")
local Theme = require("ui.theme")

local TutorialPrompt = {}

local PAD = SpeechBox.PAD -- the inset from the columns on either side, shared with the opening scene
local GAP = 8             -- between the board's bottom edge and the panel
local BOTTOM = 12         -- between the panel and the bottom of the screen

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

function TutorialPrompt.draw(combat, prompt, opts)
    if not (prompt and prompt.text and combat) then
        shownText = nil
        return
    end
    local unit = findUnit(combat, prompt.speaker)
    if not unit then return end -- the speaker fell; the lesson reconciles itself on the next turn

    opts = opts or {}

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
    -- under the board -- the same rect states/battle.lua hands the opening scene.
    local x = (opts.leftMargin or 0) + PAD
    local right = Scale.WIDTH - (opts.rightMargin or 0) - PAD
    local w = right - x
    local y = (opts.boardBottom or 0) + GAP
    local h = Scale.HEIGHT - BOTTOM - y

    -- A correction ("not that -- do as I showed you") borders in the hostile red, so a player who
    -- clicked something the lesson won't take sees the panel change and not just re-read as usual.
    -- Everything else wears the ordinary panel edge, which is the whole point: an instruction is not
    -- a different kind of thing from the scene that opened the fight.
    SpeechBox.draw(x, y, w, h, {
        name = unit.char.name or "?",
        bust = true,
        portrait = unit.char.portrait,
        accent = prompt.alert and Theme.accentWeapon or nil,
        alpha = alpha,
    })

    -- The line, laid out in the shared text rect at the shared size -- so it lands on exactly the
    -- pixel the opening scene's last line came off.
    local tx, ty, tw, th = SpeechBox.textArea(x, y, w, h)
    love.graphics.setFont(SpeechBox.font(th))
    Theme.set(Theme.ink, alpha)
    love.graphics.printf(prompt.text, tx, ty, tw, "left")
    love.graphics.setColor(1, 1, 1)
end

return TutorialPrompt
