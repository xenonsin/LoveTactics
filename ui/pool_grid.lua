-- Reusable scrolling grid of items with hover tooltips: the shared "pool" surface for the Party
-- screen (ui/panels/party.lua). It is the grid-shaped successor to ui/stash_list.lua's vertical
-- list, and renders one of two backing sources:
--
--   * a STASH -- real owned Item instances (setItems(player.stash)); cell index maps 1:1 to the
--     stash list, and a stackable consumable shows an "xN" count.
--   * a STORE -- catalog entries from Vendor.stock (setStore(entries)); each cell is a buyable
--     TYPE (never consumed), showing its price and a greyed overlay when rank-locked.
--
-- Like the grid and the old list it is PICK-THEN-PLACE: activating a cell picks it up (`picked`);
-- the host panel reads that and performs the actual transfer (a plain move, a buy, or a sell). It
-- never mutates ownership itself, so the pool and a character's grid can't disagree about who holds
-- what. Dragging a cell is the same transfer by another route, resolved by the panel.
--
-- Follows the three-input standard and is fully mouse-only playable: click a cell, or the scroll
-- arrows (the wheel is a shortcut, never the only way); or drive the cursor with arrows/D-pad +
-- confirm, which scrolls the view to follow. The host draws the tooltip (ui/item_tooltip.lua) for
-- whatever `hover`/`cursor` names, via :itemAt.
--
--   local pool = PoolGrid.new({ x =, y =, w =, h = })
--   pool:setItems(player.stash)        -- stash source
--   pool:setStore(Vendor.stock(...))   -- store source
--   pool:draw(); pool:mousemoved(x, y); pool:mousepressed(x, y, button) -> handled, index
--   pool:wheelmoved(dy); pool:contains(x, y); pool:itemAt(i); pool:cellAt(i)
--   pool:keypressed(key); pool:gamepadpressed(joystick, button); pool:cancelPickup()

local Item = require("models.item")

local PoolGrid = {}
PoolGrid.__index = PoolGrid

local CELL = 64
local GAP = 8
local ARROW_H = 20 -- clickable scroll arrows above and below the grid

-- Icon/plate tint per item type, matching ui/item_tooltip.lua and the old stash list.
local TYPE_COLOR = {
    weapon = { 0.90, 0.58, 0.48 },
    armor = { 0.58, 0.72, 0.92 },
    consumable = { 0.52, 0.85, 0.55 },
    ability = { 0.78, 0.62, 0.96 },
    utility = { 0.92, 0.82, 0.52 },
}
local DEFAULT_COLOR = { 0.80, 0.80, 0.86 }

function PoolGrid.new(opts)
    opts = opts or {}
    local self = setmetatable({}, PoolGrid)
    self.x, self.y = opts.x or 0, opts.y or 0
    self.w, self.h = opts.w or 300, opts.h or 300
    self.cells = {}     -- normalized render list (see :setItems / :setStore)
    self.mode = "stash" -- "stash" | "store"
    self.cursor = 1     -- keyboard/gamepad cursor cell (1-based)
    self.offset = 0     -- first visible ROW - 1
    self.picked = nil   -- the cell currently picked up, or nil
    self.hover = nil
    self.focused = false
    self.nameFont = love.graphics.newFont(11)
    self.smallFont = love.graphics.newFont(11)
    self.bigFont = love.graphics.newFont(20)

    -- Cells tile between the two scroll arrows.
    self.gridY = self.y + ARROW_H
    self.gridH = self.h - ARROW_H * 2
    self.cols = math.max(1, math.floor((self.w + GAP) / (CELL + GAP)))
    self.visRows = math.max(1, math.floor((self.gridH + GAP) / (CELL + GAP)))
    self.upArrow = { x = self.x, y = self.y, w = self.w, h = ARROW_H }
    self.downArrow = { x = self.x, y = self.y + self.h - ARROW_H, w = self.w, h = ARROW_H }
    return self
end

