-- THE CROSSING: a tear in a city that already has one, and the single button that opens it.
--
-- IT DEALS, AND IT DEALS BLIND. That is a reversal of what this room used to be and the reversal is
-- the point, so here is what it was: a Hiring Hall whose whole stock was THE PEOPLE YOU HAD WALKED
-- PAST on a floor -- a consequence rather than a shop, and a hire was never somebody the player had
-- not already stood in front of and refused. Every word of that argument still reads well and the
-- room it produced was empty. A refusal only happened at a floor stop, a stop only seated while the
-- company had ROOM, and a company of four never lost anybody -- so from the second floor of the first
-- run there were no refusals left to stock it with, and the hall said "the company is full" forever.
-- Forty-five authored bodies; three of them ever met.
--
-- So the descent hands up TOKENS now (models/voucher.lua) and this is where one is spent.
--
-- IT SHOWS NO RATES AND NO PITY COUNT, and that is a decision rather than an omission. The genre puts
-- both on the summon screen and the argument for doing so is real -- published odds buy trust, and a
-- pity track gives a bad streak a visible end. What they also do is turn the room into a spreadsheet
-- you consult before pressing a button, and this room is thirty seconds long. A player who can read
-- "5%" off a legend is a player deciding whether the crossing is worth it; a player who cannot is a
-- player who just opens the tear. The second one is having a better time, and nothing here is sold
-- for money, so none of the machinery that makes those readouts ethically necessary applies.
--
-- WHAT IT IS INSTEAD IS ONE BUTTON, DRESSED. Not a list with the exit weighted the same as the only
-- thing you came in to do -- this was a two-row ui/panels/choice.lua card, and "Leave" sat there at
-- identical size to the act the building exists for. The way out is the close corner, where every
-- other modal in the game keeps it (ui/close_button.lua), and the middle of the room is the plate you
-- press.
--
-- The plate carries a verb and nothing else. Not the rank it is spending -- a token has none -- and not
-- who is behind it, because the pool is forty-five deep and naming any of it would turn the reveal into
-- a confirmation of something already read. A hairline fracture runs across the plate, which is the one
-- piece of ornament in here and is not ornament: it is the thing the button does, drawn small.
--
-- AND WITH NO TOKEN THERE IS NO BUTTON. Not a greyed one -- a control draws only where it is legal,
-- and a dead plate in the middle of an empty room is an invitation the room cannot honour. What stands
-- there instead is the sentence saying where tokens come from, which is the one thing a player looking
-- at an empty rift actually needs.

local CloseButton = require("ui.close_button")
local Debug = require("models.debug")
local Sprite = require("models.sprite")
local Vendor = require("models.vendor") -- only for the keeper's portrait, name and pitch
local HireReveal = require("ui.panels.hire_reveal")
local InputMode = require("input_mode")
local Player = require("models.player")
local Scale = require("scale")
local Sound = require("models.sound")
local Theme = require("ui.theme")
local Voucher = require("models.voucher")

local Hiring = {}
Hiring.__index = Hiring

-- Wider than it was, because the keeper's pane took a strip out of the left and the plate must not
-- have to shrink to pay for it.
local BOX_W = 780
local PAD = 28
local BTN_W, BTN_H = 340, 104

-- THE KEEPER'S PANE, AT THE CITY'S OWN MEASUREMENTS. These three numbers are not chosen here -- they
-- are copied verbatim off ui/panels/shop.lua and ui/panels/cafe.lua, which both lay their shopkeeper
-- out at exactly `boxX + 24, boxY + 64, 260 wide`. A portrait a different size to every other
-- portrait in the city is the one thing that makes a panel read as belonging to a different game, and
-- it was 168 here until somebody stood the two panels side by side.
--
-- If those panels ever move, this moves with them: three counters agreeing by copy is a convention, and
-- the day it needs to be a shared constant is the day a fourth one disagrees.
local KEEPER_X, KEEPER_Y, KEEPER_W = 24, 64, 260
-- ...AND AT THEIR HEIGHT TOO, which the width alone did not buy. The shop's pane runs from `boxY + 64`
-- to 44 short of the bottom of a 580-tall box -- 472 -- and spends `pad * 2` (24) and a 92-high foot on
-- the purse and the counter's line, which fits the portrait into 236 x 356.
--
-- THIS ROOM IS SHORT AND THE PORTRAIT PAID FOR IT. The floor here was 236, which is the whole PANE, so
-- the picture inside it came out 236 x 120 -- a letterbox beside the standing figure four other counters
-- draw. A face is the one thing in a panel that has to be the same face everywhere, so the height is
-- fixed at the shelves' and the box grows to meet it rather than the portrait shrinking to fit the box.
local KEEPER_PANE_H = 472
-- The dev row's little squares. Small enough that they never compete with the plate above them.
local DBG_W, DBG_H, DBG_GAP = 30, 24, 6

