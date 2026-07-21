-- Chest-opening loot reveal. Opened when the player claims a treasure encounter (states/game.lua's
-- openEncounter routes a `treasure` cell straight here). The panel opens showing a CLOSED chest and an
-- Open button -- the "open" screen already has the chest. Pressing Open swings the lid up with a burst
-- of light and rising coins/sparks, then each loot item rises out as a card, one at a time -- the slow
-- reveal. Once shown, the player hovers (mouse) or moves a selection (keyboard/gamepad) over a card to
-- inspect its full details via ui/item_tooltip.lua, then Take / X / Esc / B collects the loot.
--
-- Modeled on ui/panels/encounter.lua: a state owns it as game.activePanel and forwards input while it
-- is open. Three-input + mouse-only. Two outcomes, so the cell knows whether the cache was taken:
--
--   local panel = LootReveal.new({
--       encounter = cell.encounter,                  -- { name, ... } (optional; titles the panel)
--       loot = { "consumable_healing_potion", ... }, -- item ids to reveal (display copies)
--       onCollect = function() ... end,              -- OPENED and taken: grant the loot + clear the cell
--       onCancel  = function() ... end,              -- dismissed while still closed: grant nothing
--   })
--
-- The panel only DISPLAYS the loot (throwaway Item.instantiate copies for icons/tooltips); the caller
-- grants the real items into the stash in onCollect, so the reveal never double-grants.

local CloseButton = require("ui.close_button")
local ItemTooltip = require("ui.item_tooltip")
local InputMode = require("input_mode")
local Item = require("models.item")
local Scale = require("scale")

local LootReveal = {}
LootReveal.__index = LootReveal

-- Card grid.
local CARD_W, CARD_H = 96, 118
local CARD_GAP = 14
local MAX_PER_ROW = 4

-- Vertical layout (relative to the box top). The cards settle in a row up top; the chest sits below
-- them with a gap wide enough for the swung-open lid; the action button sits below the chest, clear
-- of it -- so Take never overlaps the chest.
local TITLE_TOP = 26
local GRID_TOP = 92           -- top of the card row
local LID_CLEARANCE = 132     -- cards-bottom -> chest-base-top: room for the open lid between them
local CHEST_H = 74
local CHEST_TO_BUTTON = 26    -- chest-base-bottom -> button-top
local BUTTON_H = 44
local BOTTOM_PAD = 22

-- Pacing (seconds). Timed off `elapsed`, which only advances once the chest has been Opened.
local CHEST_OPEN = 0.55  -- lid swings open over this
local BURST_AT   = 0.16  -- into the open, the lid pops -> light burst + particle spray + a shake
local REVEAL_GAP = 0.24  -- stagger between successive item cards emerging -- the "slow reveal"
local CARD_RISE  = 0.42  -- how long one card takes to rise from the chest into its slot
local SHAKE_TIME = 0.30  -- lid-pop screenshake duration
local SHAKE_MAG  = 6      -- px at the start of the shake (decays to 0)
local GLOW_TIME  = 0.70  -- expanding light ring lifetime after the pop
local GRAVITY    = 420    -- px/s^2 pulling coins/sparks back down after they spray up

local GOLD  = { 0.96, 0.80, 0.34 }
local SPARK = { 1.00, 0.95, 0.78 }

local DEFAULT_DESC = "An unguarded cache sits here. Claim what's inside."

local function easeOut(t) return 1 - (1 - t) * (1 - t) end
local function clamp01(t) return t < 0 and 0 or (t > 1 and 1 or t) end
local function lerp(a, b, t) return a + (b - a) * t end

-- Columns per row (capped) and the row count for `n` cards.
local function gridShape(n)
    return math.min(n, MAX_PER_ROW), math.ceil(n / MAX_PER_ROW)
end

