-- A generic choice modal: a title, an optional prompt line, and 2-4 options, each a labelled card with a
-- description and a callback. The reusable shape behind the Crossroads dilemmas (models/crossroads.lua) --
-- ui/panels/rest_choice.lua is the same idea with fixed options; this one takes them as data. A state owns
-- it as game.activePanel and forwards input; three-input + mouse-only.
--
--   Choice.new({ title=, prompt=, options={ { label=, desc=?, accent=?, disabled=?, cb=fn }, ... },
--                keeper=?, onClose= })
--
-- Choosing an option fires its cb (and the panel is spent); onClose fires on X/Esc/B when a back-out is
-- allowed (pass nil to forbid leaving -- a committing choice).
--
-- A DISABLED OPTION IS DRAWN AND REFUSED, never hidden, and that is the one place this widget departs
-- from the board's rule that a control appears only where it can be used. On a board a move that is
-- rarely legal draws nothing until it is; here the option IS the room -- the Inn's whole offer is "take
-- the rooms" -- and a card that vanished when it could not be bought would leave a counter showing the
-- player nothing but the door out, with no line saying why they came. It stays, dimmed, wearing the
-- reason in its own description.
--
-- A KEEPER PANE is optional and additive: pass `keeper = { name=, sprite=, line= }` and the box grows a
-- recessed column down its left with the portrait fitted inside it, the counter's name under that and
-- its own sentence beneath -- the same shape every shelf in the city uses (ui/panels/cafe.lua,
-- ui/panels/hiring.lua, ui/panels/touchstone.lua). It is what lets a counter whose whole offer is one
-- yes-or-no still have a face behind it, without that counter growing a three-column panel it has no
-- content for. Callers that pass no keeper are laid out exactly as they were.

local CloseButton = require("ui.close_button")
local InputMode = require("input_mode")
local Scale = require("scale")
local Theme = require("ui.theme")

local Choice = {}
Choice.__index = Choice

