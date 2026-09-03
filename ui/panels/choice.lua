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
-- A KEEPER PANE is optional and additive: pass `keeper = { id=, name=, line=, gold=? }` and the box grows
-- a recessed column down its left carrying the counter's name (wearing its house mark, off `id`) and its
-- own sentence beneath -- the same shape every shelf in the city uses (ui/panels/cafe.lua,
-- ui/panels/hiring.lua, ui/panels/touchstone.lua). It is what lets a counter whose whole offer is one
-- yes-or-no still have a face behind it, without that counter growing a three-column panel it has no
-- content for. Callers that pass no keeper are laid out exactly as they were.
--
-- A PANE is the other optional column, and unlike the keeper this widget draws none of it: pass
-- `pane = { w=, h=, draw=function(x, y) end }` and the box grows a column of that size down its left,
-- calling back to paint it at the corner it reserved. It exists so a question ABOUT SOMETHING can carry
-- the something -- the shop's buy confirmation hands it the item's own hover tooltip (ui/item_tooltip.lua,
-- measure once at ask-time, paint here), so the reading the player was looking at when they pressed Buy
-- is still on screen while they answer, in the one shape items wear everywhere in this game. A caller
-- that already knows how to draw a thing should not have to teach this widget, and this widget should
-- not grow a dependency on the item layer to host a yes-or-no.
--
-- `keeper.gold` is the player's purse and it draws in the SAME PLACE it draws at every other counter:
-- the first amber line under the portrait, above the name, not tucked in beside the price. A counter that
-- charges is a counter where "can I afford the next one too" is the question being asked, and the answer
-- should be in the spot the player already looks at on the shelves rather than a spot per room. It is a
-- plain number the caller re-passes whenever it rebuilds the card, so spending is visible without this
-- widget holding a reference to the player.

local CloseButton = require("ui.close_button")
local InputMode = require("input_mode")
local Scale = require("scale")
local Theme = require("ui.theme")
local VendorIcons = require("ui.vendor_icons") -- the counter's mark, worn on its name

local Choice = {}
Choice.__index = Choice

