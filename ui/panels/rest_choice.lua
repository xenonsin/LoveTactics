-- Rest, as a decision. Opened when the player steps onto a Rest tile (states/game.lua's openEncounter).
-- A rest used to just refill the party; now it forces a choice between ways to spend the breather --
-- Heal the party, Sharpen a lasting combat edge, or Study the ground -- so a safe stop is a real weigh,
-- and the companions plug in (Amana strengthens Heal, Gyeom strengthens Study). One only; the others are
-- forgone. Modeled on ui/panels/loot_reveal.lua: a state owns it as game.activePanel and forwards input;
-- three-input + mouse-only.
--
--   RestChoice.new({ title=, onHeal=, onSharpen=, onStudy=, onBind=, onClose= })
--
-- BIND IS THE FOURTH AND IT IS NOT ALWAYS THERE. It sets a bone off every body carrying one
-- (models/wound.lua), and it is the only thing underground that does -- the surface used to have a
-- building for it and the price on that building is what took the building away. A wound is a condition
-- of the expedition now, so the way to shed one mid-dive has to be a DECISION with an alternative, which
-- is exactly the shape this panel already is: binding is taken instead of healing, sharpening or
-- studying.
--
-- Passed as a callback rather than gated in here, so the row draws only when somebody is actually
-- carrying a wound (states/game.lua asks Wound.wounded before it hands one over). A whole company is
-- told that binding is not on offer by the row not being there, which is the same rule every other
-- conditional control in the game draws under -- and it keeps this panel free of the wound model.
--
-- APPENDED RATHER THAN INSERTED, on purpose: the three that were always here keep their positions and
-- their accents, so a player who has learned "Heal is the top one" is never wrong. The row that comes
-- and goes is the one at the bottom, where its arrival cannot move anything else.

local CloseButton = require("ui.close_button")
local InputMode = require("input_mode")
local Scale = require("scale")
local Theme = require("ui.theme")

local RestChoice = {}
RestChoice.__index = RestChoice

local BOX_W = 460
local PAD = 26
local OPT_H = 78
local OPT_GAP = 12

-- Each option's accent, so they read apart at a glance: Heal jade (restore), Sharpen amber (power),
-- Study steel-blue (knowledge), Bind bone-pale (repair). Bind is deliberately NOT jade: it sits next to
-- Heal in the list and the two do different things to the same bar -- one fills it, one gives back the
-- part that would not fill -- so sharing a colour would be the panel saying they are the same offer.
local ACCENTS = {
    { 0.42, 0.80, 0.62 }, { 0.86, 0.66, 0.30 }, { 0.50, 0.68, 0.92 }, { 0.88, 0.83, 0.72 },
}

local function inRect(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function RestChoice.new(opts)
    opts = opts or {}
    local self = setmetatable({}, RestChoice)
    self.title = opts.title or "Make Camp"
    self.onClose = opts.onClose
    self.finished = false
    self.options = {
        { label = "Heal",    desc = "Restore the whole party to full health.",                 cb = opts.onHeal },
        { label = "Sharpen", desc = "Gain Honed Edge -- the front line opens every fight emboldened.", cb = opts.onSharpen },
        { label = "Study",   desc = "Lift the fog from the objective and every Reliquary.",     cb = opts.onStudy },
    }
    -- ...and the one that comes and goes. See the header: no wound in the company, no row.
    if opts.onBind then
        self.options[#self.options + 1] = { label = "Bind",
            desc = "Set one wound on everybody carrying one. The held-back part of their bar comes back.",
            cb = opts.onBind }
    end
    self.focus = 1

    self.titleFont = Theme.display(28)
    self.labelFont = Theme.display(20)
    self.descFont = Theme.body(14)
    self.hintFont = Theme.body(13)

    self.boxW = BOX_W
    self.boxH = 70 + #self.options * (OPT_H + OPT_GAP) + 24
    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - self.boxH / 2
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    for i, o in ipairs(self.options) do
        o.rect = {
            x = self.boxX + PAD, y = self.boxY + 60 + (i - 1) * (OPT_H + OPT_GAP),
            w = BOX_W - PAD * 2, h = OPT_H,
        }
    end
    return self
end

function RestChoice:choose(i)
    if self.finished then return end
    local o = self.options[i]
    if not o then return end
    self.finished = true
    if o.cb then o.cb() end
end

function RestChoice:close()
    if self.finished then return end
    self.finished = true
    if self.onClose then self.onClose() end
end

function RestChoice:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local bx, by = self.boxX, self.boxY
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, bx, by + 18, self.boxW, "center")

    for i, o in ipairs(self.options) do
        local r = o.rect
        local accent = ACCENTS[i]
        local focused = (i == self.focus)
        love.graphics.setColor(0.12, 0.13, 0.16, focused and 0.95 or 0.6)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 7, 7)
        love.graphics.setColor(accent[1], accent[2], accent[3], focused and 1 or 0.45)
        love.graphics.setLineWidth(focused and 2 or 1)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 7, 7)
        love.graphics.setLineWidth(1)
        -- Accent rail down the left edge.
        love.graphics.rectangle("fill", r.x, r.y, 4, r.h, 2, 2)

        love.graphics.setFont(self.labelFont)
        love.graphics.setColor(0.96, 0.95, 0.92)
        love.graphics.print(o.label, r.x + 18, r.y + 12)

        love.graphics.setFont(self.descFont)
        love.graphics.setColor(0.78, 0.80, 0.86)
        love.graphics.printf(o.desc, r.x + 18, r.y + 42, r.w - 34, "left")
    end

    local hint = InputMode.isGamepad() and "D-pad choose  -  A confirm  -  B leave"
        or "Arrows choose  -  Enter confirm  -  Esc leave"
    love.graphics.setFont(self.hintFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.printf(hint, bx, by + self.boxH - 22, self.boxW, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

function RestChoice:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    for i, o in ipairs(self.options) do
        if inRect(o.rect, x, y) then self.focus = i; break end
    end
end

function RestChoice:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    for _, o in ipairs(self.options) do if inRect(o.rect, x, y) then return "hand" end end
    return "arrow"
end

function RestChoice:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close(); return end
    for i, o in ipairs(self.options) do
        if inRect(o.rect, x, y) then self:choose(i); return end
    end
end

function RestChoice:moveFocus(d)
    self.focus = ((self.focus - 1 + d) % #self.options) + 1
end

function RestChoice:keypressed(key)
    if key == "escape" then self:close()
    elseif key == "up" or key == "w" then self:moveFocus(-1)
    elseif key == "down" or key == "s" then self:moveFocus(1)
    elseif key == "return" or key == "kpenter" or key == "space" then self:choose(self.focus) end
end

function RestChoice:gamepadpressed(_, button)
    if button == "b" then self:close()
    elseif button == "dpup" then self:moveFocus(-1)
    elseif button == "dpdown" then self:moveFocus(1)
    elseif button == "a" or button == "start" then self:choose(self.focus) end
end

return RestChoice
