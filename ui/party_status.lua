-- The overworld party readout, in two layers:
--   * PartyStatus.drawStrip(player, x, y) -- an always-on, input-free stack of compact HP/mana bars,
--     drawn on the map so the run's ATTRITION (health + mana carry between fights within a quest; see
--     models/player.lua Player.restore) is legible while routing. This is what turns "which fights can
--     I afford before the boss?" into a decision you can actually see.
--   * PartyStatus.new{ player, onClose } -- a modal panel that expands the same readout at a size worth
--     reading. It used to host the marching-grid editor; placement is now a per-battle decision made in
--     the deployment phase (docs/deployment.md), so the panel is a pure readout and mutates nothing.
--     Three inputs, closes via X / Esc / gamepad B.
--
-- Both layers read char.stats[stat].current/.max over Character.RESOURCE_STATS; the strip is hidden on
-- the flight tutorial by its caller (states/game.lua), where the HUD is deliberately spare.

local Scale = require("scale")
local Colors = require("ui.colors")
local CloseButton = require("ui.close_button")
local OverworldAbility = require("models.overworld_ability")
local Sprite = require("models.sprite")
local Theme = require("ui.theme")

local PartyStatus = {}
PartyStatus.__index = PartyStatus

local ROW_H = 32       -- room for a portrait + name + two bars, the way a timeline card reads
local PORTRAIT = 26
local STRIP_W = 210
local BADGE_R = 7 -- the ability badge sits at the right end of each row, with a banked-count number

-- Who the strip shows: the whole roster, which is the whole marching company -- everyone owned comes to
-- the quest, and which of them stand on a given board is a per-battle decision the overworld does not
-- make (docs/deployment.md). Returns a list of characters.
local function shownParty(player)
    return (player and player.roster) or {}
end

-- The companion's portrait square (its board token, or a coloured letter box) -- the same read as a
-- battle timeline card (ui/combat_panel.lua:drawPortrait).
local function portraitImage(char)
    local s = char.sprite
    if type(s) == "userdata" then return s end
    if type(s) == "string" then
        local img = Sprite.load(s)
        if type(img) == "userdata" then return img end
    end
    return nil
end

