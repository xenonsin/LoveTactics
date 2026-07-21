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
local Combat = require("models.combat")
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
-- "default action" badge (gold/filled when pinned, faint outline when merely pinnable).
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

-- Draw the default-action star at (cx, cy): gold + filled when `pinned` (this cell IS the default),
-- a faint gold outline otherwise (the affordance that it CAN be pinned). Shared by the cell badge
-- and the loadout legend so the two read as the same mark. Exposed as InventoryGrid.drawStar.
local function drawStar(cx, cy, r, pinned)
    if pinned then
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.circle("fill", cx, cy, r + 2)
        love.graphics.setColor(0.98, 0.82, 0.30)
        love.graphics.polygon("fill", starPoints(cx, cy, r))
        love.graphics.setColor(0.4, 0.3, 0.05)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", starPoints(cx, cy, r))
    else
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.circle("fill", cx, cy, r + 2)
        love.graphics.setColor(0.85, 0.85, 0.55, 0.55)
        love.graphics.setLineWidth(1.5)
        love.graphics.polygon("line", starPoints(cx, cy, r))
    end
    love.graphics.setLineWidth(1)
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
    self.countFont = love.graphics.newFont(12)
    self.gridW = COLS * self.slot + (COLS - 1) * self.gap
    self.gridH = ROWS * self.slot + (ROWS - 1) * self.gap
    return self
end

function InventoryGrid:setChar(char)
    self.char = char
    self.picked = nil
end

-- The item currently "in hand": the one this grid picked up, or one the host is dragging in from
-- outside it (the Party screen's stash -- set through setHeldItem, since it isn't in the grid yet).
function InventoryGrid:heldItem()
    if self.held then return self.held end
    return self.picked and self.char and self.char.inventory[self.picked] or nil
end

-- Tell the grid about an item being dragged over it from elsewhere, so the placement hints below
-- light up for it too. Pass nil when the drag ends.
function InventoryGrid:setHeldItem(item)
    self.held = item
end

-- Cells where the held item would have its adjacency requirement met (Rain of Arrows: the cells that
-- touch a bow), as an index set. Empty unless something requiring a neighbor is in hand -- an item
-- with no requirement can go anywhere, so lighting cells would say nothing.
function InventoryGrid:candidateCells()
    local item = self:heldItem()
    if not item then return {} end
    return Combat.adjacencyCandidateCells(self.char, item)
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

-- Does cell `i` hold an ability item (a default-action candidate)? Mirrors Combat.defaultAction's
-- test so the star badge only offers itself on cells that can be pinned -- any ability, not just a
-- weapon (a spell or a heal can be the default action too).
function InventoryGrid:isActionCell(i)
    local item = self.char and i and self.char.inventory[i]
    return item ~= nil and item.activeAbility ~= nil
end

-- Top-right corner rect where an action cell's "default action" star badge is drawn / clicked. A
-- touch larger than the badge so the mouse target is easy and doesn't fight the item pickup.
function InventoryGrid:starRect(i)
    local sx, sy, sw = self:slotRect(i)
    local d = 26
    return sx + sw - d - 2, sy + 2, d, d
end

-- The action cell whose star badge is under (px, py), or nil. Lets the host show a star tooltip and
-- swap the click's meaning (pin the default) for the item pickup on that corner of the cell.
function InventoryGrid:starAt(px, py)
    local i = self:indexAt(px, py)
    if not (i and self:isActionCell(i)) then return nil end
    local rx, ry, rw, rh = self:starRect(i)
    if px >= rx and px <= rx + rw and py >= ry and py <= ry + rh then return i end
    return nil
end

-- Pin (or un-pin) cell `i` as the character's default action. Only ability cells qualify; clicking
-- the current default toggles it back to the auto pick (nil). Combat.defaultAction reads
-- char.defaultActionSlot, validating it still holds an ability item, so a stale pin is harmless.
function InventoryGrid:setDefaultAt(i)
    if not (self.char and self:isActionCell(i)) then return false end
    if self.char.defaultActionSlot == i then
        self.char.defaultActionSlot = nil
    else
        self.char.defaultActionSlot = i
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

    -- Cells that would satisfy the held item's adjacency requirement. Computed once here and reused
    -- by the plate wash and the outline pass below.
    local candidates = self:candidateCells()

    -- Cell plates, then the adjacency wires across them -- both under the items, so a wire reads
    -- over the plate without ever covering an icon or a name band.
    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        local item = inv[i]
        if candidates[i] then
            love.graphics.setColor(0.16, 0.30, 0.20) -- green: drop the held item here and it works
        elseif item and Item.isBound(item) then
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

    -- Default-action star, top-right of each ability cell: gold + filled on the pinned default,
    -- a faint outline on the other ability cells (the affordance that they can be pinned). Cells
    -- with no ability get nothing. Drawn over the items so it is never hidden by an icon.
    for i = 1, COLS * ROWS do
        if self:isActionCell(i) then
            local rx, ry, rw = self:starRect(i)
            drawStar(rx + rw / 2, rw / 2 + ry, rw * 0.42, self.char.defaultActionSlot == i)
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

    -- Stack count, top-left of any cell holding more than one of a stackable consumable (mirrors the
    -- "xN" badge on the stash's pool_grid). Placed opposite the top-right star and over a dark pill so
    -- it reads over the icon; a stacking consumable is never a bound relic, so it won't meet the lock.
    for i = 1, COLS * ROWS do
        local item = inv[i]
        if item and (item.quantity or 1) > 1 then
            local sx, sy = self:slotRect(i)
            local label = "x" .. item.quantity
            love.graphics.setFont(self.countFont)
            local w = self.countFont:getWidth(label)
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle("fill", sx + 3, sy + 3, w + 8, 16, 4, 4)
            love.graphics.setColor(0.90, 0.91, 0.96)
            love.graphics.print(label, sx + 7, sy + 4)
        end
    end

    -- Green rims over the candidate plates, so a cell that already holds an item still reads as a
    -- valid drop (its icon covers most of the wash underneath). Drawn before the selection overlays
    -- below, which must stay the brightest marks on the grid.
    for i = 1, COLS * ROWS do
        if candidates[i] then
            local sx, sy, sw, sh = self:slotRect(i)
            love.graphics.setColor(0.40, 0.90, 0.50, 0.85)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", sx + 1, sy + 1, sw - 2, sh - 2, 6, 6)
        end
    end
    love.graphics.setLineWidth(1)

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
    self.hoverStar = self:starAt(x, y) -- the star badge under the pointer, or nil (drives its tooltip)
end

-- Returns true if the click landed on a cell (so the panel can treat it as handled).
function InventoryGrid:mousepressed(x, y, button)
    if button ~= 1 then return false end
    local i = self:indexAt(x, y)
    if not i then return false end
    self.cursor = i
    -- A click on an ability cell's star badge pins/un-pins the default action instead of picking the
    -- item up (checked before activate so the two never fire on one click).
    if self:isActionCell(i) then
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

-- The default-action star mark, for the host's legend (same look as the cell badge).
InventoryGrid.drawStar = drawStar

return InventoryGrid