local BOX_W = 500
local PAD = 26
-- The keeper column, sized to the strip the shelves use rather than to this box: a portrait the player
-- has learned to read at one size in four other rooms should not be smaller in the fifth.
local KEEPER_W = 260
local KEEPER_GAP = 22
-- Where a side column starts: under the title, level with the prompt, so the columns and the question
-- share a top edge.
local SIDE_TOP = 54
-- What the pane costs OUTSIDE its text: `pad * 2` (24) and the 54/22 margins the box keeps above and
-- below. Nothing else, because there is no picture in it any more.
--
-- IT WAS 456, back-solved so a portrait came out the same size here as at a shop counter (356 of picture
-- plus the pad and margins). That made a yes-or-no card -- a prompt and two options, barely 300px --
-- grow to 532 to hold a face that was never painted, and what actually stood in the space was a lettered
-- plate. The vendor portrait is gone everywhere (ui/vendor_icons.lua drawNamed), so the card is free to
-- be its natural height again and the pane is the name, the sentence and the purse.
local KEEPER_BASE_H = 100
local KEEPER_FOOT_H = 76
local KEEPER_GOLD_H = 24
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
    self.goldFont = Theme.body(15)
    self.lineFont = Theme.body(13)
    local keeperCol = self.keeper and (KEEPER_W + KEEPER_GAP) or 0
    self.keeperFootH = KEEPER_FOOT_H + ((self.keeper and self.keeper.gold) and KEEPER_GOLD_H or 0)

    -- The caller-drawn pane takes a column of its own, outboard of the keeper's, so a counter that has
    -- both a face and a thing on the table lays out as three columns rather than two overlapping ones.
    self.pane = opts.pane
    local paneCol = self.pane and (self.pane.w + KEEPER_GAP) or 0

    self.boxW = BOX_W + keeperCol + paneCol
    -- Prompt wraps above the options; height follows it.
    self.promptH = 0
    if self.prompt then
        -- Measured a written line at a time, so a prompt that breaks its own lines (the shop asks a
        -- price and then says what you already hold) is counted the way printf will draw it. Leaving
        -- the newlines to getWrap alone is a bet on which of the two it counts.
        local drawn = 0
        for line in (self.prompt .. "\n"):gmatch("([^\n]*)\n") do
            local _, wrapped = self.promptFont:getWrap(line, BOX_W - PAD * 2)
            drawn = drawn + math.max(1, #wrapped)
        end
        self.promptH = math.max(1, drawn) * self.promptFont:getHeight() + 12
    end
    self.optTop = 58 + self.promptH
    self.optH = opts.optionHeight or OPT_H
    local natural = self.optTop + #self.options * (self.optH + OPT_GAP) + 22
    self.boxH = natural
    -- What the side columns ask of the box's height, whichever asks for more.
    local sideH = 0
    if self.keeper then sideH = math.max(sideH, KEEPER_BASE_H + self.keeperFootH) end
    if self.pane then sideH = math.max(sideH, SIDE_TOP + self.pane.h + 22) end
    if sideH > 0 then
        self.boxH = math.max(natural, sideH)
        -- The slack the portrait bought is split above and below the stack rather than all dumped
        -- under it: options left hanging off the title read as a card that lost its bottom half.
        self.optTop = self.optTop + (self.boxH - natural) / 2
    end
    self.boxX = Scale.WIDTH / 2 - self.boxW / 2
    -- Centred, but never off the top: a pane is as tall as whatever the caller measured, and an item
    -- with a long ability reading can out-grow half the screen.
    self.boxY = math.max(8, Scale.HEIGHT / 2 - self.boxH / 2)
    self.closeButton = CloseButton.new(self.boxX + self.boxW, self.boxY)

    -- Everything that is not the portrait lives in a column of the card's own width, offset past it.
    self.colX = self.boxX + keeperCol + paneCol
    if self.pane then
        -- Centred against the column it was given, so a short reading sits in the middle of the card
        -- rather than hanging off its title.
        local room = self.boxH - SIDE_TOP - 22
        self.paneRect = {
            x = self.boxX + PAD, y = self.boxY + SIDE_TOP + math.max(0, (room - self.pane.h) / 2),
            w = self.pane.w, h = self.pane.h,
        }
    end
    if self.keeper then
        self.keeperRect = {
            x = self.boxX + PAD + paneCol, y = self.boxY + SIDE_TOP,
            w = KEEPER_W, h = self.boxH - SIDE_TOP - 22,
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
-- `keeper.id` names the house, and the only thing drawn off it is the mark on the name: that mark takes
-- the house's OWN colour (ui/vendor_icons.lua), which is why no counter here has to borrow a sin's hue --
-- the four that are not one of the seven have colours of their own in that same table.
function Choice:drawKeeper()
    local r = self.keeperRect
    if not r then return end

    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, Theme.R, Theme.R)

    local pad = 12
    local px, py = r.x + pad, r.y + pad
    local pw = r.w - pad * 2

    local ty = py
    -- THE PURSE, in the shelves' amber and the shelves' position: the pane's first line, so the number a
    -- player reads before every price in the city does not move because this counter sells beds.
    if self.keeper.gold then
        love.graphics.setFont(self.goldFont)
        Theme.set(Theme.accentAmber)
        love.graphics.print(self.keeper.gold .. " gold", px, ty)
        ty = ty + KEEPER_GOLD_H
    end
    -- The counter's NAME, wearing its house mark. This is the whole of the picture now: the pane used to
    -- fit a standing portrait above this line and the portrait was never drawn, so what stood there was a
    -- lettered plate 260px wide. The mark says which counter this is in a glyph, and it says it in the
    -- one place the name is already being read.
    if self.keeper.name then
        love.graphics.setFont(self.keeperFont)
        Theme.set(Theme.ink)
        VendorIcons.drawNamed(self.keeper.id,
            Theme.ellipsize(self.keeper.name, self.keeperFont, pw), self.keeperFont, px, ty, pw, "left")
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
    -- The caller's own column, painted at the corner reserved for it. Drawn before the options so a
    -- pane that measured taller than it drew cannot print over them.
    if self.pane and self.pane.draw then self.pane.draw(self.paneRect.x, self.paneRect.y) end

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
    -- A one-row card has nothing to walk between, and telling the player to walk it is the hint teaching
    -- a control that does nothing. Confirm and leave are the whole of it.
    local pad = InputMode.isGamepad()
    local hint
    if #self.options <= 1 then
        hint = (pad and "A confirm" or "Enter confirm") .. leaveHint
    else
        hint = (pad and "D-pad choose  -  A confirm" or "Arrows choose  -  Enter confirm") .. leaveHint
    end
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
