-- A TUTORIAL WINDOW: a modal that stops the screen and explains one feature in full sentences, the way
-- Fire Emblem's info windows do. Title, a few short paragraphs, one button out.
--
--   local panel = TutorialNote.new({ title = "The Tally", body = "...\n\n...", onClose = fn })
--   panel:update(dt); panel:draw()
--   panel:mousepressed(x, y, button); panel:keypressed(key); panel:gamepadpressed(joystick, button)
--
-- WHY A WINDOW AND NOT A BUBBLE. ui/coach_bubble.lua is the other half of this game's teaching and the
-- two are not interchangeable: a bubble points at a CONTROL and says the one thing to do with it ("click
-- to take the stair down"), which is why it is small, tailed, and drawn without stopping anything. A
-- FEATURE is not a control -- the tally is a number with three rules and a failure state, and none of
-- that fits in a tail. This stops the screen, states the rules in order, and costs a button press.
--
-- Reach for a bubble when the answer is "press this". Reach for this when the player has to be told how
-- something WORKS before any press makes sense.
--
-- THE BOX GROWS TO ITS TEXT rather than scrolling or clipping, so a note is never half-told. `body` is
-- wrapped at the box width and measured a written line at a time, which is what lets an author break
-- paragraphs with \n\n and get paragraphs (the same measuring ui/panels/choice.lua does for its prompt).
--
-- ANY BUTTON CLOSES IT, including confirm. A window whose only job is to be read should not make the
-- player hunt for the one key that dismisses it, and every input mode gets a way out it already knows:
-- Enter/Space/Esc, A/B, the X, or a click anywhere off the box.

local CloseButton = require("ui.close_button")
local Scale = require("scale")
local InputMode = require("input_mode")
local Theme = require("ui.theme")

local TutorialNote = {}
TutorialNote.__index = TutorialNote

local BOX_W = 560
local PAD = 34          -- inside the box, left and right of the words
local TITLE_TOP = 30    -- box top -> title baseline area
local BODY_TOP = 92     -- box top -> first line of body
local FOOT_H = 52       -- room under the body for the dismiss hint

function TutorialNote.new(opts)
    opts = opts or {}
    local self = setmetatable({}, TutorialNote)
    self.title = opts.title or "Tutorial"
    self.body = opts.body or ""
    self.onClose = opts.onClose
    self.titleFont = Theme.display(28)
    self.bodyFont = Theme.body(16)

    -- Measure a written line at a time so an authored blank line stays a blank line: getWrap on the
    -- whole body would collapse the paragraph breaks the author put there on purpose.
    local lines = 0
    local lineH = self.bodyFont:getHeight()
    for line in (self.body .. "\n"):gmatch("([^\n]*)\n") do
        if line == "" then
            lines = lines + 0.6 -- a paragraph gap, not a full empty line
        else
            local _, wrapped = self.bodyFont:getWrap(line, BOX_W - PAD * 2)
            lines = lines + math.max(1, #wrapped)
        end
    end
    self.bodyH = lines * lineH

    self.boxH = BODY_TOP + self.bodyH + FOOT_H
    self.boxX = math.floor(Scale.WIDTH / 2 - BOX_W / 2)
    self.boxY = math.floor(Scale.HEIGHT / 2 - self.boxH / 2)
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

function TutorialNote:close()
    if self.onClose then self.onClose() end
end

function TutorialNote:update(dt) end

function TutorialNote:draw()
    -- Dim what is behind it. Heavier than a shop's overlay on purpose: this one is asking to be read
    -- rather than acted in, so the screen it covers should stop competing for the eye.
    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, self.boxH, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, self.boxH, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, self.boxX, self.boxY + TITLE_TOP, BOX_W, "center")

    -- A rule under the title, the width of the words rather than the box: it separates the heading from
    -- the lesson without drawing a second frame inside the first one.
    Theme.set(Theme.frame)
    love.graphics.rectangle("fill", self.boxX + PAD, self.boxY + BODY_TOP - 22, BOX_W - PAD * 2, 1)

    -- LEFT-ALIGNED, unlike the placeholder's centred one-liner. This is prose to be read in order, and
    -- centred paragraphs give every line a different starting edge for the eye to find.
    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.ink)
    local y = self.boxY + BODY_TOP
    local lineH = self.bodyFont:getHeight()
    for line in (self.body .. "\n"):gmatch("([^\n]*)\n") do
        if line == "" then
            y = y + lineH * 0.6
        else
            love.graphics.printf(line, self.boxX + PAD, y, BOX_W - PAD * 2, "left")
            local _, wrapped = self.bodyFont:getWrap(line, BOX_W - PAD * 2)
            y = y + math.max(1, #wrapped) * lineH
        end
    end

    Theme.set(Theme.muted)
    local hint = InputMode.pick("A to continue", "Tap to continue", "Click, or press Enter to continue")
    love.graphics.printf(hint, self.boxX, self.boxY + self.boxH - 34, BOX_W, "center")

    self.closeButton:draw()

    love.graphics.setColor(1, 1, 1)
end

function TutorialNote:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
end

function TutorialNote:cursorKind(x, y)
    return self.closeButton:contains(x, y) and "hand" or "arrow"
end

function TutorialNote:mousepressed(x, y, button)
    if button ~= 1 then return end
    self.closeButton:mousepressed(x, y, button)
    self:close() -- read and dismissed: anywhere on the screen is the button
end

function TutorialNote:keypressed(key)
    if key == "escape" or key == "return" or key == "kpenter" or key == "space" then self:close() end
end

function TutorialNote:gamepadpressed(joystick, button)
    if button == "a" or button == "b" then self:close() end
end

return TutorialNote