local function drawPortrait(char, px, py, ps, headFont)
    local img = portraitImage(char)
    love.graphics.setColor(0.13, 0.14, 0.19)
    love.graphics.rectangle("fill", px, py, ps, ps, 4, 4)
    if img then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = img:getDimensions()
        local scale = math.min(ps / sw, ps / sh)
        love.graphics.draw(img, px + ps / 2, py + ps / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        love.graphics.setFont(headFont)
        love.graphics.setColor(0.9, 0.9, 0.95)
        love.graphics.printf((char.name or "?"):sub(1, 1), px, py + ps / 2 - 9, ps, "center")
    end
    love.graphics.setColor(0.4, 0.44, 0.56)
    love.graphics.rectangle("line", px, py, ps, ps, 4, 4)
end

-- A small four-point star: the "this companion has an overworld ability" badge, hoverable for a tooltip.
local function drawBadge(cx, cy, r, hovered)
    local g = hovered and 1.0 or 0.85
    love.graphics.setColor(0.95, 0.85, 0.45, g)
    love.graphics.polygon("fill",
        cx, cy - r, cx + r * 0.32, cy - r * 0.32, cx + r, cy,
        cx + r * 0.32, cy + r * 0.32, cx, cy + r,
        cx - r * 0.32, cy + r * 0.32, cx - r, cy,
        cx - r * 0.32, cy - r * 0.32)
end

-- One row: portrait, name, HP + mana bars, and (if the companion has an overworld ability) the star
-- badge with its banked-count number. Returns the badge centre + info so the caller can hit-test hover.
local function drawRow(char, x, y, stripFont, headFont, bucket)
    drawPortrait(char, x, y + 2, PORTRAIT, headFont)

    local textX = x + PORTRAIT + 6
    love.graphics.setFont(stripFont)
    love.graphics.setColor(0.88, 0.90, 0.95)
    love.graphics.print(char.name or "?", textX, y)

    local hp = char.stats and char.stats.health
    local mp = char.stats and char.stats.mana
    local barX = textX
    local barW = (x + STRIP_W) - textX - 30 -- leave room for the badge + counter at the right
    local function bar(yy, cur, max, color, h)
        love.graphics.setColor(0.10, 0.11, 0.15)
        love.graphics.rectangle("fill", barX, yy, barW, h, 2, 2)
        if max and max > 0 then
            local frac = math.max(0, math.min(1, cur / max))
            love.graphics.setColor(color[1], color[2], color[3])
            love.graphics.rectangle("fill", barX, yy, barW * frac, h, 2, 2)
        end
    end
    if type(hp) == "table" then bar(y + 15, hp.current or 0, hp.max or 0, Colors.PARTY, 6) end
    if type(mp) == "table" and (mp.max or 0) > 0 then
        bar(y + 23, mp.current or 0, mp.max or 0, Colors.MANA, 4)
    end

    local info = OverworldAbility.info(char)
    if info then
        local bcx, bcy = x + STRIP_W - 22, y + PORTRAIT / 2 + 1
        local count = OverworldAbility.bankedCount(char, bucket)
        if count then
            love.graphics.setFont(stripFont)
            love.graphics.setColor(0.98, 0.9, 0.55)
            love.graphics.print(tostring(count), bcx + BADGE_R + 3, bcy - 8)
        end
        return bcx, bcy, info
    end
end

-- The ability tooltip: a titled box near the hovered badge, so the passive can explain itself.
local tipTitleFont, tipBodyFont
local function drawTooltip(bx, by, info)
    tipTitleFont = tipTitleFont or Theme.display(15)
    tipBodyFont = tipBodyFont or Theme.body(13)
    local W = 250
    local pad = 10
    local tx = bx + 12
    local _, wrapped = tipBodyFont:getWrap(info.blurb, W - pad * 2)
    local h = pad + 22 + #wrapped * (tipBodyFont:getHeight() + 2) + pad - 4
    -- Keep the box on-screen (nudge left if it would run off the right edge).
    if tx + W > Scale.WIDTH - 8 then tx = bx - W - 12 end
    local ty = by - 6
    love.graphics.setColor(0.08, 0.09, 0.13, 0.96)
    love.graphics.rectangle("fill", tx, ty, W, h, 8, 8)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", tx, ty, W, h, 8, 8)
    love.graphics.setFont(tipTitleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.print(info.name, tx + pad, ty + pad)
    love.graphics.setFont(tipBodyFont)
    love.graphics.setColor(0.82, 0.85, 0.9)
    love.graphics.printf(info.blurb, tx + pad, ty + pad + 22, W - pad * 2, "left")
end

-- Cached small font for the strip (the strip is called every frame from drawHud; don't mint a font
-- per call).
-- Draw the always-on party HP/mana strip. `mx, my` (optional, logical space) drive the ability-badge
-- hover tooltip, so a mouse player can point at the star by any companion and read what their passive
-- does; the same text also lives in the Party panel for keyboard/pad players.
-- The strip's total pixel height for `n` party members -- so a caller (states/game.lua) can stack
-- toasts beneath it without hard-coding the row math.
function PartyStatus.stripHeight(n)
    return n * ROW_H + 8
end

local stripFont, stripHeadFont
function PartyStatus.drawStrip(player, x, y, mx, my, abilityState)
    local party = shownParty(player)
    if #party == 0 then return end
    stripFont = stripFont or Theme.body(13)
    stripHeadFont = stripHeadFont or Theme.display(16)
    x = x or 16
    y = y or 60
    -- A faint backing so the portraits + bars read over any tile.
    love.graphics.setColor(0.06, 0.07, 0.10, 0.6)
    love.graphics.rectangle("fill", x - 6, y - 6, STRIP_W + 8, #party * ROW_H + 8, 6, 6)
    local hover
    for i, char in ipairs(party) do
        local bucket = abilityState and abilityState[char.id]
        local bcx, bcy, info = drawRow(char, x, y + (i - 1) * ROW_H, stripFont, stripHeadFont, bucket)
        if info then
            local hot = mx and math.abs(mx - bcx) <= BADGE_R + 4 and math.abs(my - bcy) <= BADGE_R + 4
            drawBadge(bcx, bcy, BADGE_R, hot)
            if hot then hover = { bcx, bcy, info } end
        end
    end
    if hover then drawTooltip(hover[1], hover[2], hover[3]) end
    love.graphics.setColor(1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- The expandable modal (the company's resources)
-- ---------------------------------------------------------------------------

-- This used to host the marching-grid editor. That grid is gone: who fights and where they stand is
-- chosen per battle in the deployment phase (states/battle.lua, docs/deployment.md), so between fights
-- there is no arrangement left to make. What the panel is FOR is the thing it was always also doing --
-- reading the company's attrition at a size you can actually see -- so it is now that, in full.
local BOX_W, BOX_H = 540, 470
local MODAL_ROW_H = 40 -- roomier than the strip's ROW_H; this is the read-it-properly view

function PartyStatus.new(opts)
    opts = opts or {}
    local self = setmetatable({}, PartyStatus)
    self.player = opts.player
    self.abilityState = opts.abilityState -- per-run ability scratch, for the banked-state line
    self.onClose = opts.onClose
    self.titleFont = Theme.display(26)
    self.hintFont = Theme.body(14)
    self.rowFont = Theme.body(15)
    self.rowHeadFont = Theme.display(18)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

function PartyStatus:close()
    if self.onClose then self.onClose() end
end

function PartyStatus:update(dt) end

function PartyStatus:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("The Company", self.boxX, self.boxY + 24, BOX_W, "center")

    love.graphics.setFont(self.hintFont)
    love.graphics.setColor(0.7, 0.74, 0.82)
    love.graphics.printf("Health and mana carry between fights. You choose who takes the field, and "
        .. "where, at the start of each battle.", self.boxX + 30, self.boxY + 60, BOX_W - 60, "center")

    -- One roomy row per company member: the same portrait + bars the map strip draws, at a size the
    -- panel has the space for.
    local party = shownParty(self.player)
    local rowX = self.boxX + (BOX_W - STRIP_W) / 2
    local rowY = self.boxY + 118
    for i, char in ipairs(party) do
        local bucket = self.abilityState and self.abilityState[char.id]
        local bcx, bcy, info = drawRow(char, rowX, rowY + (i - 1) * MODAL_ROW_H,
            self.rowFont, self.rowHeadFont, bucket)
        if info then drawBadge(bcx, bcy, BADGE_R, false) end
    end

    -- What each companion has banked toward a payoff this run (Ren's doses, Kaya's forage, ...), so the
    -- silent passives are legible. Only members with something pending appear.
    if self.abilityState then
        local notes = {}
        for _, char in ipairs(shownParty(self.player)) do
            local summary = OverworldAbility.bankedSummary(char, self.abilityState[char.id])
            if summary then notes[#notes + 1] = (char.name or "?") .. ": " .. summary end
        end
        if #notes > 0 then
            love.graphics.setFont(self.hintFont)
            love.graphics.setColor(0.72, 0.82, 0.6)
            love.graphics.printf(table.concat(notes, "    "), self.boxX + 20, self.boxY + BOX_H - 60,
                BOX_W - 40, "center")
        end
    end

    love.graphics.setFont(self.hintFont)
    love.graphics.setColor(0.5, 0.55, 0.65)
    local hint = require("input_mode").isGamepad() and "B: close" or "Esc: close"
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 34, BOX_W, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

function PartyStatus:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
end

function PartyStatus:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    return "arrow"
end

function PartyStatus:mousepressed(x, y, button)
    if button == 1 and self.closeButton:mousepressed(x, y, button) then
        self:close()
    end
end

function PartyStatus:keypressed(key)
    if key == "escape" then self:close() end
end

function PartyStatus:gamepadpressed(_, button)
    if button == "b" then self:close() end
end

return PartyStatus
