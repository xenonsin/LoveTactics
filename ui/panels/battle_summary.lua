-- Battle summary overlay: the animated victory/defeat panel a fight ends on. Owned by states/battle.lua
-- (not a separate state) and drawn over the frozen board once `battle.over` is set; the state forwards
-- input to it and defers its own onWin/onLoss callback until this panel is dismissed. A win reveals the
-- spoils -- gold counts up, loot rises in as cards, exactly the way the treasure chest reveals a cache
-- (ui/panels/loot_reveal.lua, whose easing/particle idiom this shares). A loss is a somber, reward-free
-- red panel. An objective win carries no spoils (its reward flows through the hub's Company Advancement),
-- so its panel is a bare celebratory "Victory!".
--
--   local panel = BattleSummary.new({
--       result = "win" | "loss",
--       spoils = { gold = 71, loot = { "consumable_healing_potion", ... } }, -- nil for a loss/objective
--       encounter = battle.encounter,                                        -- { name, ... } (optional)
--       actions = {                                                          -- 1 button (win) or 1-2 (loss)
--           { label = "Try Again",     onSelect = function() ... end },      -- fired when chosen; each
--           { label = "Return to Hub", onSelect = function() ... end },      -- callback dismisses the panel
--       },
--   })
--
-- The panel only DISPLAYS the loot (throwaway Item.instantiate copies); the caller grants the real gold
-- and items in the win action's onSelect, so the reveal never double-grants. Three-input + mouse-only,
-- per project standard.

local CloseButton = require("ui.close_button")
local ItemTooltip = require("ui.item_tooltip")
local InputMode = require("input_mode")
local Item = require("models.item")
local Scale = require("scale")
local Colors = require("ui.colors")

local BattleSummary = {}
BattleSummary.__index = BattleSummary

-- Loot card grid (a shade smaller than the chest reveal's -- a fight drops less than a cache).
local CARD_W, CARD_H = 92, 112
local CARD_GAP = 14
local MAX_PER_ROW = 4

local BUTTON_H = 44
local BOTTOM_PAD = 22

-- Pacing (seconds), timed off `elapsed`. The banner lands, then gold counts up, then loot cards rise.
local BANNER_IN  = 0.50   -- title fades + scales in over this
local GOLD_START = 0.42   -- gold count-up begins
local GOLD_COUNT = 0.60   -- ...and runs for this long
local CARD_GAP_T = 0.10   -- pause between the gold finishing and the first card
local REVEAL_GAP = 0.22   -- stagger between successive loot cards
local CARD_RISE  = 0.40   -- one card's rise from source to slot
local GRAVITY    = 420     -- px/s^2 pulling the victory-burst particles back down

local GOLD  = { 0.96, 0.80, 0.34 }
local SPARK = { 1.00, 0.95, 0.78 }

local function easeOut(t) return 1 - (1 - t) * (1 - t) end
local function clamp01(t) return t < 0 and 0 or (t > 1 and 1 or t) end
local function lerp(a, b, t) return a + (b - a) * t end

local function inRect(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function BattleSummary.new(opts)
    opts = opts or {}
    local self = setmetatable({}, BattleSummary)
    self.win = opts.result ~= "loss"
    -- The panel's buttons, in order: { label, onSelect }. A win carries one ("Continue"); a defeat
    -- carries "Try Again" and, when there is a hub to abandon to, a second "Return to Hub". The caller
    -- (states/battle.lua) owns the labels and callbacks; this panel only lays them out and drives them.
    self.actions = opts.actions or {}
    self.finished = false
    self.subtitle = opts.encounter and opts.encounter.name or nil

    local spoils = opts.spoils or {}
    self.gold = math.max(0, spoils.gold or 0)

    -- Display-only instances, duplicate ids collapsed to one card carrying its count (three potions read
    -- as "Healing Potion x3"), just as loot_reveal does.
    local order, tally = {}, {}
    for _, id in ipairs(spoils.loot or {}) do
        if tally[id] then tally[id] = tally[id] + 1 else tally[id] = 1; order[#order + 1] = id end
    end
    self.items, self.counts = {}, {}
    for _, id in ipairs(order) do
        self.items[#self.items + 1] = Item.instantiate(id, tally[id])
        self.counts[#self.items] = tally[id]
    end
    self.n = #self.items

    self.bannerFont = love.graphics.newFont(44)
    self.subFont = love.graphics.newFont(16)
    self.goldFont = love.graphics.newFont(26)
    self.nameFont = love.graphics.newFont(13)
    self.hintFont = love.graphics.newFont(15)
    self.titleFont = love.graphics.newFont(30) -- the card icon-letter fallback font

    local hasGold = self.gold > 0
    local hasLoot = self.n > 0

    -- Box width tracks the loot row; a spoils-less panel (loss / objective) stays compact.
    local cols = math.min(math.max(1, self.n), MAX_PER_ROW)
    local rows = self.n > 0 and math.ceil(self.n / MAX_PER_ROW) or 0
    local gridW = cols * CARD_W + (cols - 1) * CARD_GAP
    local BOX_W = math.max(460, hasLoot and (gridW + 80) or 0)

    -- Vertical layout, top-down. Relative offsets first, so the total height is known before centring.
    local y = 34
    self.bannerRelY = y; y = y + 62
    if self.subtitle then self.subRelY = y; y = y + 26 end
    if hasGold then self.goldRelY = y; y = y + 46 end
    if hasLoot then
        self.gridRelY = y
        y = y + rows * CARD_H + (rows - 1) * CARD_GAP + 8
    end
    if not hasGold and not hasLoot then y = y + 10 end
    self.buttonRelY = y + 8
    local BOX_H = self.buttonRelY + BUTTON_H + BOTTOM_PAD

    self.boxW, self.boxH = BOX_W, BOX_H
    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    -- Lay the action buttons out in a centred row: one wide button on its own, or a pair side by side.
    local count = #self.actions
    local BW = count > 1 and 180 or 200
    local GAP = 16
    local rowW = count * BW + math.max(0, count - 1) * GAP
    local startX = self.boxX + BOX_W / 2 - rowW / 2
    self.buttonY = self.boxY + self.buttonRelY
    self.buttons = {}
    for i = 1, count do
        self.buttons[i] = { x = startX + (i - 1) * (BW + GAP), y = self.buttonY, w = BW, h = BUTTON_H, hovered = false }
    end
    self.focusBtn = 1              -- keyboard/gamepad highlight; defaults to the primary action
    self.cancelBtn = count         -- Esc / B / the X close: the last action (the safe exit)

    -- Cards rise from the box centre (from under the banner) to their settled slots.
    self.sourceX = self.boxX + BOX_W / 2
    self.sourceY = self.boxY + self.bannerRelY + 40
    self.slots = {}
    for i = 1, self.n do
        local col = (i - 1) % MAX_PER_ROW
        local row = math.floor((i - 1) / MAX_PER_ROW)
        local rowCount = math.min(self.n - row * MAX_PER_ROW, MAX_PER_ROW)
        local rowW = rowCount * CARD_W + (rowCount - 1) * CARD_GAP
        local startX = self.boxX + BOX_W / 2 - rowW / 2
        self.slots[i] = {
            cx = startX + col * (CARD_W + CARD_GAP) + CARD_W / 2,
            cy = self.boxY + (self.gridRelY or 0) + row * (CARD_H + CARD_GAP) + CARD_H / 2,
        }
    end

    self.elapsed = 0
    self.focus = 1
    self.mouseOverCard = false -- mouse mode only shows a loot tooltip while hovering a card
    self.burstDone = false
    self.particles = {}
    self.mx, self.my = self.boxX + BOX_W / 2, self.boxY + BOX_H / 2

    -- When the first card starts, and when everything has finished revealing.
    self.cardsStart = hasGold and (GOLD_START + GOLD_COUNT + CARD_GAP_T) or BANNER_IN
    local reveal = BANNER_IN
    if hasGold then reveal = math.max(reveal, GOLD_START + GOLD_COUNT) end
    if hasLoot then reveal = self.cardsStart + (self.n - 1) * REVEAL_GAP + CARD_RISE end
    self.fullyRevealedAt = reveal
    return self
end

-- Commit to action `i` (fire its callback once). Dismisses the panel.
function BattleSummary:select(i)
    if self.finished then return end
    local act = self.actions[i]
    if not act then return end
    self.finished = true
    if act.onSelect then act.onSelect() end
end

-- The safe exit (Esc / gamepad B / the X): the last action -- "Return to Hub" on a normal defeat,
-- or the only action when that is all there is (a win's "Continue", the tutorial's "Try Again").
function BattleSummary:cancel()
    self:select(self.cancelBtn)
end

function BattleSummary:isRevealed()
    return self.elapsed >= self.fullyRevealedAt
end

-- Fast-forward past the reveal to the final state (a confirm mid-animation).
function BattleSummary:skip()
    if self.elapsed < self.fullyRevealedAt then
        if self.win and not self.burstDone then self:burst() end
        self.elapsed = self.fullyRevealedAt
    end
end

-- A confirm: skip the reveal if it is still playing, else commit to the focused action.
function BattleSummary:confirm()
    if not self:isRevealed() then self:skip() else self:select(self.focusBtn) end
end

-- Victory burst: a spray of coins/sparks from behind the banner as it lands.
function BattleSummary:burst()
    self.burstDone = true
    local ox, oy = self.boxX + self.boxW / 2, self.boxY + self.bannerRelY + 24
    for _ = 1, 30 do
        local ang = -math.pi / 2 + (love.math.random() - 0.5) * 2.2
        local speed = 120 + love.math.random() * 160
        local coin = love.math.random() < 0.55
        self.particles[#self.particles + 1] = {
            x = ox + (love.math.random() - 0.5) * 60, y = oy,
            vx = math.cos(ang) * speed, vy = math.sin(ang) * speed,
            age = 0, life = 0.7 + love.math.random() * 0.7,
            spin = love.math.random() * math.pi,
            kind = coin and "coin" or "spark", color = coin and GOLD or SPARK,
        }
    end
end

function BattleSummary:update(dt)
    self.elapsed = self.elapsed + dt
    if self.win and not self.burstDone and self.elapsed >= BANNER_IN then self:burst() end
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.age = p.age + dt
        if p.age >= p.life then
            table.remove(self.particles, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + GRAVITY * dt
            p.spin = p.spin + dt * 12
        end
    end
end

-- The gold shown right now (counts up from 0 to self.gold across GOLD_COUNT).
function BattleSummary:goldShown()
    if self.gold <= 0 then return 0 end
    local t = clamp01((self.elapsed - GOLD_START) / GOLD_COUNT)
    return math.floor(self.gold * easeOut(t) + 0.5)
end

-- Draw state for card `i`: nil until it starts, else { cx, cy, alpha, scale }. Mirrors loot_reveal.
function BattleSummary:cardState(i)
    local start = self.cardsStart + (i - 1) * REVEAL_GAP
    if self.elapsed < start then return nil end
    local t = clamp01((self.elapsed - start) / CARD_RISE)
    local p = easeOut(t)
    local slot = self.slots[i]
    local cx = lerp(self.sourceX, slot.cx, p)
    local cy = lerp(self.sourceY, slot.cy, p) - math.sin(t * math.pi) * 10
    return { cx = cx, cy = cy, alpha = clamp01(t * 2), scale = 0.5 + 0.5 * p }
end

function BattleSummary:cardRect(i)
    local slot = self.slots[i]
    return { x = slot.cx - CARD_W / 2, y = slot.cy - CARD_H / 2, w = CARD_W, h = CARD_H }
end

-- ---- drawing ----------------------------------------------------------------

function BattleSummary:drawParticles()
    for _, p in ipairs(self.particles) do
        local a = 1 - p.age / p.life
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], a)
        if p.kind == "coin" then
            love.graphics.ellipse("fill", p.x, p.y, 4 * math.abs(math.cos(p.spin)) + 1.5, 4)
        else
            love.graphics.circle("fill", p.x, p.y, 2)
        end
    end
end

-- One loot card (icon + name + stack badge), matching the chest reveal's cards.
function BattleSummary:drawCard(item, count, cx, cy, alpha, scale, focused)
    local w, h = CARD_W * scale, CARD_H * scale
    local x, y = cx - w / 2, cy - h / 2

    love.graphics.setColor(0.15, 0.16, 0.21, alpha)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    if focused then
        love.graphics.setColor(0.95, 0.85, 0.55, alpha)
        love.graphics.setLineWidth(2)
    else
        love.graphics.setColor(0.45, 0.48, 0.58, alpha * 0.8)
        love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setLineWidth(1)

    local icx, icy = cx, cy - 6 * scale
    local sprite = item.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1, alpha)
        local iw, ih = sprite:getDimensions()
        local s = math.min((w - 14) / iw, (h - 30) / ih)
        love.graphics.draw(sprite, icx, icy, 0, s, s, iw / 2, ih / 2)
    else
        local ph = (h - 34)
        love.graphics.setColor(0.5, 0.5, 0.56, alpha)
        love.graphics.rectangle("fill", icx - ph / 2, y + 8, ph, ph, 6, 6)
        love.graphics.setFont(self.titleFont)
        love.graphics.setColor(0.95, 0.95, 0.95, alpha)
        love.graphics.printf((item.name or "?"):sub(1, 1), icx - ph / 2, icy - 18, ph, "center")
    end

    love.graphics.setColor(0, 0, 0, 0.6 * alpha)
    love.graphics.rectangle("fill", x + 1, y + h - 17 * scale, w - 2, 16 * scale, 0, 0, 6, 6)
    love.graphics.setFont(self.nameFont)
    local name = item.name or "?"
    local nw = self.nameFont:getWidth(name)
    local sc = math.min(1, (w - 8) / nw)
    love.graphics.setColor(0.92, 0.92, 0.96, alpha)
    love.graphics.print(name, cx - (nw * sc) / 2, y + h - 16 * scale, 0, sc, sc)

    if count and count > 1 then
        love.graphics.setFont(self.nameFont)
        local label = "x" .. count
        local lw = self.nameFont:getWidth(label)
        local bw, bh = lw + 8, self.nameFont:getHeight() + 2
        local bxr, byr = x + w - bw - 3, y + 3
        love.graphics.setColor(0.08, 0.09, 0.12, 0.85 * alpha)
        love.graphics.rectangle("fill", bxr, byr, bw, bh, 4, 4)
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], alpha)
        love.graphics.rectangle("line", bxr, byr, bw, bh, 4, 4)
        love.graphics.print(label, bxr + 4, byr + 1)
    end
end

function BattleSummary:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local accent = self.win and Colors.PARTY or Colors.ENEMY
    local bx, by = self.boxX, self.boxY

    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", bx, by, self.boxW, self.boxH, 10, 10)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, self.boxW, self.boxH, 10, 10)
    love.graphics.setLineWidth(1)

    self:drawParticles()

    -- Banner: scales + fades in, with a soft accent glow behind it on a win.
    local bt = clamp01(self.elapsed / BANNER_IN)
    local bp = easeOut(bt)
    local scale = lerp(0.55, 1.0, bp)
    local alpha = clamp01(bt * 1.6)
    local cx = bx + self.boxW / 2
    local cy = by + self.bannerRelY + 24
    if self.win then
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.18 * alpha)
        love.graphics.ellipse("fill", cx, cy, self.boxW * 0.42 * bp, 40 * bp)
    end
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    love.graphics.setFont(self.bannerFont)
    local title = self.win and "Victory!" or "Defeat"
    local tint = self.win and GOLD or { 0.95, 0.45, 0.42 }
    love.graphics.setColor(tint[1], tint[2], tint[3], alpha)
    love.graphics.printf(title, -self.boxW / 2, -self.bannerFont:getHeight() / 2, self.boxW, "center")
    love.graphics.pop()

    if self.subtitle then
        love.graphics.setFont(self.subFont)
        love.graphics.setColor(0.75, 0.77, 0.85, alpha)
        love.graphics.printf(self.subtitle, bx, by + self.subRelY, self.boxW, "center")
    end

    -- Gold line: a coin + the counting-up total.
    if self.gold > 0 then
        local gy = by + self.goldRelY
        local shown = self:goldShown()
        love.graphics.setFont(self.goldFont)
        local label = tostring(shown) .. " gold"
        local lw = self.goldFont:getWidth(label)
        local coinR = 9
        local totalW = coinR * 2 + 10 + lw
        local startX = cx - totalW / 2
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3])
        love.graphics.ellipse("fill", startX + coinR, gy + self.goldFont:getHeight() / 2, coinR, coinR)
        love.graphics.setColor(0.55, 0.42, 0.12)
        love.graphics.ellipse("line", startX + coinR, gy + self.goldFont:getHeight() / 2, coinR, coinR)
        love.graphics.setColor(0.97, 0.90, 0.62)
        love.graphics.print(label, startX + coinR * 2 + 10, gy)
    end

    -- Loot cards.
    for i, item in ipairs(self.items) do
        local cs = self:cardState(i)
        if cs then
            self:drawCard(item, self.counts[i], cs.cx, cs.cy, cs.alpha, cs.scale,
                i == self.focus and self:isRevealed())
        end
    end

    -- Action buttons, once everything has settled. The focused (keyboard/gamepad) or hovered (mouse)
    -- one is lit; the rest sit dim.
    if self:isRevealed() then
        love.graphics.setFont(self.hintFont)
        for i, b in ipairs(self.buttons) do
            local active = b.hovered or (i == self.focusBtn and not InputMode.isMouse())
            love.graphics.setColor(active and 0.35 or 0.22, active and 0.45 or 0.28, active and 0.35 or 0.24)
            love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6, 6)
            love.graphics.setColor(0.6, 0.7, 0.55)
            love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 6, 6)
            love.graphics.setColor(0.95, 0.95, 0.95)
            love.graphics.printf(self.actions[i].label or "", b.x, b.y + b.h / 2 - 9, b.w, "center")
        end
    else
        love.graphics.setFont(self.hintFont)
        love.graphics.setColor(0.55, 0.6, 0.7)
        local hint = InputMode.isGamepad() and "A to skip" or "Click / Enter to skip"
        love.graphics.printf(hint, bx, self.buttonY + BUTTON_H / 2 - 9, self.boxW, "center")
    end

    -- Loot inspect tooltip: a mouse-hover nicety only, so the default view keeps the Continue button
    -- clear. The cards themselves announce what dropped (icon + name + count); full stats are on the
    -- item once it's in the stash. Keyboard/gamepad just read the cards.
    if self:isRevealed() and self.n > 0 and self.mouseOverCard and InputMode.isMouse() then
        local focused = self.items[self.focus]
        if focused then ItemTooltip.draw(focused, self.mx, self.my, Scale.WIDTH) end
    end

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

