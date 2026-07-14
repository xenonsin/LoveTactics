-- Reusable 3x3 inventory-grid editor. Renders one character's item grid (models/character.lua:
-- a fixed nine cells that may hold gaps) and lets the player rearrange items by PICK-THEN-PLACE:
-- activate a non-empty cell to pick its item up, then activate another cell to SWAP the two cells'
-- contents (swapping with an empty cell is just a move). This is the ONLY place item positions
-- change -- the overworld/hub loadout panel hosts it (ui/panels/loadout.lua); combat never reorders.
--
-- Follows the project's three-input standard, and is fully mouse-only playable: click a source
-- cell then a destination cell (mouse), or drive a cursor with arrows/D-pad + confirm
-- (keyboard/gamepad). Escape/B cancels a pickup (the host panel routes those). Adjacency connector
-- wires (ui/adjacency_links.lua) run behind the cards so item-to-item bonuses read at a glance
-- without covering an icon or a name.
--
--   local grid = InventoryGrid.new({ x = , y = , char = char })
--   grid:setChar(char)
--   grid:draw(); grid:mousemoved(x, y); grid:mousepressed(x, y, button)
--   grid:keypressed(key); grid:gamepadpressed(joystick, button); grid:cancelPickup()

local Character = require("models.character")
local Item = require("models.item")
local AdjacencyLinks = require("ui.adjacency_links")

local InventoryGrid = {}
InventoryGrid.__index = InventoryGrid

local SLOT = 92
local GAP = 12
local COLS, ROWS = Character.COLS, Character.ROWS

-- A small gold padlock centered at (x, y), badging a bound cell (a signature relic that can't be
-- moved). Drawn top-left, opposite the top-right default-weapon star, so the two never overlap.
local function drawLock(x, y)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x - 7, y - 7, 14, 15, 3, 3) -- backing so it reads over any icon
    love.graphics.setColor(0.72, 0.58, 0.22)                    -- shackle
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", "open", x, y - 1, 4, math.pi, 2 * math.pi)
    love.graphics.setColor(0.98, 0.82, 0.30)                    -- body
    love.graphics.rectangle("fill", x - 5, y - 1, 10, 7, 2, 2)
    love.graphics.setLineWidth(1)
end