function LootReveal.new(opts)
    opts = opts or {}
    local self = setmetatable({}, LootReveal)
    self.onCollect = opts.onCollect
    self.onCancel = opts.onCancel
    self.finished = false
    self.title = (opts.encounter and opts.encounter.name) or "Treasure"
    self.description = opts.description or DEFAULT_DESC

    -- Display-only instances: icons + the data ItemTooltip needs. Never granted from here. Identical
    -- ids collapse into a single card carrying its count (self.counts), so three healing potions read
    -- as one "Healing Potion x3" rather than three cards. The count seeds the instance's quantity too,
    -- so a stackable's tooltip shows the same "Quantity xN" (Item.instantiate clamps to its maxStack).
    local order, tally = {}, {}
    for _, id in ipairs(opts.loot or {}) do
        if tally[id] then tally[id] = tally[id] + 1 else tally[id] = 1; order[#order + 1] = id end
    end
    self.items, self.counts = {}, {}
    for _, id in ipairs(order) do
        self.items[#self.items + 1] = Item.instantiate(id, tally[id])
        self.counts[#self.items] = tally[id]
    end
    local n = math.max(1, #self.items)

    self.titleFont = love.graphics.newFont(30)
    self.bodyFont = love.graphics.newFont(18)
    self.nameFont = love.graphics.newFont(13)
    self.hintFont = love.graphics.newFont(15)

    -- Box sized to the card grid width, with a fixed vertical layout stacked title -> cards -> chest
    -- -> button, so the Take button always clears the chest.
    local cols, rows = gridShape(#self.items)
    local gridW = cols * CARD_W + (cols - 1) * CARD_GAP
    local BOX_W = math.max(480, gridW + 80)
    local cardsBottom = GRID_TOP + rows * CARD_H + (rows - 1) * CARD_GAP
    local chestTopRel = cardsBottom + LID_CLEARANCE
    local BOX_H = chestTopRel + CHEST_H + CHEST_TO_BUTTON + BUTTON_H + BOTTOM_PAD
    self.boxW, self.boxH = BOX_W, BOX_H
    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    -- One bottom button: labelled "Open" while closed, "Take" once revealed (hidden mid-animation).
    self.button = {
        x = self.boxX + BOX_W / 2 - 90,
        y = self.boxY + chestTopRel + CHEST_H + CHEST_TO_BUTTON,
        w = 180,
        h = BUTTON_H,
        hovered = false,
    }

    -- Chest (base top) centred below the cards; cards rise from its mouth.
    self.chestX = self.boxX + BOX_W / 2
    self.chestY = self.boxY + chestTopRel
    self.chestMouthX = self.chestX
    self.chestMouthY = self.chestY + 4

    -- Card slot centres: centred rows under the title.
    self.slots = {}
    for i = 1, #self.items do
        local col = (i - 1) % MAX_PER_ROW
        local row = math.floor((i - 1) / MAX_PER_ROW)
        local rowCount = math.min(#self.items - row * MAX_PER_ROW, MAX_PER_ROW)
        local rowW = rowCount * CARD_W + (rowCount - 1) * CARD_GAP
        local startX = self.boxX + BOX_W / 2 - rowW / 2
        self.slots[i] = {
            cx = startX + col * (CARD_W + CARD_GAP) + CARD_W / 2,
            cy = self.boxY + GRID_TOP + row * (CARD_H + CARD_GAP) + CARD_H / 2,
        }
    end

    self.opened = false         -- has the chest been Opened yet? (gates the animation)
    self.elapsed = 0
    self.focus = 1              -- inspected card index
    self.hoverCard = nil        -- card the mouse is over right now (nil = off the cards; hides the tooltip in mouse mode)
    self.shake = 0
    self.burstDone = false
    self.glow = nil
    self.particles = {}
    self.trickle = 0
    -- Seed the mouse anchor at the panel centre so a mouse-mode tooltip is never stranded at (0,0)
    -- before the first mousemoved; a real hover overwrites it at once.
    self.mx, self.my = self.boxX + BOX_W / 2, self.boxY + BOX_H / 2

    self.fullyRevealedAt = CHEST_OPEN + (n - 1) * REVEAL_GAP + CARD_RISE
    return self
end

-- Dismiss. Fired once; the outcome depends on whether the chest was ever opened.
function LootReveal:close()
    if self.finished then return end
    self.finished = true
    if self.opened then
        if self.onCollect then self.onCollect() end
    else
        if self.onCancel then self.onCancel() end
    end
end

-- Begin the opening animation (the Open button / confirm while still closed).
function LootReveal:open()
    if self.opened then return end
    self.opened = true
    self.elapsed = 0
end

-- Fast-forward past the animation straight to the fully-revealed state (confirm during the show).
function LootReveal:skip()
    if self.elapsed < self.fullyRevealedAt then
        if not self.burstDone then self:burst() end
        self.elapsed = self.fullyRevealedAt
    end
end

function LootReveal:isRevealed()
    return self.opened and self.elapsed >= self.fullyRevealedAt
end

-- Whether card `i` has begun emerging yet (so it can be inspected / drawn).
function LootReveal:cardStarted(i)
    return self.opened and self.elapsed >= CHEST_OPEN + (i - 1) * REVEAL_GAP
end

-- Which bottom button is live: "open" while closed, "take" once revealed, nil mid-animation.
function LootReveal:buttonMode()
    if not self.opened then return "open" end
    if self:isRevealed() then return "take" end
    return nil
end

-- The lid pops: spray coins/sparks from the chest mouth, kick the glow ring and a short shake.
function LootReveal:burst()
    self.burstDone = true
    self.shake = SHAKE_TIME
    self.glow = { age = 0 }
    for _ = 1, 26 do self:spawnParticle(true) end
end

function LootReveal:spawnParticle(strong)
    local coin = love.math.random() < 0.55
    local speed = strong and (140 + love.math.random() * 150) or (90 + love.math.random() * 90)
    local ang = -math.pi / 2 + (love.math.random() - 0.5) * (strong and 1.7 or 1.1)
    self.particles[#self.particles + 1] = {
        x = self.chestMouthX + (love.math.random() - 0.5) * 24,
        y = self.chestMouthY,
        vx = math.cos(ang) * speed,
        vy = math.sin(ang) * speed,
        age = 0,
        life = 0.7 + love.math.random() * 0.7,
        spin = love.math.random() * math.pi,
        kind = coin and "coin" or "spark",
        color = coin and GOLD or SPARK,
    }
end

function LootReveal:update(dt)
    if self.opened then
        self.elapsed = self.elapsed + dt

        if not self.burstDone and self.elapsed >= BURST_AT then self:burst() end
        if self.burstDone and not self:isRevealed() then
            self.trickle = self.trickle + dt
            while self.trickle >= 0.05 do
                self.trickle = self.trickle - 0.05
                self:spawnParticle(false)
            end
        end
    end

    if self.shake > 0 then self.shake = math.max(0, self.shake - dt) end
    if self.glow then
        self.glow.age = self.glow.age + dt
        if self.glow.age >= GLOW_TIME then self.glow = nil end
    end

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

-- Draw state for card `i`: nil until it starts, else { cx, cy, alpha, scale }.
function LootReveal:cardState(i)
    if not self:cardStarted(i) then return nil end
    local t = clamp01((self.elapsed - (CHEST_OPEN + (i - 1) * REVEAL_GAP)) / CARD_RISE)
    local p = easeOut(t)
    local slot = self.slots[i]
    local cx = lerp(self.chestMouthX, slot.cx, p)
    local cy = lerp(self.chestMouthY, slot.cy, p) - math.sin(t * math.pi) * 10 -- slight arc/overshoot
    return { cx = cx, cy = cy, alpha = clamp01(t * 2), scale = 0.5 + 0.5 * p }
end

local function inRect(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- The rect a fully-settled card occupies (for hover hit-testing once revealed).
function LootReveal:cardRect(i)
    local slot = self.slots[i]
    return { x = slot.cx - CARD_W / 2, y = slot.cy - CARD_H / 2, w = CARD_W, h = CARD_H }
end

-- ---- drawing ----------------------------------------------------------------

function LootReveal:drawChest(ox, oy)
    local cx = self.chestX + ox
    local baseY = self.chestY + oy
    local w = 108
    local x = cx - w / 2

    -- Base body.
    love.graphics.setColor(0.40, 0.27, 0.15)
    love.graphics.rectangle("fill", x, baseY, w, CHEST_H, 6, 6)
    love.graphics.setColor(0.26, 0.17, 0.10)
    love.graphics.rectangle("line", x, baseY, w, CHEST_H, 6, 6)
    love.graphics.setColor(0.72, 0.60, 0.28)
    love.graphics.rectangle("fill", x + 14, baseY, 10, CHEST_H, 2, 2)
    love.graphics.rectangle("fill", x + w - 24, baseY, 10, CHEST_H, 2, 2)
    love.graphics.rectangle("fill", cx - 8, baseY + CHEST_H - 26, 16, 18, 3, 3)

    -- Lid: a rounded top swinging open about its rear (top) hinge. Shut until Opened, then eases up.
    local t = self.opened and clamp01(self.elapsed / CHEST_OPEN) or 0
    local angle = -easeOut(t) * (math.pi * 0.62)
    local lidH = 30
    love.graphics.push()
    love.graphics.translate(x, baseY)
    love.graphics.rotate(angle)
    love.graphics.setColor(0.48, 0.33, 0.19)
    love.graphics.rectangle("fill", 0, -lidH, w, lidH, 6, 6)
    love.graphics.setColor(0.72, 0.60, 0.28)
    love.graphics.rectangle("fill", 14, -lidH, 10, lidH, 2, 2)
    love.graphics.rectangle("fill", w - 24, -lidH, 10, lidH, 2, 2)
    love.graphics.setColor(0.26, 0.17, 0.10)
    love.graphics.rectangle("line", 0, -lidH, w, lidH, 6, 6)
    love.graphics.pop()

    -- Warm interior glow spilling from the open mouth once the lid has cracked.
    if t > 0.15 then
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.25 * t)
        love.graphics.ellipse("fill", cx, baseY + 2, w / 2 - 6, 14)
    end
end

function LootReveal:drawGlow(ox, oy)
    if not self.glow then return end
    local k = 1 - self.glow.age / GLOW_TIME
    local r = 20 + (1 - k) * 150
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.30 * k)
    love.graphics.circle("fill", self.chestMouthX + ox, self.chestMouthY + oy, r)
    love.graphics.setColor(SPARK[1], SPARK[2], SPARK[3], 0.22 * k)
    love.graphics.circle("fill", self.chestMouthX + ox, self.chestMouthY + oy, r * 0.6)
end

function LootReveal:drawParticles(ox, oy)
    for _, p in ipairs(self.particles) do
        local a = 1 - p.age / p.life
        local px, py = p.x + ox, p.y + oy
        if p.kind == "coin" then
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], a)
            love.graphics.ellipse("fill", px, py, 4 * math.abs(math.cos(p.spin)) + 1.5, 4)
        else
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], a)
            love.graphics.circle("fill", px, py, 2)
        end
    end
end

function LootReveal:drawCard(item, count, cx, cy, alpha, scale, focused)
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

    -- Icon: image when the art exists (models/sprite.lua returns the path string otherwise), else the
    -- name's first letter -- the same fallback the inventory grid uses.
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

    -- Stack badge in the top-right corner when the chest gave more than one of this item.
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

function LootReveal:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    -- Screenshake offset, applied to the box contents (not the dimmer).
    local ox, oy = 0, 0
    if self.shake > 0 then
        local k = self.shake / SHAKE_TIME
        ox = math.sin(self.shake * 70) * SHAKE_MAG * k
        oy = math.cos(self.shake * 55) * SHAKE_MAG * k
    end

    local bx, by = self.boxX + ox, self.boxY + oy
    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", bx, by, self.boxW, self.boxH, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", bx, by, self.boxW, self.boxH, 10, 10)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(self.title, bx, by + TITLE_TOP, self.boxW, "center")

    -- Closed intro: the description sits where the cards will later land.
    if not self.opened then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.printf(self.description, bx + 30, by + GRID_TOP + 24, self.boxW - 60, "center")
    end

    self:drawGlow(ox, oy)
    self:drawChest(ox, oy)
    self:drawParticles(ox, oy)

    for i, item in ipairs(self.items) do
        local cs = self:cardState(i)
        if cs then
            self:drawCard(item, self.counts[i], cs.cx + ox, cs.cy + oy, cs.alpha, cs.scale,
                i == self.focus and self:isRevealed())
        end
    end

    -- Bottom button: "Open" while closed, "Take" once revealed (hidden mid-animation).
    local mode = self:buttonMode()
    if mode then
        local b = self.button
        love.graphics.setColor(b.hovered and 0.35 or 0.22, b.hovered and 0.45 or 0.28, b.hovered and 0.35 or 0.24)
        love.graphics.rectangle("fill", b.x + ox, b.y + oy, b.w, b.h, 6, 6)
        love.graphics.setColor(0.6, 0.7, 0.55)
        love.graphics.rectangle("line", b.x + ox, b.y + oy, b.w, b.h, 6, 6)
        love.graphics.setFont(self.hintFont)
        love.graphics.setColor(0.95, 0.95, 0.95)
        love.graphics.printf(mode == "open" and "Open" or "Take",
            b.x + ox, b.y + oy + b.h / 2 - 9, b.w, "center")
    end

    -- Inspect hint + tooltip, once everything is revealed.
    if self:isRevealed() then
        local hint = InputMode.isGamepad() and "D-pad to inspect  -  A to take"
            or "Hover / arrows to inspect  -  Enter to take"
        love.graphics.setFont(self.hintFont)
        love.graphics.setColor(0.55, 0.6, 0.7)
        love.graphics.printf(hint, bx, self.button.y + oy - 30, self.boxW, "center")

        -- In mouse mode the tooltip only shows while the cursor is actually over a card -- move off the
        -- cards and it goes away. Keyboard/gamepad always inspect the focused card (there is no "off").
        local focused = self.items[self.focus]
        if focused and (not InputMode.isMouse() or self.hoverCard) then
            -- Anchor to the focused card, not the cursor: the reveal inspects one card at a time, so a
            -- tooltip pinned beside the card reads steadily. A mouse-following tooltip jitters and, on a
            -- card near the panel's right edge, kept sliding under the cursor.
            local slot = self.slots[self.focus]
            ItemTooltip.draw(focused, slot.cx + CARD_W / 2 + ox, slot.cy - 40 + oy, Scale.WIDTH)
        end
    end

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

