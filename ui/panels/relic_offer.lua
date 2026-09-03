-- The Reliquary. Opened when the player steps onto a `relic_cache` (see states/game.lua's openEncounter),
-- which has already built a SLATE of up to three run relics (models/relic.lua's Relic.slate). This panel
-- lays them out as three cards and takes exactly ONE -- the two refused are the price of the one kept, so
-- the stop is a decision rather than a free gift with a confirm button.
--
-- WHAT A CARD SAYS, and every word of it is a number. The rung (its colour, ui/relic_card.lua), the
-- effect resolved AT THE STACK THE COMPANY WOULD HOLD, and the price on the same terms. A card offering a
-- relic already carried twice reads "+5 damage / -5 defense", not the authored "+3 / -3" -- because what
-- taking it actually buys is the next copy, and a card that quoted the base would be advertising a
-- different relic from the one the button grants.
--
-- (The slate used to be composed to contrast -- one Vice against two Virtues -- and the cards said so in
-- cool jade and warm crimson. That axis is deleted: there is one shelf, the slate is a plain rarity roll,
-- and the colour is the rung.)
--
-- Taking is IRREVERSIBLE, so a mouse click on a card only FOCUSES it; the Take button below commits. A
-- keyboard/pad focus already lives on a card, so Enter/A takes the focused one outright. Same panel
-- contract as ui/panels/relic_reveal.lua: a state owns it as game.activePanel and forwards input while it
-- is open; three-input + mouse-only.
--
--   local panel = RelicOffer.new({
--       title   = "Reliquary",                                  -- optional; titles the panel
--       offer   = { { id = , info = Relic.info(id) }, ... },     -- 1..3 relics to choose between
--       onTake  = function(entry) ... end,                       -- TAKE: grant that relic, clear the cell
--       onLeave = function() ... end,                            -- LEAVE / dismissed: take nothing
--   })
--
-- WHAT THE REFUSAL IS CALLED, and why it is a parameter. On a reliquary, refusing leaves the cell to
-- come back to, and "Leave" is the whole of it. A descent's LANDING opens this same panel over the
-- general the party just put down (states/game.lua's openLanding), and there the refusal is not a
-- leaving at all -- there is nowhere to stand but the stair, so declining the boon goes down anyway.
-- A button that said "Leave" there would name an exit that does not exist.
--
-- So `prompt`, `leaveLabel` and `closeable` are the three things a caller may say instead. They are
-- text and a flag rather than a second panel, because the GESTURE is identical -- three cards, take
-- one, the rest are the price -- and the only honest difference is what the untaken cards cost you.

local CloseButton = require("ui.close_button")
local InputMode = require("input_mode")
local RelicCard = require("ui.relic_card")
local Scale = require("scale")
local Sound = require("models.sound")
local Theme = require("ui.theme")

local RelicOffer = {}
RelicOffer.__index = RelicOffer

local PAD = 30
local CARD_W = 300
local CARD_GAP = 24
local CARD_PAD = 16 -- inner margin of a card, for the wrapped name / blurb / cost

local function inRect(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function RelicOffer.new(opts)
    opts = opts or {}
    local self = setmetatable({}, RelicOffer)
    self.title = opts.title or "Reliquary"
    self.prompt = opts.prompt or "Take one. The rest stay sealed."
    self.leaveLabel = opts.leaveLabel or "Leave"
    -- A panel with nowhere to back out to draws no X. The refusal is still reachable by mouse (the
    -- button below the cards), by key and by pad -- what goes away is the corner control that reads as
    -- "dismiss this" on a screen where nothing can be dismissed.
    self.closeable = opts.closeable ~= false
    self.offer = opts.offer or {}
    self.onTake = opts.onTake
    self.onLeave = opts.onLeave
    self.finished = false
    self.focus = 1

    self.titleFont = Theme.display(28)
    self.promptFont = Theme.body(15)
    self.nameFont = Theme.display(20)
    self.badgeFont = Theme.body(11)
    self.bodyFont = Theme.body(14)
    self.hintFont = Theme.body(14)

    -- Card interior, laid out top-down as running offsets from the card top: gem -> name -> badges ->
    -- blurb -> (a Vice's cost). Every card gets the SAME height -- the tallest wrap wins -- so the three
    -- read as one shelf and the eye compares like with like.
    local textW = CARD_W - CARD_PAD * 2
    local lineH = self.bodyFont:getHeight()
    self.oGem, self.oName = 20, 74
    local nameH = self.nameFont:getHeight()
    self.oBadge = self.oName + nameH + 10
    self.oBlurb = self.oBadge + self.badgeFont:getHeight() + 6 + 12

    -- Both lines are resolved at the stack the company WOULD hold, here as well as at the draw, so the
    -- card is sized against the text it actually prints. Taking a relic held twice grants a third, so
    -- `held + 1` is the number every line on this card is quoting.
    local Relic = require("models.relic")
    local tallest = 0
    for _, entry in ipairs(self.offer) do
        local info = entry.info or {}
        local at = (entry.held or 0) + 1
        entry.blurbText = Relic.blurbAt(entry.id or info, at)
        entry.costText = Relic.costAt(entry.id or info, at) or info.cost
        local _, blurbLines = self.bodyFont:getWrap(entry.blurbText or "", textW)
        local h = self.oBlurb + math.max(1, #blurbLines) * lineH
        if entry.costText then
            local _, costLines = self.bodyFont:getWrap("Cost: " .. entry.costText, textW)
            h = h + 8 + math.max(1, #costLines) * lineH
        end
        if h > tallest then tallest = h end
    end
    self.cardH = tallest + CARD_PAD

    local n = math.max(1, #self.offer)
    self.boxW = PAD * 2 + n * CARD_W + (n - 1) * CARD_GAP
    -- The cards start under the prompt rather than at a fixed offset. The reliquary's own one-liner
    -- fits on a line at any slate size, but a caller's prompt need not -- and a two-line one at a fixed
    -- 96 would print its second line through the top of the cards.
    self.oPrompt = 60
    local _, promptLines = self.promptFont:getWrap(self.prompt, self.boxW - PAD * 2)
    self.oCards = self.oPrompt + math.max(1, #promptLines) * self.promptFont:getHeight() + 17
    local bw, bh, gap = 150, 44, 16
    self.oButtons = self.oCards + self.cardH + 18
    self.oHint = self.oButtons + bh + 12
    self.boxH = self.oHint + self.hintFont:getHeight() + PAD - 6
    self.boxX = Scale.WIDTH / 2 - self.boxW / 2
    self.boxY = Scale.HEIGHT / 2 - self.boxH / 2

    self.closeButton = self.closeable and CloseButton.new(self.boxX + self.boxW, self.boxY) or nil

    for i, entry in ipairs(self.offer) do
        entry.rect = {
            x = self.boxX + PAD + (i - 1) * (CARD_W + CARD_GAP),
            y = self.boxY + self.oCards, w = CARD_W, h = self.cardH,
        }
    end

    local by = self.boxY + self.oButtons
    self.leaveBtn = { x = self.boxX + self.boxW / 2 - bw - gap / 2, y = by, w = bw, h = bh, hovered = false }
    self.takeBtn  = { x = self.boxX + self.boxW / 2 + gap / 2,      y = by, w = bw, h = bh, hovered = false }

    Sound.play("treasure.reveal") -- a soft glint as the reliquary opens (silent until the file exists)
    return self
end

function RelicOffer:take(i)
    if self.finished then return end
    local entry = self.offer[i or self.focus]
    if not entry then return end
    self.finished = true
    if self.onTake then self.onTake(entry) end
end

function RelicOffer:leave()
    if self.finished then return end
    self.finished = true
    if self.onLeave then self.onLeave() end
end

-- ---- drawing ----------------------------------------------------------------

function RelicOffer:drawCard(entry, focused)
    local r = entry.rect
    local info = entry.info or {}
    local accent = RelicCard.accentOf(info)
    local cx = r.x + r.w / 2
    local textW = r.w - CARD_PAD * 2

    love.graphics.setColor(0.12, 0.13, 0.16, focused and 0.95 or 0.55)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 7, 7)
    love.graphics.setColor(accent[1], accent[2], accent[3], focused and 1 or 0.4)
    love.graphics.setLineWidth(focused and 2 or 1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 7, 7)
    love.graphics.setLineWidth(1)

    RelicCard.gem(cx, r.y + self.oGem, 40, 40, accent)

    -- The name never scales: a long one steps the face down a size or two, then ellipsizes (Theme.fitText).
    local font, label = Theme.fitText(Theme.display, info.name or entry.id or "Relic", textW, 20, 15)
    love.graphics.setFont(font)
    love.graphics.setColor(0.96, 0.95, 0.92)
    love.graphics.printf(label, r.x + CARD_PAD, r.y + self.oName, textW, "center")

    -- The rung, plus a HELD count when this card is something the run already carries. Taking a
    -- duplicate deepens it (models/relic.lua), so at the moment of the offer "you have two of these"
    -- is the one other fact that changes the decision.
    RelicCard.badges(cx, r.y + self.oBadge, info, self.badgeFont, entry.held)

    -- Both lines were resolved in the constructor at `held + 1` -- the stack this card would leave the
    -- company on -- so what is printed is what taking it actually buys.
    local blurb = entry.blurbText or info.blurb or ""
    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.82, 0.83, 0.88)
    love.graphics.printf(blurb, r.x + CARD_PAD, r.y + self.oBlurb, textW, "center")

    -- A relic that costs you something spells the price out under its blurb, in the same digits the gain
    -- is stated in. Not a category any more -- there is one shelf -- just a second sentence on the
    -- relics that have one.
    if entry.costText then
        local _, blurbLines = self.bodyFont:getWrap(blurb, textW)
        local y = r.y + self.oBlurb + math.max(1, #blurbLines) * self.bodyFont:getHeight() + 8
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.95)
        love.graphics.printf("Cost: " .. entry.costText, r.x + CARD_PAD, y, textW, "center")
    end
end

function RelicOffer:drawButton(b, label, primary, focused)
    local accent = primary and RelicCard.accentOf(self.offer[self.focus] and self.offer[self.focus].info)
        or { 0.6, 0.63, 0.7 }
    local lit = b.hovered or focused
    love.graphics.setColor(accent[1], accent[2], accent[3], lit and 0.30 or 0.14)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6, 6)
    love.graphics.setColor(accent[1], accent[2], accent[3], lit and 1 or 0.7)
    love.graphics.setLineWidth(lit and 2 or 1)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.95, 0.95, 0.97)
    love.graphics.printf(label, b.x, b.y + b.h / 2 - self.bodyFont:getHeight() / 2, b.w, "center")
end

function RelicOffer:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local bx, by = self.boxX, self.boxY
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)
    -- The top rule takes the FOCUSED relic's colour, so moving the ring re-tints the whole panel and the
    -- moral weight of the card under the cursor is legible from the frame in.
    local accent = RelicCard.accentOf(self.offer[self.focus] and self.offer[self.focus].info)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.85)
    love.graphics.rectangle("fill", bx + Theme.R, by, self.boxW - Theme.R * 2, 3)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, bx, by + 20, self.boxW, "center")

    love.graphics.setFont(self.promptFont)
    love.graphics.setColor(0.66, 0.69, 0.76)
    love.graphics.printf(self.prompt, bx + PAD, by + self.oPrompt, self.boxW - PAD * 2, "center")

    for i, entry in ipairs(self.offer) do self:drawCard(entry, i == self.focus) end

    self:drawButton(self.leaveBtn, self.leaveLabel, false, false)
    self:drawButton(self.takeBtn, "Take", true, true)

    local refuse = self.leaveLabel:lower()
    local hint = InputMode.isGamepad() and ("D-pad choose  -  A take  -  B " .. refuse)
        or ("Arrows choose  -  Enter take  -  Esc " .. refuse)
    love.graphics.setFont(self.hintFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.printf(hint, bx, by + self.oHint, self.boxW, "center")

    if self.closeButton then self.closeButton:draw() end
    love.graphics.setColor(1, 1, 1)
end

-- ---- input -------------------------------------------------------------------

function RelicOffer:mousemoved(x, y)
    if self.closeButton then self.closeButton:mousemoved(x, y) end
    self.leaveBtn.hovered = inRect(self.leaveBtn, x, y)
    self.takeBtn.hovered = inRect(self.takeBtn, x, y)
    for i, entry in ipairs(self.offer) do
        if inRect(entry.rect, x, y) then self.focus = i; break end
    end
end

function RelicOffer:cursorKind(x, y)
    if self.closeButton and self.closeButton:contains(x, y) then return "hand" end
    if inRect(self.leaveBtn, x, y) or inRect(self.takeBtn, x, y) then return "hand" end
    for _, entry in ipairs(self.offer) do if inRect(entry.rect, x, y) then return "hand" end end
    return "arrow"
end

-- A click on a card only SELECTS it -- the choice is irreversible, so committing is always the deliberate
-- second click on Take.
function RelicOffer:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton and self.closeButton:mousepressed(x, y, button) then self:leave(); return end
    if inRect(self.takeBtn, x, y) then self:take(); return end
    if inRect(self.leaveBtn, x, y) then self:leave(); return end
    for i, entry in ipairs(self.offer) do
        if inRect(entry.rect, x, y) then self.focus = i; return end
    end
end

function RelicOffer:moveFocus(d)
    if #self.offer == 0 then return end
    self.focus = ((self.focus - 1 + d) % #self.offer) + 1
end

function RelicOffer:keypressed(key)
    if key == "escape" then self:leave()
    elseif key == "left" or key == "a" then self:moveFocus(-1)
    elseif key == "right" or key == "d" then self:moveFocus(1)
    elseif key == "return" or key == "kpenter" or key == "space" then self:take() end
end

function RelicOffer:gamepadpressed(_, button)
    if button == "b" then self:leave()
    elseif button == "dpleft" then self:moveFocus(-1)
    elseif button == "dpright" then self:moveFocus(1)
    elseif button == "a" or button == "start" then self:take() end
end

return RelicOffer
