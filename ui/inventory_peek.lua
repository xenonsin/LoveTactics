-- The inventory peek: a small floating card that shows a foe's ASSAYED kit (the Assayer's Eye ability,
-- data/items/ability/ability_assayers_eye.lua). Given a foe whose inventory has been revealed
-- (Combat.inventoryRevealed), it draws that foe's 3x3 item grid as read-only icons, laid out the same
-- way the owner's own grid is (ui/combat_panel.lua), and exposes itemAt(mx, my) so the battle state can
-- pop the shared ItemTooltip on hover.
--
-- It is anchored to a point (the foe's board token) and clamped on-screen, but does NOT follow the
-- cursor: the whole point is that the player can move the mouse ONTO it and hover its slots. The battle
-- state keeps it open while the cursor is over the assayed foe OR over this card (peek:contains), so
-- moving between the two never dismisses it.
--
-- Icons follow the same fallback the item grid uses: `item.sprite` is either a loaded image (drawn
-- scaled to the slot) or, when the art is missing, a rounded placeholder carrying the item's initial.

local Scale = require("scale")
local Colors = require("ui.colors")

local InventoryPeek = {}
InventoryPeek.__index = InventoryPeek

local COLS, ROWS = 3, 3
local SLOT = 40
local GAP = 4
local PAD = 8
local TITLE_H = 20

local GRID_W = COLS * SLOT + (COLS - 1) * GAP
local GRID_H = ROWS * SLOT + (ROWS - 1) * GAP
local CARD_W = GRID_W + PAD * 2
local CARD_H = TITLE_H + GRID_H + PAD * 2

function InventoryPeek.new()
    local self = setmetatable({}, InventoryPeek)
    self.titleFont = love.graphics.newFont(13)
    self.initFont = love.graphics.newFont(16)
    self.rect = nil     -- {x, y, w, h} of the last-drawn card, for contains()
    self.slots = {}     -- last-drawn slot rects {x, y, w, h, item}, for itemAt()
    return self
end

-- The card rect for a foe token at (anchorX, anchorY), placed to the token's RIGHT when there's room
-- and to its LEFT otherwise, then clamped inside [minX, maxX] x [4, HEIGHT-4] so it never slides under
-- the side columns or off-screen. Pure, so draw() and any hit-test agree on where the card sits.
local function layoutRect(anchorX, anchorY, minX, maxX)
    local x = anchorX + SLOT * 0.6
    if x + CARD_W > maxX then x = anchorX - SLOT * 0.6 - CARD_W end
    x = math.max(minX, math.min(x, maxX - CARD_W))
    local y = anchorY - CARD_H / 2
    y = math.max(4, math.min(y, Scale.HEIGHT - CARD_H - 4))
    return x, y
end

-- Draw the read-only kit of `unit` anchored near (anchorX, anchorY), clamped within [minX, maxX].
-- Caches the card + slot rects so contains()/itemAt() can be called against the same frame.
function InventoryPeek:draw(unit, anchorX, anchorY, minX, maxX)
    self.slots = {}
    if not (unit and unit.char) then self.rect = nil; return end
    local bx, by = layoutRect(anchorX, anchorY, minX, maxX)
    self.rect = { x = bx, y = by, w = CARD_W, h = CARD_H }

    -- Plate + a foe-red border, so an assayed enemy's card reads as an enemy's.
    love.graphics.setColor(0.09, 0.10, 0.13, 0.96)
    love.graphics.rectangle("fill", bx, by, CARD_W, CARD_H, 6, 6)
    local ec = Colors.unit(unit)
    love.graphics.setColor(ec[1] * 0.9, ec[2] * 0.9, ec[3] * 0.9, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bx, by, CARD_W, CARD_H, 6, 6)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.94, 0.90, 0.80, 1)
    local title = (unit.char.name or "Foe") .. " — Kit"
    love.graphics.printf(title, bx + PAD, by + 4, GRID_W, "left")

    local gx, gy = bx + PAD, by + TITLE_H + PAD
    for i = 1, COLS * ROWS do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local sx = gx + col * (SLOT + GAP)
        local sy = gy + row * (SLOT + GAP)
        love.graphics.setColor(0.16, 0.17, 0.22, 1)
        love.graphics.rectangle("fill", sx, sy, SLOT, SLOT, 5, 5)

        local item = unit.char.inventory[i]
        if item then
            self.slots[#self.slots + 1] = { x = sx, y = sy, w = SLOT, h = SLOT, item = item }
            local sprite = item.sprite
            local icx, icy = sx + SLOT / 2, sy + SLOT / 2
            if type(sprite) == "userdata" then
                love.graphics.setColor(1, 1, 1)
                local iw, ih = sprite:getDimensions()
                local scale = math.min((SLOT - 6) / iw, (SLOT - 6) / ih)
                love.graphics.draw(sprite, icx, icy, 0, scale, scale, iw / 2, ih / 2)
            else
                -- Art missing: a rounded placeholder with the item's initial (mirrors the item grid).
                local ph = SLOT - 12
                love.graphics.setColor(0.5, 0.5, 0.55)
                love.graphics.rectangle("fill", icx - ph / 2, sy + 4, ph, ph, 4, 4)
                love.graphics.setFont(self.initFont)
                love.graphics.setColor(0.95, 0.95, 0.98)
                love.graphics.printf((item.name or "?"):sub(1, 1), icx - ph / 2, icy - 9, ph, "center")
            end
        end
    end

    -- A foe that carries nothing worth reading still gets a card, so the reveal never reads as broken.
    if #self.slots == 0 then
        love.graphics.setFont(self.titleFont)
        love.graphics.setColor(0.62, 0.65, 0.72, 1)
        love.graphics.printf("Carries nothing", gx, gy + GRID_H / 2 - 8, GRID_W, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

-- Is (mx, my) inside the last-drawn card? The battle state keeps the peek open while true, so the
-- cursor can travel from the foe onto the card without it closing.
function InventoryPeek:contains(mx, my)
    local r = self.rect
    return r ~= nil and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
end

-- The item whose slot is under (mx, my), or nil -- drives the shared ItemTooltip.
function InventoryPeek:itemAt(mx, my)
    for _, s in ipairs(self.slots) do
        if mx >= s.x and mx <= s.x + s.w and my >= s.y and my <= s.y + s.h then
            return s.item
        end
    end
    return nil
end

return InventoryPeek
