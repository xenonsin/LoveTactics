-- THE GIFT CARD: what a class unlock hands over, shown after the "Class Unlocked" stat card.
--
-- Unlocking a root drops one ability off that root's own shelf into the stash (Class.unlock's `gift`,
-- models/class.lua). It used to land there silently, so a player who never opened the stash never met
-- the piece the class was built to teach. This card names it: a centred plate over the dimmed frame,
-- the item's icon and name, its full tooltip under them, and where it went.
--
-- HOST CONTRACT: the same as ui/levelup_card.lua's, so a host already holding a level-up card can hold
-- this one in the same slot with no new input routing.
--
--   card = GiftCard.new(itemId, opts)     -- nil when `itemId` names no item
--          -- opts.classId = the class that gave it (heads the plate)
--          -- opts.char    = the body that unlocked it (the tooltip's owner)
--   card:update(dt) / card:draw()
--   card:keypressed / gamepadpressed / mousepressed / mousemoved / wheelmoved -- each eats the input
--   card:press()                          -- the one verb: reveal on the first, dismiss on the second
--   card.done                             -- true once dismissed
--
-- Nothing here touches love.graphics at require time (tests/class_unlock_spec plays it headless).

local Theme = require("ui.theme")
local Scale = require("scale")

local GiftCard = {}
GiftCard.__index = GiftCard

-- The plate fades and rises in over this; a press before it ends finishes it instead of dismissing.
GiftCard.IN = 0.3

local PAD, ICON = 18, 64

function GiftCard.new(itemId, opts)
    opts = opts or {}
    local Item = require("models.item")
    if not (itemId and Item.defs[itemId]) then return nil end
    local self = setmetatable({}, GiftCard)
    self.itemId = itemId
    self.item = Item.instantiate(itemId)
    self.char = opts.char
    self.classId = opts.classId
    local okC, Class = pcall(require, "models.class")
    self.classTitle = (self.classId and okC and Class.displayName and Class.displayName(self.classId)) or nil
    self.t = 0
    self.revealed = false
    self.done = false
    local okS, Sound = pcall(require, "models.sound")
    if okS and Sound.play then Sound.play("treasure.reveal") end
    return self
end

function GiftCard:update(dt)
    if self.done then return end
    self.t = self.t + (dt or 0)
    if self.t >= GiftCard.IN then self.revealed = true end
end

function GiftCard:press()
    if self.done then return "dismissed" end
    if not self.revealed then
        self.t = math.max(self.t, GiftCard.IN)
        self.revealed = true
        return "revealed"
    end
    self.done = true
    return "dismissed"
end

local CONFIRM_KEYS = { ["return"] = true, kpenter = true, space = true, escape = true, z = true, x = true }
function GiftCard:keypressed(key)
    if CONFIRM_KEYS[key] then self:press() end
    return true
end

function GiftCard:gamepadpressed(_, button)
    if button == "a" or button == "b" or button == "start" then self:press() end
    return true
end

function GiftCard:mousepressed(_, _, button)
    if button == nil or button == 1 or button == 2 then self:press() end
    return true
end

function GiftCard:mousemoved() return true end
function GiftCard:wheelmoved() return true end

-- ---------------------------------------------------------------------------------------------- draw

local function ease(x)
    x = math.max(0, math.min(1, x))
    return 1 - (1 - x) * (1 - x) * (1 - x)
end

function GiftCard:draw()
    if self.done then return end
    local ItemTooltip = require("ui.item_tooltip")
    if not self.layout then self.layout = ItemTooltip.measure(self.item, nil, self.char) end
    local a = ease(self.t / GiftCard.IN)

    love.graphics.setColor(0, 0, 0, 0.62 * a)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local head, sub, foot = Theme.display(30), Theme.body(16), Theme.body(13)
    local tipW, tipH = self.layout and self.layout.w or ItemTooltip.WIDTH, self.layout and self.layout.h or 0
    local w = math.max(360, tipW + PAD * 2)
    local headH = 10 + head:getHeight() + 4 + sub:getHeight() + 12
    local iconRowH = ICON + 12
    local footH = foot:getHeight() + 14
    local h = headH + iconRowH + tipH + footH + PAD
    local x = math.floor(Scale.WIDTH / 2 - w / 2)
    local y = math.floor(math.max(12, Scale.HEIGHT / 2 - h / 2) + (1 - a) * 24)

    -- The glow and plate: the stat card's own, so the two read as one ceremony in two beats.
    local breathe = self.revealed and (0.8 + 0.2 * math.sin(self.t * 3)) or 1
    for i = 4, 1, -1 do
        Theme.set(Theme.accentAmber, 0.07 * a * breathe)
        love.graphics.rectangle("fill", x - i * 5, y - i * 5, w + i * 10, h + i * 10, 8 + i * 3, 8 + i * 3)
    end
    Theme.set(Theme.panel, 0.96 * a)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    Theme.set(Theme.accentAmber, 0.85 * a)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setLineWidth(1)

    -- Head.
    love.graphics.setFont(head)
    Theme.set(Theme.accentAmber, a)
    love.graphics.printf("New Item", x + PAD, y + 10, w - PAD * 2, "left")
    love.graphics.setFont(sub)
    Theme.set(Theme.ink, a)
    local line = self.classTitle and (self.classTitle .. " gift") or "Class gift"
    love.graphics.print(line, x + PAD, y + 10 + head:getHeight() + 4)
    Theme.set(Theme.hairline, a)
    love.graphics.line(x + PAD, y + headH - 6, x + w - PAD, y + headH - 6)

    -- Icon and name.
    local iy = y + headH
    local sprite = self.item.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1, a)
        local sw, sh = sprite:getDimensions()
        local s = math.min(ICON / sw, ICON / sh)
        love.graphics.draw(sprite, x + PAD + ICON / 2, iy + ICON / 2, 0, s, s, sw / 2, sh / 2)
    else
        Theme.set(Theme.panel2, a)
        love.graphics.rectangle("fill", x + PAD, iy, ICON, ICON, 6, 6)
        love.graphics.setFont(head)
        Theme.set(Theme.ink, a)
        love.graphics.printf((self.item.name or "?"):sub(1, 1), x + PAD, iy + (ICON - head:getHeight()) / 2,
            ICON, "center")
    end
    local name = Theme.display(24)
    love.graphics.setFont(name)
    Theme.set(Theme.ink, a)
    love.graphics.printf(self.item.name or self.itemId, x + PAD + ICON + 14, iy + (ICON - name:getHeight()) / 2,
        w - PAD * 2 - ICON - 14, "left")

    -- What it does: the full tooltip, pinned inside the plate.
    if self.layout and a > 0.05 then
        ItemTooltip.paint(self.layout, x + (w - tipW) / 2, iy + iconRowH)
    end

    -- Where it went, and the way on.
    local fy = y + h - PAD - foot:getHeight()
    love.graphics.setFont(foot)
    Theme.set(Theme.muted, a)
    love.graphics.printf("Sent to the stash.", x + PAD, fy, w - PAD * 2, "left")
    if self.revealed then
        Theme.set(Theme.muted, 0.6 + 0.4 * math.sin(self.t * 4))
        love.graphics.printf("Continue", x + PAD, fy, w - PAD * 2, "right")
    end
    love.graphics.setColor(1, 1, 1)
end

return GiftCard
