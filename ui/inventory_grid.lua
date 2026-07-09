-- Reusable 3x3 inventory-grid editor. Renders one character's item grid (models/character.lua:
-- a fixed nine cells that may hold gaps) and lets the player rearrange items by PICK-THEN-PLACE:
-- activate a non-empty cell to pick its item up, then activate another cell to SWAP the two cells'
-- contents (swapping with an empty cell is just a move). This is the ONLY place item positions
-- change -- the overworld/hub loadout panel hosts it (ui/panels/loadout.lua); combat never reorders.
--
-- Follows the project's three-input standard, and is fully mouse-only playable: click a source
-- cell then a destination cell (mouse), or drive a cursor with arrows/D-pad + confirm
-- (keyboard/gamepad). Escape/B cancels a pickup (the host panel routes those). Adjacency connector
-- lines (Combat.adjacencyLinks) are drawn over the grid so item-to-item bonuses read at a glance.
--
--   local grid = InventoryGrid.new({ x = , y = , char = char })
--   grid:setChar(char)
--   grid:draw(); grid:mousemoved(x, y); grid:mousepressed(x, y, button)
--   grid:keypressed(key); grid:gamepadpressed(joystick, button); grid:cancelPickup()

local Character = require("models.character")
local Combat = require("models.combat")

local InventoryGrid = {}
InventoryGrid.__index = InventoryGrid

local SLOT = 92
local GAP = 12
local COLS, ROWS = Character.COLS, Character.ROWS

-- Connector-line tint per adjacency relationship kind (see Combat.adjacencyLinks).
InventoryGrid.LINK_COLOR = {
    aura        = { 0.95, 0.55, 0.28 }, -- ember orange (an aura infusing a neighbor)
    boost       = { 0.55, 0.78, 1.00 }, -- steel blue (an ability scaling off a neighbor)
    requirement = { 0.70, 0.88, 0.45 }, -- green (a requirement satisfied by a neighbor)
}

function InventoryGrid.new(opts)
    opts = opts or {}
    local self = setmetatable({}, InventoryGrid)
    self.x = opts.x or 0
    self.y = opts.y or 0
    self.char = opts.char
    self.cursor = 1       -- keyboard/gamepad cursor cell (1..9)
    self.picked = nil     -- the cell currently picked up, or nil
    self.hover = nil      -- mouse-hover cell, or nil
    self.nameFont = love.graphics.newFont(11)
    self.bigFont = love.graphics.newFont(22)
    self.gridW = COLS * SLOT + (COLS - 1) * GAP
    self.gridH = ROWS * SLOT + (ROWS - 1) * GAP
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
    return self.x + col * (SLOT + GAP), self.y + row * (SLOT + GAP), SLOT, SLOT
end

function InventoryGrid:slotCenter(index)
    local sx, sy, sw, sh = self:slotRect(index)
    return sx + sw / 2, sy + sh / 2
end

function InventoryGrid:indexAt(px, py)
    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        if px >= sx and px <= sx + sw and py >= sy and py <= sy + sh then return i end
    end
    return nil
end

-- Move the cursor by (dc, dr) grid steps, clamped to the 3x3.
function InventoryGrid:moveCursor(dc, dr)
    local col = math.max(0, math.min(COLS - 1, (self.cursor - 1) % COLS + dc))
    local row = math.max(0, math.min(ROWS - 1, math.floor((self.cursor - 1) / COLS) + dr))
    self.cursor = row * COLS + col + 1
end

-- Pick up (first activation on a non-empty cell), or place/swap (second activation): exchange the
-- picked cell's contents with cell `i` -- either side may be empty, so this covers plain moves too.
function InventoryGrid:activate(i)
    if not (self.char and i) then return end
    local inv = self.char.inventory
    if self.picked == nil then
        if inv[i] ~= nil then self.picked = i end
    else
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

    -- Cell plates + items.
    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        love.graphics.setColor(0.16, 0.17, 0.22)
        love.graphics.rectangle("fill", sx, sy, sw, sh, 6, 6)

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

    -- Adjacency connector lines, over the plates so relationships read at a glance.
    love.graphics.setLineWidth(3)
    for _, link in ipairs(Combat.adjacencyLinks(self.char)) do
        local c = InventoryGrid.LINK_COLOR[link.kind] or { 0.8, 0.8, 0.8 }
        local ax, ay = self:slotCenter(link.from)
        local bx, by = self:slotCenter(link.to)
        love.graphics.setColor(c[1], c[2], c[3], 0.85)
        love.graphics.line(ax, ay, bx, by)
        love.graphics.circle("fill", ax, ay, 4)
        love.graphics.circle("fill", bx, by, 4)
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
end

-- Returns true if the click landed on a cell (so the panel can treat it as handled).
function InventoryGrid:mousepressed(x, y, button)
    if button ~= 1 then return false end
    local i = self:indexAt(x, y)
    if not i then return false end
    self.cursor = i
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