-- ---- input -------------------------------------------------------------------

function LootReveal:mousemoved(x, y)
    self.mx, self.my = x, y
    self.closeButton:mousemoved(x, y)
    self.button.hovered = self:buttonMode() ~= nil and inRect(self.button, x, y)
    self.hoverCard = nil
    if self:isRevealed() then
        for i = 1, #self.items do
            if inRect(self:cardRect(i), x, y) then self.focus = i; self.hoverCard = i; break end
        end
    end
end

function LootReveal:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    if self:buttonMode() and inRect(self.button, x, y) then return "hand" end
    if self:isRevealed() then
        for i = 1, #self.items do
            if inRect(self:cardRect(i), x, y) then return "hand" end
        end
    end
    return "arrow"
end

function LootReveal:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then
        self:close()
        return
    end
    local mode = self:buttonMode()
    if not self.opened then
        -- Closed: only the Open button starts it (a click elsewhere does nothing, like a modal).
        if mode == "open" and inRect(self.button, x, y) then self:open() end
        return
    end
    if not self:isRevealed() then
        self:skip()
        return
    end
    if inRect(self.button, x, y) then
        self:close()
    else
        for i = 1, #self.items do
            if inRect(self:cardRect(i), x, y) then self.focus = i; break end
        end
    end
end

function LootReveal:moveFocus(dir)
    if not self:isRevealed() then return end
    self.focus = ((self.focus - 1 + dir) % #self.items) + 1
end

-- Confirm (Enter / A): Open while closed, skip mid-animation, Take once revealed.
function LootReveal:confirm()
    if not self.opened then
        self:open()
    elseif not self:isRevealed() then
        self:skip()
    else
        self:close()
    end
end

function LootReveal:keypressed(key)
    if key == "escape" then
        self:close()
    elseif key == "left" or key == "a" then
        self:moveFocus(-1)
    elseif key == "right" or key == "d" then
        self:moveFocus(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:confirm()
    end
end

function LootReveal:gamepadpressed(_, button)
    if button == "b" then
        self:close()
    elseif button == "dpleft" then
        self:moveFocus(-1)
    elseif button == "dpright" then
        self:moveFocus(1)
    elseif button == "a" or button == "start" then
        self:confirm()
    end
end

return LootReveal