local function inRect(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- A TOKEN DOES NOT SAY WHAT IT IS WORTH, and that is the room's whole posture rather than an
-- oversight. The plate used to wear the rank as pips and name it again underneath ("spends the
-- four-star token"), which made the crossing a transaction: you read the grade, you weighed whether it
-- was worth it, and the reveal was confirming a number you already had.
--
-- What is hidden is the TOKEN's rank. What is not hidden is the BODY's -- the stars strike in during
-- the reveal and the card names them (ui/panels/hire_reveal.lua), because that is the payoff and it is
-- the one number the player is meant to end up holding. Grading the ticket as well would tell them the
-- answer on the way in.
--
-- It is the same call as showing no rates and no pity count (see the header): a player who cannot
-- price the crossing is a player who just opens the rift, and nothing here is sold for money, so there
-- is no reason they should have to.

function Hiring.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Hiring)
    self.opts = opts
    self.player = opts.player or Player.active
    self.title = opts.title or "The Crossing"
    self.finished = false
    self.t = 0        -- free-running, for the plate's breath
    self.hover = false
    self.notice = nil -- what the last crossing left behind, shown in place of the prompt once

    self.titleFont = Theme.display(28)
    self.promptFont = Theme.body(15)
    self.verbFont = Theme.display(24)
    self.subFont = Theme.body(12)
    self.hintFont = Theme.body(13)

    -- THE KEEPER. Every other counter in the city has a face behind it -- the Cafe, the Touchstone and
    -- all seven houses draw a portrait pane down the left of their panel -- and this room was the one
    -- that did not, which made it read as a machine rather than as a place with somebody in it.
    --
    -- Read off the vendor blueprint (data/vendors/crossing.lua) rather than pointed at directly,
    -- because that is where every other panel gets its shopkeeper and it is the seam the first-visit
    -- greeting hangs off too. Sprite.load is tolerant -- a missing file comes back as its own path
    -- string -- so the pane falls back to a lettered plate and the art can land later.
    self.def = (opts.vendor and Vendor.get(opts.vendor)) or Vendor.get("crossing") or {}
    self.keeper = Sprite.load(self.def.sprite)

    self:layout()
    return self
end

-- Measured off the prompt, so a two-line sentence and a four-line one both sit properly in the box
-- rather than one of them colliding with the plate.
function Hiring:layout()
    local best = Voucher.count(self.player) > 0
    self.best = best

    local prompt = self.notice or (best
        and "A token holds it open long enough for one of them to come through. Which one is not " ..
            "yours to say."
        or "Nothing to open it with. A circle beaten below hands one up, a spirit on every floor holds " ..
           "one out, and now and then a body falls with one on it.")
    self.prompt = prompt

    -- THE COLUMN RIGHT OF THE KEEPER is what everything below measures against, not the whole box.
    -- The portrait pane owns a fixed strip down the left, and the column starts one gutter past it --
    -- the same `vendorX + vendorW + 24` the shop and the Cafe use for their lists.
    local colW = BOX_W - (KEEPER_X + KEEPER_W + 24) - 24
    local _, lines = self.promptFont:getWrap(prompt, colW)
    local promptH = math.max(1, #lines) * self.promptFont:getHeight()

    -- Clear of the title, which spans the WHOLE box rather than this column -- the shape the Cafe and
    -- the shops use, where the counter is named once across the top and the keeper stands underneath.
    self.oPrompt = KEEPER_Y + 8
    local afterPrompt = self.oPrompt + promptH + 22

    if best then
        self.oButton = afterPrompt
        self.oSub = self.oButton + BTN_H + 12
        self.boxH = self.oSub + self.subFont:getHeight() + 16 + self.hintFont:getHeight() + PAD
    else
        self.oButton = nil
        self.oSub = nil
        self.boxH = afterPrompt + self.hintFont:getHeight() + PAD
    end
    -- A floor under the box, so the keeper always has room to stand at the size it stands everywhere
    -- else (KEEPER_PANE_H). This room is a sentence and one plate, so the floor is what sets the height
    -- every time -- the box is sized by its portrait rather than by its content, and that is deliberate.
    --
    -- THE SLACK GOES TO THE PLATE AND NOT TO THE SENTENCE, which is exactly how ui/panels/choice.lua
    -- spends it for the Inn: the prompt keeps its place under the title, where a room's own line belongs,
    -- and the thing you press floats to the middle of the column so it sits opposite the portrait's face
    -- rather than hanging off the title with half a card of nothing under it.
    --
    -- BEFORE the hint is placed, not after, which is the bug this ordering fixes: the hint anchors to
    -- the bottom margin, so computing it against the pre-floor height stranded "Esc leave" halfway up
    -- an empty column with a hand's width of nothing under it.
    local floorH = KEEPER_Y + KEEPER_PANE_H + 24
    if self.boxH < floorH then
        local slack = (floorH - self.boxH) / 2
        if self.oButton then self.oButton = self.oButton + slack end
        if self.oSub then self.oSub = self.oSub + slack end
        self.boxH = floorH
    end
    self.oHint = self.boxH - PAD - self.hintFont:getHeight() + 4

    self.boxW = BOX_W
    self.boxX = (Scale.WIDTH - self.boxW) / 2
    self.boxY = (Scale.HEIGHT - self.boxH) / 2

    self.colX = self.boxX + KEEPER_X + KEEPER_W + 24
    self.colW = colW

    -- The pane starts UNDER the title and runs to the bottom margin, which is how the Cafe and the
    -- shops lay theirs out: named once across the top, keeper standing beneath the name.
    self.keeperRect = {
        x = self.boxX + KEEPER_X, y = self.boxY + KEEPER_Y,
        w = KEEPER_W, h = self.boxH - KEEPER_Y - 24,
    }

    if self.oButton then
        self.btn = {
            x = self.colX + (colW - BTN_W) / 2,
            y = self.boxY + self.oButton,
            w = BTN_W, h = BTN_H,
        }
    else
        self.btn = nil
    end

    -- THE DEV BUTTONS: one small square per rank, clickable as well as keyed. A keybind alone is a
    -- tool you have to remember; a row of buttons is one you find by opening the room, which is the
    -- difference between a debug affordance that gets used and one that gets rebuilt every few months
    -- because nobody knew it was there.
    --
    -- PINNED TO THE SCREEN, NOT TO THE CARD, and that is not tidiness -- it is the one thing that
    -- makes the row usable. Inside the box it moved every time it was pressed: minting the first token
    -- makes the plate appear, the box grows, the row slides down, and the second click of a run of
    -- five lands on nothing. Minting several quickly is the entire workflow this exists for.
    --
    -- Off the card also says what it is more loudly than the colour does: this is not part of the
    -- room, it is a tool laid over the screen.
    self.dbgBtns = nil
    if Debug.enabled then
        self.dbgBtns = {}
        local total = Voucher.MAX_STARS * DBG_W + (Voucher.MAX_STARS - 1) * DBG_GAP
        local x0 = (Scale.WIDTH - total) / 2
        local y0 = Scale.HEIGHT - DBG_H - 26
        for i = 1, Voucher.MAX_STARS do
            self.dbgBtns[i] = {
                x = x0 + (i - 1) * (DBG_W + DBG_GAP), y = y0,
                w = DBG_W, h = DBG_H, stars = i,
            }
        end
        self.dbgLabelY = y0 - self.subFont:getHeight() - 4
    end

    self.closeButton = CloseButton.new(self.boxX + self.boxW, self.boxY)
end

function Hiring:update(dt)
    self.t = self.t + (dt or 0)
end

-- ---- the act -----------------------------------------------------------------

function Hiring:open()
    if self.finished or not self.best then return end
    local result = Voucher.pull(self.player)
    Player.save()
    if not result then
        self.notice = "The tear opens on nothing. The token is spent."
        self:layout()
        return
    end

    -- THE REVEAL TAKES THE SCREEN and this panel steps aside under it rather than drawing behind it:
    -- the room is not information while a body is coming through. The re-layout on the way back out is
    -- what re-reads the purse, so a player who crosses three times running watches the count fall
    -- without leaving the room.
    if self.opts.onReveal then
        self.opts.onReveal(HireReveal.new({
            result = result,
            -- WHERE THE RIFT OPENS: the descent's own card, handed down by the state that knows the
            -- map (states/hub.lua). The city has one wound in it, and a crossing is that wound being
            -- forced open rather than a light parked in the middle of the screen.
            rect = self.opts.riftRect and self.opts.riftRect() or nil,
            -- The staked crossing plays in full -- it is the one the tutorial is teaching with. Every
            -- crossing after it can be skipped from the first frame.
            hold = self.opts.hold == true,
            onClose = function()
                if self.opts.onRevealClosed then self.opts.onRevealClosed() end
                self.notice = result.dupe
                    and ((result.name or "They") .. " came back to you.")
                    or ((result.name or "Somebody") .. " comes through.")
                self:layout()
            end,
        }))
    else
        self.notice = (result.name or "Somebody") .. " comes through."
        self:layout()
    end
end

function Hiring:close()
    if self.finished then return end
    self.finished = true
    if self.opts.onClose then self.opts.onClose() end
end

-- MINT A TOKEN, for development only. 1..5 hand the purse a token of that rank so a reveal can be
-- driven at any rank on demand -- which is the whole reason this exists: the honest way to see a
-- five-star crossing is to beat seven circles, and tuning an animation you can only reach after an
-- hour of play is tuning it blind.
--
-- IT LIVES HERE rather than in the main menu's debug column or the battle's right-click menu, because
-- this is the room you are standing in when you want one. A resource you have to leave the building to
-- grant is a resource you grant once and then stop testing with.
--
-- A TOKEN HAS NO RANK to mint, so the key mints a token AND rigs the next pull to that rank
-- (`player.debugRank`, read by Voucher.peek). That is the only honest way to test a five-star reveal:
-- the odds put one at two percent, and tuning an animation you reach twice an hour is tuning it blind.
--
-- `Debug.enabled` is the build constant, not a runtime flag (models/debug.lua): a shipping build has
-- no key here and no line saying there is one.
function Hiring:debugGrant(stars)
    if not Debug.enabled then return end
    Voucher.grant(self.player, 1)
    self.player.debugRank = stars
    Player.save()
    self.notice = nil
    self:layout()
end

-- ---- drawing -----------------------------------------------------------------

-- The hairline running across the plate. The one piece of ornament in this room, and it is the thing
-- the button DOES drawn small -- a crack, angular and off-centre, in the same family as the fracture
-- the reveal opens (ui/panels/hire_reveal.lua). Authored offsets rather than rolled, so it is the same
-- crack every visit.
local SEAM = { 0.00, -0.26, 0.14, -0.10, 0.30, -0.18, 0.08, 0.00 }

function Hiring:drawSeam(b, alpha)
    love.graphics.setLineWidth(1)
    Theme.set(Theme.accentAmber, alpha)
    local n = #SEAM
    local prevX, prevY
    for i = 1, n do
        local f = (i - 1) / (n - 1)
        local x = b.x + 22 + (b.w - 44) * f
        local y = b.y + b.h * 0.76 + SEAM[i] * b.h * 0.20
        if prevX then love.graphics.line(prevX, prevY, x, y) end
        prevX, prevY = x, y
    end
end

function Hiring:drawButton()
    local b = self.btn
    if not b then return end

    -- The breath: a slow rise and fall so the plate reads as live rather than as a printed rectangle.
    -- Small on purpose -- a button that pulses hard is a button that nags.
    local breath = 0.5 + 0.5 * math.sin(self.t * 1.9)
    local lit = self.hover and 1 or 0

    -- The glow behind it, additive so it brightens rather than washing to grey.
    love.graphics.setBlendMode("add")
    for i = 5, 1, -1 do
        local t = i / 5
        Theme.set(Theme.accentAmber, (0.020 + 0.026 * breath + 0.030 * lit) * (1 - t * 0.7))
        love.graphics.rectangle("fill", b.x - 14 * t, b.y - 14 * t,
            b.w + 28 * t, b.h + 28 * t, 4)
    end
    love.graphics.setBlendMode("alpha")

    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 3)
    Theme.set(Theme.accentAmber, 0.09 + 0.05 * breath + 0.07 * lit)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 3)

    self:drawSeam(b, 0.16 + 0.10 * breath + 0.14 * lit)

    Theme.set(Theme.accentAmber, 0.80 + 0.20 * lit)
    love.graphics.setLineWidth(1.6)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 3)
    love.graphics.setLineWidth(1)

    -- NO RANK ON THE PLATE. It wore five pips until the day somebody read them and decided not to
    -- press. The verb is centred on the plate now rather than
    -- sitting under a row of stars, which is also simply a better button.
    love.graphics.setFont(self.verbFont)
    Theme.set(Theme.ink, 0.92 + 0.08 * lit)
    love.graphics.printf("Open it", b.x, b.y + (b.h - self.verbFont:getHeight()) / 2, b.w, "center")