local BOX_W = 500
local PAD = 26
-- The keeper column, sized to the strip the shelves use rather than to this box: a portrait the player
-- has learned to read at one size in four other rooms should not be smaller in the fifth.
local KEEPER_W = 260
local KEEPER_GAP = 22
-- The room a portrait needs to be a portrait, and it is NOT a number picked to look tall enough -- it is
-- back-solved from the shelves so the picture comes out the same size here as it does at a shop counter.
-- ui/panels/shop.lua fits its portrait into 236 x 356; this pane spends `pad * 2` (24) and a foot of 76
-- on the name and the line, so 356 + 24 + 76 + the 54/22 margins the box keeps above and below is 532.
--
-- IT WAS 360, and at 360 the same face was 196 x 184 -- a letterbox next to the shelves' standing
-- figure. A yes-or-no card is short (two options and a prompt is barely 300px) and a portrait fitted
-- into what is left over is always the thing that gets squeezed, which is why this height is fixed and
-- the card grows to meet it rather than the other way round.
local KEEPER_MIN_H = 532
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

    -- The keeper's own strip is spent on top of the card rather than out of it: the options keep the
    -- width they have everywhere else, so a caller that grows a face does not also get shorter rows.
    self.keeper = opts.keeper
    self.keeperFont = Theme.display(18)
    self.lineFont = Theme.body(13)
    local keeperCol = self.keeper and (KEEPER_W + KEEPER_GAP) or 0

    self.boxW = BOX_W + keeperCol
    -- Prompt wraps above the options; height follows it.
    self.promptH = 0
    if self.prompt then
        local _, lines = self.promptFont:getWrap(self.prompt, BOX_W - PAD * 2)
        self.promptH = math.max(1, #lines) * self.promptFont:getHeight() + 12
    end
    self.optTop = 58 + self.promptH
    self.optH = opts.optionHeight or OPT_H
    local natural = self.optTop + #self.options * (self.optH + OPT_GAP) + 22
    self.boxH = natural
    if self.keeper then
        self.boxH = math.max(natural, KEEPER_MIN_H)
        -- The slack the portrait bought is split above and below the stack rather than all dumped
        -- under it: options left hanging off the title read as a card that lost its bottom half.
        self.optTop = self.optTop + (self.boxH - natural) / 2
    end
    self.boxX = Scale.WIDTH / 2 - self.boxW / 2
    self.boxY = Scale.HEIGHT / 2 - self.boxH / 2
    self.closeButton = CloseButton.new(self.boxX + self.boxW, self.boxY)

    -- Everything that is not the portrait lives in a column of the card's own width, offset past it.
    self.colX = self.boxX + keeperCol
    if self.keeper then
        self.keeperRect = {
            x = self.boxX + PAD, y = self.boxY + 54,
            w = KEEPER_W, h = self.boxH - 54 - 22,
        }
    end

    for i, o in ipairs(self.options) do
        o.rect = {
            x = self.colX + PAD, y = self.boxY + self.optTop + (i - 1) * (self.optH + OPT_GAP),
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
    -- Refused, and the panel is NOT spent: a dead card must cost the player nothing, least of all the
    -- live one underneath it. See the disabled note in the header for why it is drawn at all.
    if o.disabled then return end
    self.finished = true
    if o.cb then o.cb() end
end

function Choice:close()
    if self.finished then return end
    if not self.onClose then return end -- a committing choice: X/Esc do nothing
    self.finished = true
    self.onClose()
end

-- THE KEEPER'S PANE, built to the shape every other counter in the city uses (ui/panels/cafe.lua,
-- ui/panels/hiring.lua, ui/panels/touchstone.lua): a recessed slot down the left with the portrait
-- fitted inside it, the counter's name under that and its own sentence beneath.
--
-- `keeper.sprite` is whatever models/sprite.lua handed the caller, which is an image when the art has
-- landed and the path string when it has not -- so the lettered plate below is the ordinary case for
-- now and not an error path. NO SIN TINT on it, the same call the Cafe and the Rift make for the same
-- reason: the seven houses each borrow their sin's hue, and a counter that is not one of the seven
-- wearing a borrowed colour would be the only thing in the game claiming it was.
function Choice:drawKeeper()
    local r = self.keeperRect
    if not r then return end

    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, Theme.R, Theme.R)

    local pad, footH = 12, 76
    local px, py = r.x + pad, r.y + pad
    local pw, ph = r.w - pad * 2, r.h - pad * 2 - footH

    local sprite = self.keeper.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(pw / sw, ph / sh)
        love.graphics.draw(sprite, px + pw / 2, py + ph / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        Theme.set(Theme.panel2)
        love.graphics.rectangle("fill", px, py, pw, ph, 8, 8)
        love.graphics.setFont(self.titleFont)
        Theme.set(Theme.ink, 0.55)
        love.graphics.printf((self.keeper.name or "?"):sub(1, 1), px, py + ph / 2 - 20, pw, "center")
    end

    local ty = py + ph + 10
    if self.keeper.name then
        love.graphics.setFont(self.keeperFont)
        Theme.set(Theme.ink)
        love.graphics.printf(Theme.ellipsize(self.keeper.name, self.keeperFont, pw), px, ty, pw, "left")
        ty = ty + self.keeperFont:getHeight() + 4
    end
    -- The counter's own sentence, read off its blueprint by the caller rather than written again here,
    -- so the keeper says the same thing wherever they are quoted.
    if self.keeper.line then
        love.graphics.setFont(self.lineFont)
        Theme.set(Theme.muted, 0.80)
        love.graphics.printf(self.keeper.line, px, ty, pw, "left")
    end
end

function Choice:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local bx, by = self.boxX, self.boxY
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)

    self:drawKeeper()

    local cx = self.colX
    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, cx, by + 16, BOX_W, "center")

    if self.prompt then
        love.graphics.setFont(self.promptFont)
        love.graphics.setColor(0.82, 0.83, 0.88)
        love.graphics.printf(self.prompt, cx + PAD, by + 50, BOX_W - PAD * 2, "center")
    end

    for i, o in ipairs(self.options) do
        local r = o.rect
        local accent = o.accent
        local focused = (i == self.focus)
        -- A dead card keeps its shape and loses its light: same plate, same accent hue, everything at
        -- roughly a third. It has to stay legible -- its description is the only place the reason it is
        -- dead is written -- while never once looking pressable.
        local dim = o.disabled and 0.34 or 1
        love.graphics.setColor(0.12, 0.13, 0.16, (focused and 0.95 or 0.6) * (o.disabled and 0.7 or 1))
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 7, 7)
        love.graphics.setColor(accent[1], accent[2], accent[3], (focused and 1 or 0.45) * dim)
        love.graphics.setLineWidth((focused and not o.disabled) and 2 or 1)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 7, 7)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("fill", r.x, r.y, 4, r.h, 2, 2)

        -- A bare option -- one whose label is the whole of it, like the shop's Buy / Cancel -- centers
        -- in its card instead of sitting at the top of an empty one. A dilemma with descriptions is
        -- laid out exactly as before.
        local hasDesc = o.desc and o.desc ~= ""
        love.graphics.setFont(self.labelFont)
        love.graphics.setColor(0.96, 0.95, 0.92, dim)
        love.graphics.print(o.label, r.x + 18,
            hasDesc and (r.y + 10) or (r.y + r.h / 2 - self.labelFont:getHeight() / 2))

        if hasDesc then
            love.graphics.setFont(self.descFont)
            -- The refusal is the one thing on a dead card that must still read, so it is dimmed less
            -- far than the label above it: a player looking at a row they cannot press is looking for
            -- exactly this line.
            love.graphics.setColor(0.78, 0.80, 0.86, o.disabled and 0.72 or 1)
            love.graphics.printf(o.desc, r.x + 18, r.y + 38, r.w - 34, "left")
        end
    end

    local leaveHint = self.onClose and (InputMode.isGamepad() and "  -  B leave" or "  -  Esc leave") or ""
    local hint = (InputMode.isGamepad() and "D-pad choose  -  A confirm" or "Arrows choose  -  Enter confirm") .. leaveHint
    love.graphics.setFont(self.hintFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.printf(hint, cx, by + self.boxH - 22, BOX_W, "center")

    if self.onClose then self.closeButton:draw() end
    love.graphics.setColor(1, 1, 1)
end

function Choice:mousemoved(x, y)
    if self.onClose then self.closeButton:mousemoved(x, y) end
    for i, o in ipairs(self.options) do if inRect(o.rect, x, y) then self.focus = i; break end end
end

function Choice:cursorKind(x, y)
    if self.onClose and self.closeButton:contains(x, y) then return "hand" end
    -- A dead card keeps the plain arrow: the pointer is the fastest thing the player has for finding
    -- out whether a row does anything, and it must not promise a press this row will refuse.
    for _, o in ipairs(self.options) do
        if inRect(o.rect, x, y) then return o.disabled and "arrow" or "hand" end
    end
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
