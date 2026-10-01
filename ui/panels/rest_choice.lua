-- Rest, as a decision. Opened when the player steps onto a Rest tile (states/game.lua's openEncounter).
-- A rest used to just refill the party; now it forces a choice between ways to spend the breather --
-- Heal the party, Sharpen a lasting combat edge, or Bind an injury -- so a safe stop is a real weigh.
-- One only; the others are forgone. Modeled on ui/panels/loot_reveal.lua: a state owns it as
-- game.activePanel and forwards input; three-input + mouse-only.
--
-- STUDY IS GONE (2026-10-01). It lifted the fog off the stair and opened the floor's secret doors, and
-- on a kept floor (Descent.keepFloor) both are already done by the second trip -- so the row paid
-- nothing on every camp but the first, while still drawing as a choice. game:restStudy survives: the
-- Crossroads dilemmas reach it through `ctx.reveal`.
--
--   RestChoice.new({ title=, onHeal=, onSharpen=, onBind=, onClose=,
--                    forecast = { { char=, from=, to=, max= }, ... },  -- Player.campForecast's rows
--                    fire = true })                                     -- a descent: the verbs light it
--
-- EVERY ROW COMES AND GOES NOW, Rest included: states/game.lua passes `onHeal` only when the camp would
-- move a bar, because a heal that moves nothing still lights the fire (Descent.lightFire) and buys a fight
-- for nothing. A company with nothing to rest off and nothing to bind is told so, and offered only the
-- way out.
--
-- BIND IS THE FOURTH AND IT IS NOT ALWAYS THERE. It sets a bone off every body carrying one
-- (models/injury.lua), and it is the only thing underground that does -- the surface used to have a
-- building for it and the price on that building is what took the building away. An injury is a condition
-- of the expedition now, so the way to shed one mid-dive has to be a DECISION with an alternative, which
-- is exactly the shape this panel already is: binding is taken instead of healing or sharpening.
--
-- Passed as a callback rather than gated in here, so the row draws only when somebody is actually
-- carrying an injury (states/game.lua asks Injury.injured before it hands one over). A whole company is
-- told that binding is not on offer by the row not being there, which is the same rule every other
-- conditional control in the game draws under -- and it keeps this panel free of the injury model.
--
-- APPENDED RATHER THAN INSERTED, on purpose: Heal keeps the top, so a player who has learned "Heal is
-- the top one" is never wrong. The row that comes and goes is the one at the bottom, where its arrival
-- cannot move anything else.

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
local FORECAST_LINE = 18 -- one line of the Rest row's forecast, two bodies to a line
local ARROW = "→"

-- Each option's accent, so they read apart at a glance: Heal jade (restore), Sharpen amber (power),
-- Bind bone-pale (repair). Bind is deliberately NOT jade: it sits next to Heal in the list and the two do
-- different things to the same bar -- one fills it, one gives back the part that would not fill -- so
-- sharing a colour would be the panel saying they are the same offer.
--
-- KEYED BY VERB, NOT BY ROW. This was a list indexed by position, which only held while every row was
-- always drawn: with Sharpen parked, Bind slid up a slot and wore another verb's colour.
local ACCENTS = {
    heal = { 0.42, 0.80, 0.62 }, sharpen = { 0.86, 0.66, 0.30 }, bind = { 0.88, 0.83, 0.72 },
}

local function inRect(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function RestChoice.new(opts)
    opts = opts or {}
    local self = setmetatable({}, RestChoice)
    self.title = opts.title or "Make Camp"
    self.onClose = opts.onClose
    self.finished = false
    self.options = {
    }
    -- REST, which was Heal and said "to full health" for a long time after Player.CAMP_SHARE made it half.
    -- The description says what the share is; the forecast under it says what it comes to, body by body,
    -- so the line cannot drift from the number again.
    if opts.onHeal then
        self.options[1] = { label = "Rest", accent = ACCENTS.heal,
            desc = "Get back half of what is missing: health, mana and stamina.",
            forecast = opts.forecast, cb = opts.onHeal }
    end
    -- SHARPEN COMES AND GOES NOW, for the Bind row's reason rather than its own. Its whole payload was
    -- Honed Edge, a run relic, and models/relic.lua is parked -- so the camp has nothing to hand over
    -- and states/game.lua passes no `onSharpen`. Made conditional rather than deleted: the row is three
    -- lines from working again the day the relic shelf comes back, and a fixed row whose callback is
    -- nil is a control that draws and does nothing, which is the one thing a camp menu must not do.
    if opts.onSharpen then
        table.insert(self.options, 2, { label = "Sharpen", accent = ACCENTS.sharpen,
            desc = "Gain Honed Edge -- the front line opens every fight emboldened.",
            cb = opts.onSharpen })
    end
    -- ...and the one that comes and goes. See the header: no injury in the company, no row.
    if opts.onBind then
        self.options[#self.options + 1] = { label = "Bind", accent = ACCENTS.bind,
            desc = "Set one injury on everybody carrying one. The held-back part of their bar comes back.",
            cb = opts.onBind }
    end
    self.focus = 1

    self.titleFont = Theme.display(28)
    self.labelFont = Theme.display(20)
    self.descFont = Theme.body(14)
    self.hintFont = Theme.body(13)

    -- WHAT THE VERBS COST, stated before any row is pressed: in a descent, every one of them lights the
    -- fire, and the next step out of camp throws a fight (Descent.lightFire). Not a percent -- it always
    -- happens -- so the line is a forecast, in the future tense, rather than odds. Drawn only when there
    -- is a verb to pay it with.
    self.fire = (opts.fire and #self.options > 0) or nil

    -- THE BAND EXISTS ONLY WHEN THE LINE DOES, and the rows and the box height both move with it. A
    -- panel that reserves a gap for a sentence it is not going to print reads as a layout with
    -- something missing out of it; the host owns the rect, so it grows rather than overlaps. The same
    -- holds for the empty camp's one line, and for the Rest row, which grows by its forecast.
    local fireBand = (self.fire or #self.options == 0) and 22 or 0

    local total = 0
    for _, o in ipairs(self.options) do
        o.h = OPT_H + (o.forecast and (math.ceil(#o.forecast / 2) * FORECAST_LINE + 4) or 0)
        total = total + o.h + OPT_GAP
    end

    self.boxW = BOX_W
    self.boxH = 70 + fireBand + total + 24
    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - self.boxH / 2
    self.fireY = self.boxY + 56
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    local y = self.boxY + 60 + fireBand
    for _, o in ipairs(self.options) do
        o.rect = { x = self.boxX + PAD, y = y, w = BOX_W - PAD * 2, h = o.h }
        y = y + o.h + OPT_GAP
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

    -- THE FIRE, in the future tense and in the warning colour, because it describes something that has
    -- not happened yet. It names the fight, not a chance of one: there is no roll left to quote.
    love.graphics.setFont(self.hintFont)
    if self.fire then
        Theme.set(Theme.accentWeapon)
        love.graphics.printf("The fire will draw the floor. Something will find you on your next step.",
            bx, self.fireY, self.boxW, "center")
    elseif #self.options == 0 then
        Theme.set(Theme.muted)
        love.graphics.printf("The company is whole. There is nothing to rest off.",
            bx, self.fireY, self.boxW, "center")
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
        -- Accent rail down the left edge.
        love.graphics.rectangle("fill", r.x, r.y, 4, r.h, 2, 2)

        love.graphics.setFont(self.labelFont)
        love.graphics.setColor(0.96, 0.95, 0.92)
        love.graphics.print(o.label, r.x + 18, r.y + 12)

        love.graphics.setFont(self.descFont)
        love.graphics.setColor(0.78, 0.80, 0.86)
        love.graphics.printf(o.desc, r.x + 18, r.y + 42, r.w - 34, "left")

        -- THE FORECAST, two bodies to a line: a name, then where the camp takes them, "16 -> 28". Read
        -- off the same loop the camp runs (Player.campForecast), so it is the number that lands.
        if o.forecast then
            love.graphics.setFont(self.hintFont)
            local colW = (r.w - 34) / 2
            for k, f in ipairs(o.forecast) do
                local cx = r.x + 18 + ((k - 1) % 2) * colW
                local cy = r.y + OPT_H - 6 + math.floor((k - 1) / 2) * FORECAST_LINE
                love.graphics.setColor(0.78, 0.80, 0.86)
                love.graphics.print((f.char and f.char.name) or "?", cx, cy)
                if f.to > f.from then love.graphics.setColor(accent[1], accent[2], accent[3]) end
                love.graphics.printf(f.from .. " " .. ARROW .. " " .. f.to, cx, cy, colW - 14, "right")
            end
        end
    end

    local hint = InputMode.pick("D-pad choose  -  A confirm  -  B leave", nil,
        "Arrows choose  -  Enter confirm  -  Esc leave")
    if hint then
        love.graphics.setFont(self.hintFont)
        love.graphics.setColor(0.55, 0.6, 0.7)
        love.graphics.printf(hint, bx, by + self.boxH - 22, self.boxW, "center")
    end

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
    if #self.options == 0 then return end
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
