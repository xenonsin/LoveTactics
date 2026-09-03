-- Single-relic reveal, with an optional toll. Two stops open it: the ALTAR's gamble (pay gold for a
-- relic you do not get to see first) and the WEEPING STONE (a relic a rung up, priced in a permanent cut
-- to the company's maximum health). The Reliquary offers a choice of three instead and has its own panel
-- (ui/panels/relic_offer.lua). Modeled on ui/panels/loot_reveal.lua: a state owns it as game.activePanel
-- and forwards input while it is open; three-input + mouse-only.
--
-- The card wears its RUNG as its colour (ui/relic_card.lua) and states its effect and its standing price
-- in digits, both resolved at the stack taking it would leave the company on -- so what is on the panel
-- is what the button grants. (It used to read "a Virtue cool, a Vice warm"; that axis is deleted.)
--
--   local panel = RelicReveal.new({
--       title    = "Sin's Altar",            -- optional; titles the panel
--       relic    = { id = , info = Relic.info(id) }, -- the rolled relic + its display info
--       onTake   = function() ... end,        -- TAKE: grant the relic, clear the cell
--       onLeave  = function() ... end,        -- LEAVE / dismissed: grant nothing, leave the cell
--   })

local CloseButton = require("ui.close_button")
local InputMode = require("input_mode")
local RelicCard = require("ui.relic_card")
local Scale = require("scale")
local Sound = require("models.sound")
local Theme = require("ui.theme")

local RelicReveal = {}
RelicReveal.__index = RelicReveal

local BOX_W = 480
local PAD = 30

local function inRect(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function RelicReveal.new(opts)
    opts = opts or {}
    local self = setmetatable({}, RelicReveal)
    self.onTake = opts.onTake
    self.onLeave = opts.onLeave
    self.finished = false
    self.title = opts.title or "Reliquary"
    self.info = opts.relic and opts.relic.info or { name = "Relic", blurb = "", tier = "common" }
    -- How many the run already carries, so the reveal can say "x2" rather than presenting a relic the
    -- player owns as a discovery. Nil/0 for the ordinary case.
    self.held = opts.relic and opts.relic.held or 0
    -- Whether this relic asks a standing price. A property now, not a category -- there is one shelf.
    self.hasCost = self.info.cost ~= nil
    -- BOTH LINES RESOLVED AT `held + 1`: the stack taking this would leave the company on. A reveal that
    -- quoted the authored base over a relic already carried twice would be advertising a different relic
    -- from the one the Pay button grants.
    do
        local Relic = require("models.relic")
        local key = (opts.relic and opts.relic.id) or self.info
        local at = (self.held or 0) + 1
        self.blurbText = Relic.blurbAt(key, at) or self.info.blurb or ""
        self.costText = Relic.costAt(key, at) or self.info.cost
    end
    self.accent = RelicCard.accentOf(self.info)
    self.focus = "take" -- "take" | "leave"
    -- A Shrine charges an upfront toll to take its gift: `priceLabel` is shown as a warning line and turns
    -- the primary button into "Pay"; `canPay` false greys it out (the caller checked affordability). A
    -- plain Reliquary passes neither, so its relic is free.
    self.priceLabel = opts.priceLabel
    self.canPay = opts.canPay ~= false

    self.titleFont = Theme.display(28)
    self.nameFont = Theme.display(24)
    self.badgeFont = Theme.body(12)
    self.bodyFont = Theme.body(16)
    self.hintFont = Theme.body(14)

    -- Vertical layout, laid out top-down as running offsets from the box top so nothing collides however
    -- long the blurb or a Vice's cost wraps. Title -> gem -> name -> badges -> blurb -> (cost) -> hint ->
    -- buttons, each cleared of the last.
    self.boxW = BOX_W
    local lineH = self.bodyFont:getHeight()
    self.oGem, self.oName, self.oBadge, self.oBlurb = 60, 116, 150, 184
    local _, blurbLines = self.bodyFont:getWrap(self.blurbText, BOX_W - PAD * 2)
    local afterBlurb = self.oBlurb + math.max(1, #blurbLines) * lineH
    if self.hasCost then
        self.oCost = afterBlurb + 8
        local _, costLines = self.bodyFont:getWrap("Cost: " .. self.costText, BOX_W - PAD * 2)
        afterBlurb = self.oCost + math.max(1, #costLines) * lineH
    end
    if self.priceLabel then
        self.oPrice = afterBlurb + 8
        local _, priceLines = self.bodyFont:getWrap(self.priceLabel, BOX_W - PAD * 2)
        afterBlurb = self.oPrice + math.max(1, #priceLines) * lineH
    end
    self.oHint = afterBlurb + 14
    self.oButtons = self.oHint + self.hintFont:getHeight() + 12

    local bw, bh, gap = 150, 44, 16
    self.boxH = self.oButtons + bh + PAD
    self.boxX = Scale.WIDTH / 2 - self.boxW / 2
    self.boxY = Scale.HEIGHT / 2 - self.boxH / 2

    self.closeButton = CloseButton.new(self.boxX + self.boxW, self.boxY)

    local by = self.boxY + self.oButtons
    self.leaveBtn = { x = self.boxX + self.boxW / 2 - bw - gap / 2, y = by, w = bw, h = bh, hovered = false }
    self.takeBtn  = { x = self.boxX + self.boxW / 2 + gap / 2,      y = by, w = bw, h = bh, hovered = false }

    Sound.play("treasure.reveal") -- a soft glint as the reliquary opens (silent until the file exists)
    return self
end

function RelicReveal:take()
    if self.finished then return end
    if self.priceLabel and not self.canPay then return end -- the toll is unaffordable; Pay is inert
    self.finished = true
    if self.onTake then self.onTake() end
end

function RelicReveal:leave()
    if self.finished then return end
    self.finished = true
    if self.onLeave then self.onLeave() end
end

-- ---- drawing ----------------------------------------------------------------

function RelicReveal:drawButton(b, label, primary, focused, disabled)
    local a = disabled and { 0.4, 0.42, 0.46 } or (primary and self.accent or { 0.6, 0.63, 0.7 })
    local lit = not disabled and (b.hovered or focused)
    love.graphics.setColor(a[1], a[2], a[3], lit and 0.30 or 0.14)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6, 6)
    love.graphics.setColor(a[1], a[2], a[3], lit and 1 or (disabled and 0.5 or 0.7))
    love.graphics.setLineWidth(focused and not disabled and 2 or 1)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(disabled and 0.6 or 0.95, disabled and 0.6 or 0.95, disabled and 0.62 or 0.97)
    love.graphics.printf(label, b.x, b.y + b.h / 2 - self.bodyFont:getHeight() / 2, b.w, "center")
end

function RelicReveal:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local bx, by = self.boxX, self.boxY
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)
    -- A thin accent rule along the top edge tints the whole panel to the relic's moral colour.
    love.graphics.setColor(self.accent[1], self.accent[2], self.accent[3], 0.85)
    love.graphics.rectangle("fill", bx + Theme.R, by, self.boxW - Theme.R * 2, 3)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, bx, by + 20, self.boxW, "center")

    RelicCard.gem(bx + self.boxW / 2, by + self.oGem, 44, 44, self.accent)

    love.graphics.setFont(self.nameFont)
    love.graphics.setColor(0.96, 0.95, 0.92)
    love.graphics.printf(self.info.name, bx + PAD, by + self.oName, self.boxW - PAD * 2, "center")

    -- The rung, and a held count when the run already carries one. Centred as a row.
    RelicCard.badges(bx + self.boxW / 2, by + self.oBadge, self.info, self.badgeFont, self.held)

    -- Blurb.
    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.82, 0.83, 0.88)
    love.graphics.printf(self.blurbText, bx + PAD, by + self.oBlurb, self.boxW - PAD * 2, "center")

    -- A Vice spells out its standing cost in its own warm colour.
    if self.oCost then
        love.graphics.setColor(self.accent[1], self.accent[2], self.accent[3], 0.95)
        love.graphics.printf("Cost: " .. self.costText, bx + PAD, by + self.oCost, self.boxW - PAD * 2, "center")
    end

    -- A Shrine's upfront toll, in a warning amber, and (when unaffordable) called out as such.
    if self.oPrice then
        love.graphics.setColor(0.86, 0.66, 0.30, self.canPay and 0.95 or 0.55)
        local line = self.priceLabel .. (self.canPay and "" or "  (can't afford)")
        love.graphics.printf(line, bx + PAD, by + self.oPrice, self.boxW - PAD * 2, "center")
    end

    local takeLabel = self.priceLabel and "Pay" or "Take"
    self:drawButton(self.leaveBtn, "Leave", false, self.focus == "leave")
    self:drawButton(self.takeBtn, takeLabel, true, self.focus == "take", self.priceLabel and not self.canPay)

    local verb = self.priceLabel and "pay" or "take"
    local hint = InputMode.isGamepad() and ("A " .. verb .. "  -  B leave")
        or ("Enter " .. verb .. "  -  Esc leave")
    love.graphics.setFont(self.hintFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.printf(hint, bx, by + self.oHint, self.boxW, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

-- ---- input -------------------------------------------------------------------

function RelicReveal:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    self.leaveBtn.hovered = inRect(self.leaveBtn, x, y)
    self.takeBtn.hovered = inRect(self.takeBtn, x, y)
end

function RelicReveal:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    if inRect(self.leaveBtn, x, y) or inRect(self.takeBtn, x, y) then return "hand" end
    return "arrow"
end

function RelicReveal:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:leave(); return end
    if inRect(self.takeBtn, x, y) then self:take()
    elseif inRect(self.leaveBtn, x, y) then self:leave() end
end

function RelicReveal:confirm()
    if self.focus == "take" then self:take() else self:leave() end
end

function RelicReveal:keypressed(key)
    if key == "escape" then self:leave()
    elseif key == "left" or key == "a" or key == "right" or key == "d" then
        self.focus = (self.focus == "take") and "leave" or "take"
    elseif key == "return" or key == "kpenter" or key == "space" then self:confirm() end
end

function RelicReveal:gamepadpressed(_, button)
    if button == "b" then self:leave()
    elseif button == "dpleft" or button == "dpright" then
        self.focus = (self.focus == "take") and "leave" or "take"
    elseif button == "a" or button == "start" then self:confirm() end
end

return RelicReveal
