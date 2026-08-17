-- A generic choice modal: a title, an optional prompt line, and 2-4 options, each a labelled card with a
-- description and a callback. The reusable shape behind the Crossroads dilemmas (models/crossroads.lua) --
-- ui/panels/rest_choice.lua is the same idea with fixed options; this one takes them as data. A state owns
-- it as game.activePanel and forwards input; three-input + mouse-only.
--
--   Choice.new({ title=, prompt=, options={ { label=, desc=?, accent=?, cb=fn }, ... }, onClose= })
--
-- Choosing an option fires its cb (and the panel is spent); onClose fires on X/Esc/B when a back-out is
-- allowed (pass nil to forbid leaving -- a committing choice).

local CloseButton = require("ui.close_button")
local InputMode = require("input_mode")
local Scale = require("scale")
local Theme = require("ui.theme")

local Choice = {}
Choice.__index = Choice

local BOX_W = 500
local PAD = 26
-- A card's height, and the reason it is a default rather than a constant. 70 holds a label and ONE line of
-- description, which is what a dilemma's options are (models/crossroads.lua) -- a second line lands with
-- its descenders across the card's bottom border. A caller whose rows have more to say than that passes
-- `optionHeight` and gets the room instead of writing shorter, less useful rows: the descent's recruit
-- stop describes a body in two lines (states/game.lua), because what a body is worth is what it can take
-- and what it fights with, and neither half is decoration.
local OPT_H = 70
local OPT_GAP = 12

-- A rotating accent set so options read apart when a dilemma doesn't name its own.
local ACCENTS = { { 0.50, 0.68, 0.92 }, { 0.86, 0.66, 0.30 }, { 0.42, 0.80, 0.62 }, { 0.80, 0.52, 0.92 } }

local function inRect(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function Choice.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Choice)
    self.title = opts.title or "Choose"
    self.prompt = opts.prompt
    self.options = opts.options or {}
    self.onClose = opts.onClose
    self.finished = false
    self.focus = 1

    self.titleFont = Theme.display(28)
    self.promptFont = Theme.body(15)
    self.labelFont = Theme.display(19)
    self.descFont = Theme.body(14)
    self.hintFont = Theme.body(13)

    self.boxW = BOX_W
    -- Prompt wraps above the options; height follows it.
    self.promptH = 0
    if self.prompt then
        local _, lines = self.promptFont:getWrap(self.prompt, BOX_W - PAD * 2)
        self.promptH = math.max(1, #lines) * self.promptFont:getHeight() + 12
    end
    self.optTop = 58 + self.promptH
    self.optH = opts.optionHeight or OPT_H
    self.boxH = self.optTop + #self.options * (self.optH + OPT_GAP) + 22
    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - self.boxH / 2
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    for i, o in ipairs(self.options) do
        o.rect = {
            x = self.boxX + PAD, y = self.boxY + self.optTop + (i - 1) * (self.optH + OPT_GAP),
            w = BOX_W - PAD * 2, h = self.optH,
        }
        o.accent = o.accent or ACCENTS[(i - 1) % #ACCENTS + 1]
    end
    return self
end

function Choice:choose(i)
    if self.finished then return end
    local o = self.options[i]
    if not o then return end
    self.finished = true
    if o.cb then o.cb() end
end

function Choice:close()
    if self.finished then return end
    if not self.onClose then return end -- a committing choice: X/Esc do nothing
    self.finished = true
    self.onClose()
end

function Choice:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local bx, by = self.boxX, self.boxY
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, bx, by + 16, self.boxW, "center")

    if self.prompt then
        love.graphics.setFont(self.promptFont)
        love.graphics.setColor(0.82, 0.83, 0.88)
        love.graphics.printf(self.prompt, bx + PAD, by + 50, self.boxW - PAD * 2, "center")
    end

    for i, o in ipairs(self.options) do
        local r = o.rect
        local accent = o.accent
        local focused = (i == self.focus)
        love.graphics.setColor(0.12, 0.13, 0.16, focused and 0.95 or 0.6)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 7, 7)
        love.graphics.setColor(accent[1], accent[2], accent[3], focused and 1 or 0.45)
        love.graphics.setLineWidth(focused and 2 or 1)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 7, 7)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("fill", r.x, r.y, 4, r.h, 2, 2)

        -- A bare option -- one whose label is the whole of it, like the shop's Buy / Cancel -- centers
        -- in its card instead of sitting at the top of an empty one. A dilemma with descriptions is
        -- laid out exactly as before.
        local hasDesc = o.desc and o.desc ~= ""
        love.graphics.setFont(self.labelFont)
        love.graphics.setColor(0.96, 0.95, 0.92)
        love.graphics.print(o.label, r.x + 18,
            hasDesc and (r.y + 10) or (r.y + r.h / 2 - self.labelFont:getHeight() / 2))

        if hasDesc then
            love.graphics.setFont(self.descFont)
            love.graphics.setColor(0.78, 0.80, 0.86)
            love.graphics.printf(o.desc, r.x + 18, r.y + 38, r.w - 34, "left")
        end
    end

    local leaveHint = self.onClose and (InputMode.isGamepad() and "  -  B leave" or "  -  Esc leave") or ""
    local hint = (InputMode.isGamepad() and "D-pad choose  -  A confirm" or "Arrows choose  -  Enter confirm") .. leaveHint
    love.graphics.setFont(self.hintFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.printf(hint, bx, by + self.boxH - 22, self.boxW, "center")

    if self.onClose then self.closeButton:draw() end
    love.graphics.setColor(1, 1, 1)
end

function Choice:mousemoved(x, y)
    if self.onClose then self.closeButton:mousemoved(x, y) end
    for i, o in ipairs(self.options) do if inRect(o.rect, x, y) then self.focus = i; break end end
end

function Choice:cursorKind(x, y)
    if self.onClose and self.closeButton:contains(x, y) then return "hand" end
    for _, o in ipairs(self.options) do if inRect(o.rect, x, y) then return "hand" end end
    return "arrow"
end

function Choice:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.onClose and self.closeButton:mousepressed(x, y, button) then self:close(); return end
    for i, o in ipairs(self.options) do if inRect(o.rect, x, y) then self:choose(i); return end end
end

function Choice:moveFocus(d)
    if #self.options == 0 then return end
    self.focus = ((self.focus - 1 + d) % #self.options) + 1
end

function Choice:keypressed(key)
    if key == "escape" then self:close()
    elseif key == "up" or key == "w" then self:moveFocus(-1)
    elseif key == "down" or key == "s" then self:moveFocus(1)
    elseif key == "return" or key == "kpenter" or key == "space" then self:choose(self.focus) end
end

function Choice:gamepadpressed(_, button)
    if button == "b" then self:close()
    elseif button == "dpup" then self:moveFocus(-1)
    elseif button == "dpdown" then self:moveFocus(1)
    elseif button == "a" or button == "start" then self:choose(self.focus) end
end

return Choice