end

-- THE KEEPER'S PANE, built to the shape every other counter in the city uses (ui/panels/cafe.lua,
-- ui/panels/shop.lua): a recessed slot down the left with the portrait fitted inside it and the
-- counter's own line printed underneath.
--
-- NO SIN TINT on the fallback plate, and that is the same call the Cafe makes for the same reason:
-- the seven houses each borrow their sin's hue, and this is not one of the seven. A borrowed colour
-- would be the only thing in the game ever claiming it was.
function Hiring:drawKeeper()
    local r = self.keeperRect
    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, Theme.R, Theme.R)

    local pad = 12
    -- The strip under the portrait, at the shop panel's own reserve (`portraitH = h - 92`), so the
    -- picture itself is the same size and shape here as on every other counter.
    local pitchH = 92
    local px, py = r.x + pad, r.y + pad
    local pw, ph = r.w - pad * 2, r.h - pad * 2 - pitchH

    if type(self.keeper) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = self.keeper:getDimensions()
        local scale = math.min(pw / sw, ph / sh)
        love.graphics.draw(self.keeper, px + pw / 2, py + ph / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        -- Art has not landed: a lettered plate, which is what every other counter falls back to
        -- (models/sprite.lua hands back the path string rather than crashing).
        Theme.set(Theme.panel2)
        love.graphics.rectangle("fill", px, py, pw, ph, 8, 8)
        love.graphics.setFont(self.titleFont)
        Theme.set(Theme.ink, 0.55)
        love.graphics.printf((self.def.name or "?"):sub(1, 1), px, py + ph / 2 - 20, pw, "center")
    end

    -- The counter's own sentence, off the blueprint rather than written again here, so the keeper says
    -- the same thing wherever they are quoted.
    --
    -- CENTRED IN THE FOOT rather than hung off the portrait, because this counter does not fill the foot
    -- the shelves do. Their 92 holds a purse, an errand tally and a line; here there is only the line, and
    -- pinning it to the top of the strip left a hand's width of empty pane under it. The strip stays the
    -- shelves' size -- the portrait above it is what that number is protecting -- and the sentence sits in
    -- the middle of what is left.
    if self.def.description then
        love.graphics.setFont(self.subFont)
        Theme.set(Theme.muted, 0.80)
        local top = py + ph + 10
        local _, wrapped = self.subFont:getWrap(self.def.description, pw)
        local textH = #wrapped * self.subFont:getHeight()
        local slack = math.max(0, (r.y + r.h - pad) - top - textH)
        love.graphics.printf(self.def.description, px, top + slack / 2, pw, "center")
    end
end

function Hiring:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local bx, by = self.boxX, self.boxY
    Theme.plate(bx, by, self.boxW, self.boxH, Theme.R)

    self:drawKeeper()

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, bx, by + 18, self.boxW, "center")

    love.graphics.setFont(self.promptFont)
    Theme.set(Theme.muted)
    love.graphics.printf(self.prompt, self.colX, by + self.oPrompt, self.colW, "center")

    self:drawButton()

    if self.oSub then
        -- HOW MANY, and nothing else. It said which rank it was about to spend until tokens stopped
        -- having one: a count is now the whole truth about a purse.
        local held = Voucher.count(self.player)
        local line = held == 1 and "One token" or (held .. " tokens")
        love.graphics.setFont(self.subFont)
        Theme.set(Theme.muted, 0.75)
        love.graphics.printf(line, self.colX, by + self.oSub, self.colW, "center")
    end

    love.graphics.setFont(self.hintFont)
    Theme.set(Theme.muted, 0.55)
    local hint
    if self.best then
        hint = InputMode.isGamepad() and "A open  ·  B leave" or "Enter open  ·  Esc leave"
    else
        hint = InputMode.isGamepad() and "B leave" or "Esc leave"
    end
    love.graphics.printf(hint, self.colX, by + self.oHint, self.colW, "center")

    -- The dev row, in the hostile red rather than the room's gold, so it can never be mistaken for
    -- something the game is offering the player.
    if self.dbgBtns then
        love.graphics.setFont(self.subFont)
        Theme.set(Theme.accentWeapon, 0.50)
        love.graphics.printf("debug  ·  mint a token  ·  holding " .. Voucher.count(self.player),
            0, self.dbgLabelY, Scale.WIDTH, "center")

        for _, d in ipairs(self.dbgBtns) do
            local lit = self.dbgHover == d.stars
            Theme.set(Theme.slot)
            love.graphics.rectangle("fill", d.x, d.y, d.w, d.h, 2)
            Theme.set(Theme.accentWeapon, lit and 0.85 or 0.40)
            love.graphics.rectangle("line", d.x, d.y, d.w, d.h, 2)
            Theme.set(Theme.accentWeapon, lit and 1 or 0.70)
            love.graphics.printf(tostring(d.stars), d.x, d.y + (d.h - self.subFont:getHeight()) / 2,
                d.w, "center")
        end
    end

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