-- ---- input -------------------------------------------------------------------

function BattleSummary:mousemoved(x, y)
    self.mx, self.my = x, y
    self.closeButton:mousemoved(x, y)
    for _, b in ipairs(self.buttons) do
        b.hovered = self:isRevealed() and inRect(b, x, y)
    end
    self.mouseOverCard = false
    if self:isRevealed() then
        for i = 1, self.n do
            if inRect(self:cardRect(i), x, y) then self.focus = i; self.mouseOverCard = true; break end
        end
    end
end

function BattleSummary:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    if self:isRevealed() then
        for _, b in ipairs(self.buttons) do
            if inRect(b, x, y) then return "hand" end
        end
        for i = 1, self.n do
            if inRect(self:cardRect(i), x, y) then return "hand" end
        end
    end
    return "arrow"
end

function BattleSummary:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then
        self:cancel()
        return
    end
    if not self:isRevealed() then
        self:skip()
        return
    end
    for i, b in ipairs(self.buttons) do
        if inRect(b, x, y) then self:select(i); return end
    end
    for i = 1, self.n do
        if inRect(self:cardRect(i), x, y) then self.focus = i; break end
    end
end

-- Cycle the loot inspect focus (a win with loot cards).
function BattleSummary:moveFocus(dir)
    if not self:isRevealed() or self.n == 0 then return end
    self.focus = ((self.focus - 1 + dir) % self.n) + 1
end

-- Cycle which action button is highlighted (a defeat with both Try Again and Return to Hub).
function BattleSummary:moveButtonFocus(dir)
    local n = #self.buttons
    if not self:isRevealed() or n <= 1 then return end
    self.focusBtn = ((self.focusBtn - 1 + dir) % n) + 1
end

-- Left/right steer the loot cards while there is loot to inspect (a win), otherwise the buttons
-- (a defeat's Try Again / Return to Hub).
function BattleSummary:steer(dir)
    if self.n > 0 then self:moveFocus(dir) else self:moveButtonFocus(dir) end
end

function BattleSummary:keypressed(key)
    if key == "escape" then
        self:cancel()
    elseif key == "left" or key == "a" then
        self:steer(-1)
    elseif key == "right" or key == "d" then
        self:steer(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:confirm()
    end
end

function BattleSummary:gamepadpressed(_, button)
    if button == "b" then
        self:cancel()
    elseif button == "dpleft" then
        self:steer(-1)
    elseif button == "dpright" then
        self:steer(1)
    elseif button == "a" or button == "start" then
        self:confirm()
    end
end

return BattleSummary