-- Point this pool at a live list of owned Item instances (the stash). Cell index maps 1:1 to the
-- list, so the host can turn a picked index straight into a stash index.
function PoolGrid:setItems(list)
    self.mode = "stash"
    self.source = list or {}
    self.cells = {}
    for _, item in ipairs(self.source) do
        self.cells[#self.cells + 1] = { item = item }
    end
    self:clampView()
end

-- Point this pool at a vendor's stock (Vendor.stock entries). Each entry becomes a buyable cell;
-- a preview Item instance is built so the icon/name/tooltip render like any other item, while
-- price/locked come from the entry.
function PoolGrid:setStore(entries)
    self.mode = "store"
    self.source = entries or {}
    self.cells = {}
    for _, entry in ipairs(self.source) do
        self.cells[#self.cells + 1] = {
            item = Item.instantiate(entry.id),
            entry = entry,
            price = entry.price,
            locked = entry.locked,
        }
    end
    self:clampView()
end

-- The list changed under us (an item left or arrived). Drop any pickup -- the cell it named may be a
-- different item now -- rebuild, and pull cursor/scroll back into range without jumping to the top.
function PoolGrid:refresh()
    if self.mode == "store" then self:setStore(self.source) else self:setItems(self.source) end
end

function PoolGrid:clampView()
    self.picked = nil
    self.hover = nil
    self.cursor = math.max(1, math.min(math.max(1, self:count()), self.cursor))
    self.offset = math.max(0, math.min(self:maxOffset(), self.offset))
end

function PoolGrid:count() return #self.cells end
function PoolGrid:totalRows() return math.ceil(self:count() / self.cols) end
function PoolGrid:maxOffset() return math.max(0, self:totalRows() - self.visRows) end
function PoolGrid:cellAt(i) return self.cells[i] end

-- The Item instance in cell `i` (for the host's tooltip), or nil.
function PoolGrid:itemAt(i)
    local cell = self.cells[i]
    return cell and cell.item
end

function PoolGrid:scroll(deltaRows)
    self.offset = math.max(0, math.min(self:maxOffset(), self.offset + deltaRows))
end

function PoolGrid:wheelmoved(dy)
    self:scroll(-dy) -- dy > 0 is a push away from the user -> earlier rows
end

-- Whole-widget hit test (arrows included) -- the host uses it as a drop target for a dragged item.
function PoolGrid:contains(x, y)
    return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

-- Screen rect of cell `i` (1-based), or nil if it is scrolled out of view.
function PoolGrid:cellRect(i)
    local row = math.floor((i - 1) / self.cols)
    local col = (i - 1) % self.cols
    local visRow = row - self.offset
    if visRow < 0 or visRow >= self.visRows then return nil end
    return self.x + col * (CELL + GAP), self.gridY + visRow * (CELL + GAP), CELL, CELL
end

function PoolGrid:indexAt(px, py)
    for i = 1, self:count() do
        local rx, ry, rw, rh = self:cellRect(i)
        if rx and px >= rx and px <= rx + rw and py >= ry and py <= ry + rh then return i end
    end
    return nil
end

-- Keep the cursor cell on screen after it moves.
function PoolGrid:scrollToCursor()
    local row = math.floor((self.cursor - 1) / self.cols)
    if row < self.offset then
        self.offset = row
    elseif row >= self.offset + self.visRows then
        self.offset = row - self.visRows + 1
    end
    self.offset = math.max(0, math.min(self:maxOffset(), self.offset))
end

function PoolGrid:moveCursor(dc, dr)
    local n = self:count()
    if n == 0 then return end
    self.cursor = math.max(1, math.min(n, self.cursor + dc + dr * self.cols))
    self:scrollToCursor()
end

-- Pick up cell `i` (or drop the current pickup if it's the same cell). The host reads `picked` and
-- performs the actual move/buy/sell.
function PoolGrid:activate(i)
    if not i or not self.cells[i] then return end
    if self.picked == i then self.picked = nil else self.picked = i end
end

function PoolGrid:cancelPickup()
    if self.picked ~= nil then
        self.picked = nil
        return true
    end
    return false
end

local function pointIn(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function PoolGrid:draw()
    -- Backing well.
    love.graphics.setColor(0.10, 0.11, 0.15)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 6, 6)
    love.graphics.setColor(self.focused and 0.60 or 0.30, self.focused and 0.70 or 0.34,
        self.focused and 0.92 or 0.42)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 6, 6)

    if self:count() == 0 then
        love.graphics.setFont(self.nameFont)
        love.graphics.setColor(0.5, 0.52, 0.6)
        local empty = self.mode == "store" and "Nothing for sale" or "Stash is empty"
        love.graphics.printf(empty, self.x, self.y + self.h / 2 - 8, self.w, "center")
        love.graphics.setColor(1, 1, 1)
        return
    end

    -- Scroll arrows, dimmed at the ends of the list (still drawn, so the column never reflows).
    love.graphics.setFont(self.smallFont)
    local canUp, canDown = self.offset > 0, self.offset < self:maxOffset()
    love.graphics.setColor(0.7, 0.74, 0.85, canUp and 0.95 or 0.25)
    love.graphics.printf("^", self.upArrow.x, self.upArrow.y + 4, self.upArrow.w, "center")
    love.graphics.setColor(0.7, 0.74, 0.85, canDown and 0.95 or 0.25)
    love.graphics.printf("v", self.downArrow.x, self.downArrow.y + 4, self.downArrow.w, "center")

    for i = 1, self:count() do
        local sx, sy = self:cellRect(i)
        if sx then self:drawCell(i, sx, sy) end
    end
    love.graphics.setColor(1, 1, 1)
end

function PoolGrid:drawCell(i, sx, sy)
    local cell = self.cells[i]
    local item = cell.item
    local lifted = (self.picked == i)
    local dim = lifted and 0.5 or 1
    local col = TYPE_COLOR[item.type] or DEFAULT_COLOR

    love.graphics.setColor(0.16, 0.17, 0.22)
    love.graphics.rectangle("fill", sx, sy, CELL, CELL, 6, 6)

    -- Icon: the item's art, or its initial on a type-tinted plate.
    local sprite = item.sprite
    local icx, icy = sx + CELL / 2, sy + CELL / 2
    if type(sprite) == "userdata" then
        love.graphics.setColor(dim, dim, dim)
        local iw, ih = sprite:getDimensions()
        local scale = math.min((CELL - 12) / iw, (CELL - 22) / ih)
        love.graphics.draw(sprite, icx, icy - 6, 0, scale, scale, iw / 2, ih / 2)
    else
        local ph = CELL - 26
        love.graphics.setColor(col[1] * 0.5 * dim, col[2] * 0.5 * dim, col[3] * 0.5 * dim)
        love.graphics.rectangle("fill", icx - ph / 2, sy + 5, ph, ph, 5, 5)
        love.graphics.setFont(self.bigFont)
        love.graphics.setColor(dim, dim, dim)
        love.graphics.printf((item.name or "?"):sub(1, 1), icx - ph / 2, icy - 18, ph, "center")
    end

    -- Name band along the bottom, scaled to fit one line.
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", sx + 1, sy + CELL - 15, CELL - 2, 14, 0, 0, 6, 6)
    love.graphics.setFont(self.nameFont)
    local name = item.name or "?"
    local nw = self.nameFont:getWidth(name)
    local sc = math.min(1, (CELL - 6) / nw)
    love.graphics.setColor(col[1] * dim, col[2] * dim, col[3] * dim)
    love.graphics.print(name, sx + CELL / 2 - (nw * sc) / 2, sy + CELL - 14, 0, sc, sc)

    -- Corner badge: a store price, or a stack count.
    love.graphics.setFont(self.smallFont)
    if self.mode == "store" then
        love.graphics.setColor(0.95, 0.85, 0.55, dim)
        love.graphics.printf(tostring(cell.price) .. "g", sx, sy + 3, CELL - 4, "right")
    elseif (item.quantity or 1) > 1 then
        love.graphics.setColor(0.90, 0.91, 0.96, dim)
        love.graphics.printf("x" .. item.quantity, sx, sy + 3, CELL - 4, "right")
    end

    -- Rank-locked store cell: greyed, so seeing what standing buys is still possible.
    if cell.locked then
        love.graphics.setColor(0.12, 0.13, 0.18, 0.6)
        love.graphics.rectangle("fill", sx, sy, CELL, CELL, 6, 6)
        love.graphics.setColor(0.9, 0.6, 0.55, 0.9)
        love.graphics.printf("locked", sx, sy + CELL / 2 - 6, CELL, "center")
    end

    -- Overlays: picked (in hand), hover (mouse), the keyboard/gamepad cursor.
    if lifted then
        love.graphics.setColor(0.95, 0.85, 0.35)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", sx, sy, CELL, CELL, 6, 6)
        love.graphics.setLineWidth(1)
    end
    if self.hover == i then
        love.graphics.setColor(0.95, 0.85, 0.55, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx, sy, CELL, CELL, 6, 6)
        love.graphics.setLineWidth(1)
    end
    if self.focused and self.cursor == i then
        love.graphics.setColor(0.6, 0.75, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx - 2, sy - 2, CELL + 4, CELL + 4, 7, 7)
        love.graphics.setLineWidth(1)
    end
end

function PoolGrid:mousemoved(x, y)
    self.hover = self:indexAt(x, y)
end

-- Returns true if the click landed on this widget (a cell or a scroll arrow), so the host can treat
-- it as handled -- and, for a cell, which index, so it knows to run a transfer.
function PoolGrid:mousepressed(x, y, button)
    if button ~= 1 then return false end
    if pointIn(self.upArrow, x, y) then self:scroll(-1) return true end
    if pointIn(self.downArrow, x, y) then self:scroll(1) return true end
    local i = self:indexAt(x, y)
    if not i then return false end
    self.cursor = i
    return true, i
end

function PoolGrid:keypressed(key)
    if key == "left" or key == "a" then self:moveCursor(-1, 0)
    elseif key == "right" or key == "d" then self:moveCursor(1, 0)
    elseif key == "up" or key == "w" then self:moveCursor(0, -1)
    elseif key == "down" or key == "s" then self:moveCursor(0, 1)
    elseif key == "return" or key == "kpenter" or key == "space" then return self.cursor
    end
    return nil
end

function PoolGrid:gamepadpressed(_, button)
    if button == "dpleft" then self:moveCursor(-1, 0)
    elseif button == "dpright" then self:moveCursor(1, 0)
    elseif button == "dpup" then self:moveCursor(0, -1)
    elseif button == "dpdown" then self:moveCursor(0, 1)
    elseif button == "a" then return self.cursor
    end
    return nil
end

return PoolGrid