-- ---- input -------------------------------------------------------------------
--
-- Three-input and mouse-only by construction (project standard): the plate is clickable, Enter and A
-- press it, and Esc, B, the close corner and a click outside all leave. There is no cursor to move --
-- one control is one control, so nothing here needs a focus model.

function Hiring:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    self.hover = inRect(self.btn, x, y)
    self.dbgHover = nil
    for _, d in ipairs(self.dbgBtns or {}) do
        if inRect(d, x, y) then self.dbgHover = d.stars end
    end
end

function Hiring:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    if inRect(self.btn, x, y) then return "hand" end
    for _, d in ipairs(self.dbgBtns or {}) do
        if inRect(d, x, y) then return "hand" end
    end
    return "arrow"
end

function Hiring:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end
    for _, d in ipairs(self.dbgBtns or {}) do
        if inRect(d, x, y) then self:debugGrant(d.stars) return end
    end
    if inRect(self.btn, x, y) then
        Sound.play("ui.confirm")
        self:open()
        return
    end
    -- A click anywhere off the card leaves, the way every other modal in the city behaves.
    if x < self.boxX or x > self.boxX + self.boxW
        or y < self.boxY or y > self.boxY + self.boxH then
        self:close()
    end
end

function Hiring:keypressed(key)
    if key == "escape" then self:close()
    elseif key == "return" or key == "kpenter" or key == "space" then
        if self.best then Sound.play("ui.confirm") end
        self:open()
    elseif Debug.enabled and key:match("^[1-5]$") then
        self:debugGrant(tonumber(key))
    end
end

function Hiring:gamepadpressed(_, button)
    if button == "b" then self:close()
    elseif button == "a" or button == "start" then
        if self.best then Sound.play("ui.confirm") end
        self:open()
    end
end

return Hiring