-- Vertices of a 5-point star inscribed in radius `r` about (cx, cy), point-up. Used for the
-- "default weapon" badge (gold/filled when pinned, faint outline when merely pinnable).
local function starPoints(cx, cy, r)
    local pts = {}
    for k = 0, 9 do
        local ang = -math.pi / 2 + k * math.pi / 5
        local rad = (k % 2 == 0) and r or r * 0.42
        pts[#pts + 1] = cx + math.cos(ang) * rad
        pts[#pts + 1] = cy + math.sin(ang) * rad
    end
    return pts
end

function InventoryGrid.new(opts)
    opts = opts or {}
    local self = setmetatable({}, InventoryGrid)
    self.x = opts.x or 0
    self.y = opts.y or 0
    self.char = opts.char
    -- Cell size is configurable so a cramped host (the Party screen's narrow member column) can
    -- shrink the grid; defaults keep every existing caller unchanged.
    self.slot = opts.slot or SLOT
    self.gap = opts.gap or GAP
    self.cursor = 1       -- keyboard/gamepad cursor cell (1..9)
    self.picked = nil     -- the cell currently picked up, or nil
    self.hover = nil      -- mouse-hover cell, or nil
    self.nameFont = love.graphics.newFont(11)
    self.bigFont = love.graphics.newFont(22)
    self.gridW = COLS * self.slot + (COLS - 1) * self.gap
    self.gridH = ROWS * self.slot + (ROWS - 1) * self.gap
    return self
end

function InventoryGrid:setChar(char)
    self.char = char
    self.picked = nil
end

-- Cell rect for a 1-based index (row-major -- matches ui/combat_panel.lua and Character grid math).
function InventoryGrid:slotRect(index)
    local col = (index - 1) % COLS
    local row = math.floor((index - 1) / COLS)
    return self.x + col * (self.slot + self.gap), self.y + row * (self.slot + self.gap), self.slot, self.slot
end

function InventoryGrid:indexAt(px, py)
    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        if px >= sx and px <= sx + sw and py >= sy and py <= sy + sh then return i end
    end
    return nil
end

-- Does cell `i` hold an attackable weapon (a default-weapon candidate)? Mirrors
-- Combat.defaultWeapon's test so the star badge only offers itself on cells that can be pinned.
function InventoryGrid:isWeaponCell(i)
    local item = self.char and i and self.char.inventory[i]
    return item ~= nil and item.type == "weapon" and item.activeAbility ~= nil
end

-- Top-right corner rect where a weapon cell's "default weapon" star badge is drawn / clicked.
function InventoryGrid:starRect(i)
    local sx, sy, sw = self:slotRect(i)
    local d = 20
    return sx + sw - d - 3, sy + 3, d, d
end

-- Pin (or un-pin) cell `i` as the character's default attack weapon. Only weapon cells qualify;
-- clicking the current default toggles it back to the auto pick (nil). Combat.defaultWeapon reads
-- char.defaultWeaponSlot, validating it still holds a weapon, so a stale pin is harmless.
function InventoryGrid:setDefaultAt(i)
    if not (self.char and self:isWeaponCell(i)) then return false end
    if self.char.defaultWeaponSlot == i then
        self.char.defaultWeaponSlot = nil
    else
        self.char.defaultWeaponSlot = i
    end
    return true
end

-- Move the cursor by (dc, dr) grid steps, clamped to the 3x3.
function InventoryGrid:moveCursor(dc, dr)
    local col = math.max(0, math.min(COLS - 1, (self.cursor - 1) % COLS + dc))
    local row = math.max(0, math.min(ROWS - 1, math.floor((self.cursor - 1) / COLS) + dr))
    self.cursor = row * COLS + col + 1
end

-- Pick up (first activation on a non-empty cell), or place/swap (second activation): exchange the
-- picked cell's contents with cell `i` -- either side may be empty, so this covers plain moves too.
-- A bound item (a signature relic, Item.isBound) is nailed to its cell: it can't be picked up, and no
-- other item can be swapped into its cell, so it never moves.
function InventoryGrid:activate(i)
    if not (self.char and i) then return end
    local inv = self.char.inventory
    if self.picked == nil then
        if inv[i] ~= nil and not Item.isBound(inv[i]) then self.picked = i end
    else
        if Item.isBound(inv[i]) then return end -- can't displace a bound item from its cell
        inv[self.picked], inv[i] = inv[i], inv[self.picked]
        self.picked = nil
    end
end

-- Cancel an in-progress pickup. Returns true if there was one (so the host panel knows whether an
-- Esc/B press was consumed here or should close the panel instead).
function InventoryGrid:cancelPickup()
    if self.picked ~= nil then
        self.picked = nil
        return true
    end
    return false
end

function InventoryGrid:draw()
    if not self.char then return end
    local inv = self.char.inventory

    -- Cell plates, then the adjacency wires across them -- both under the items, so a wire reads
    -- over the plate without ever covering an icon or a name band.
    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        local item = inv[i]
        if item and Item.isBound(item) then
            love.graphics.setColor(0.24, 0.20, 0.14) -- a warm plate marks a bound (locked) cell
        else
            love.graphics.setColor(0.16, 0.17, 0.22)
        end
        love.graphics.rectangle("fill", sx, sy, sw, sh, 6, 6)
    end
    AdjacencyLinks.draw(self.char, function(i) return self:slotRect(i) end, { width = 3 })

    -- Items.
    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        local item = inv[i]
        if item then
            local lifted = (self.picked == i)
            local dim = lifted and 0.5 or 1
            local sprite = item.sprite
            local icx, icy = sx + sw / 2, sy + sh / 2
            if type(sprite) == "userdata" then
                love.graphics.setColor(dim, dim, dim)
                local iw, ih = sprite:getDimensions()
                local scale = math.min((sw - 12) / iw, (sh - 20) / ih)
                love.graphics.draw(sprite, icx, icy - 6, 0, scale, scale, iw / 2, ih / 2)
            else
                local ph = sh - 26
                love.graphics.setColor(0.5 * dim, 0.5 * dim, 0.56 * dim)
                love.graphics.rectangle("fill", icx - ph / 2, sy + 6, ph, ph, 6, 6)
                love.graphics.setFont(self.bigFont)
                love.graphics.setColor(dim, dim, dim)
                love.graphics.printf((item.name or "?"):sub(1, 1), icx - ph / 2, icy - 20, ph, "center")
            end

            -- Name band along the bottom, scaled to fit on one line.
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle("fill", sx + 1, sy + sh - 16, sw - 2, 15, 0, 0, 6, 6)
            love.graphics.setFont(self.nameFont)
            local name = item.name or "?"
            local nw = self.nameFont:getWidth(name)
            local sc = math.min(1, (sw - 8) / nw)
            love.graphics.setColor(0.95, 0.95, 0.97)
            love.graphics.print(name, sx + sw / 2 - (nw * sc) / 2, sy + sh - 15, 0, sc, sc)
        end
    end

    -- Default-weapon star, top-right of each weapon cell: gold + filled on the pinned default,
    -- a faint outline on the other weapons (the affordance that they can be pinned). Non-weapon
    -- cells get nothing. Drawn over the items so it is never hidden by an icon.
    for i = 1, COLS * ROWS do
        if self:isWeaponCell(i) then
            local rx, ry, rw = self:starRect(i)
            local cx, cy, r = rx + rw / 2, ry + rw / 2, rw * 0.5
            local pts = starPoints(cx, cy, r)
            local pinned = (self.char.defaultWeaponSlot == i)
            if pinned then
                love.graphics.setColor(0, 0, 0, 0.55)
                love.graphics.circle("fill", cx, cy, r + 2)
                love.graphics.setColor(0.98, 0.82, 0.30)
                love.graphics.polygon("fill", pts)
                love.graphics.setColor(0.4, 0.3, 0.05)
                love.graphics.setLineWidth(1)
                love.graphics.polygon("line", pts)
            else
                love.graphics.setColor(0, 0, 0, 0.35)
                love.graphics.circle("fill", cx, cy, r + 2)
                love.graphics.setColor(0.85, 0.85, 0.55, 0.55)
                love.graphics.setLineWidth(1.5)
                love.graphics.polygon("line", pts)
            end
        end
    end
    love.graphics.setLineWidth(1)

    -- Bound cells (signature relics) get a padlock badge, top-left, so the lock reads at a glance.
    -- Drawn over the items so an icon never hides it, and opposite the top-right default-weapon star.
    for i = 1, COLS * ROWS do
        local item = inv[i]
        if item and Item.isBound(item) then
            local sx, sy = self:slotRect(i)
            drawLock(sx + 13, sy + 13)
        end
    end

    -- Selection overlays: hover (mouse), the keyboard/gamepad cursor, and the picked-up cell.
    if self.hover then
        local sx, sy, sw, sh = self:slotRect(self.hover)
        love.graphics.setColor(0.95, 0.85, 0.55, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx, sy, sw, sh, 6, 6)
    end
    do
        local sx, sy, sw, sh = self:slotRect(self.cursor)
        love.graphics.setColor(0.6, 0.75, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx - 2, sy - 2, sw + 4, sh + 4, 7, 7)
    end
    if self.picked then
        local sx, sy, sw, sh = self:slotRect(self.picked)
        love.graphics.setColor(0.95, 0.85, 0.35)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", sx, sy, sw, sh, 6, 6)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
end

function InventoryGrid:mousemoved(x, y)
    self.hover = self:indexAt(x, y)
end

-- Returns true if the click landed on a cell (so the panel can treat it as handled).
function InventoryGrid:mousepressed(x, y, button)
    if button ~= 1 then return false end
    local i = self:indexAt(x, y)
    if not i then return false end
    self.cursor = i
    -- A click on a weapon cell's star badge pins/un-pins the default weapon instead of picking the
    -- item up (checked before activate so the two never fire on one click).
    if self:isWeaponCell(i) then
        local rx, ry, rw, rh = self:starRect(i)
        if x >= rx and x <= rx + rw and y >= ry and y <= ry + rh then
            self:setDefaultAt(i)
            return true
        end
    end
    self:activate(i)
    return true
end

function InventoryGrid:keypressed(key)
    if key == "left" or key == "a" then self:moveCursor(-1, 0)
    elseif key == "right" or key == "d" then self:moveCursor(1, 0)
    elseif key == "up" or key == "w" then self:moveCursor(0, -1)
    elseif key == "down" or key == "s" then self:moveCursor(0, 1)
    elseif key == "return" or key == "kpenter" or key == "space" then self:activate(self.cursor)
    end
end

function InventoryGrid:gamepadpressed(_, button)
    if button == "dpleft" then self:moveCursor(-1, 0)
    elseif button == "dpright" then self:moveCursor(1, 0)
    elseif button == "dpup" then self:moveCursor(0, -1)
    elseif button == "dpdown" then self:moveCursor(0, 1)
    elseif button == "a" then self:activate(self.cursor)
    end
end

return InventoryGrid
