-- Reusable scrolling grid of items with hover tooltips: the shared "pool" surface for the Party
-- screen (ui/panels/party.lua) and for the Market's counter (ui/panels/shop.lua). It is the
-- grid-shaped successor to ui/stash_list.lua's vertical list, and renders one of two backing sources:
--
--   * a STASH -- real owned Item instances (setItems(player.stash)); cell index maps 1:1 to the
--     stash list, and a stackable consumable shows an "xN" count.
--   * a STORE -- catalog entries from Vendor.stock (setStore(entries)); each cell is a buyable
--     TYPE (never consumed), showing its price and a greyed overlay when quest-locked. An entry may
--     carry its own display `item` when the host has already built one (the shop instantiates each
--     ware at the level it is sold at); absent that, the id is instantiated plain.
--
-- ONE ITEM LANGUAGE. A thing the player owns and a thing they could own are the same object with a
-- different question attached, so they are drawn the same way in the same widget: an icon on a plate,
-- its name under it, one number in the corner, and the full reading in the hover tooltip the host
-- opens off :itemAt. That is why the shop's counter is this grid and not a list with a description
-- column beside it -- an item that changed shape between the stash and the shelf made the player learn
-- the screen twice.
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
-- An optional pair of callbacks marks cells the player has not looked at yet: `isNew(item)` decides
-- which wear the red corner dot, and `onSeen(item)` is called the moment the pointer or the cursor
-- lands on one, so the mark clears on a LOOK rather than on a click. The widget owns neither the
-- ledger nor its persistence -- the host passes closures over the player (models/player.lua's
-- Player.markNew) -- so this stays a pure view of whatever list it was handed.
--
--   local pool = PoolGrid.new({ x =, y =, w =, h =, isNew = fn, onSeen = fn })
--   pool:setItems(player.stash)        -- stash source
--   pool:setStore(Vendor.stock(...))   -- store source
--   pool:draw(); pool:mousemoved(x, y); pool:mousepressed(x, y, button) -> handled, index
--   pool:wheelmoved(dy); pool:contains(x, y); pool:itemAt(i); pool:cellAt(i)
--   pool:keypressed(key); pool:gamepadpressed(joystick, button); pool:cancelPickup()

local Item = require("models.item")
local Glyphs = require("ui.glyphs")
local Theme = require("ui.theme")

local PoolGrid = {}
PoolGrid.__index = PoolGrid

local CELL = 64
local GAP = 8
local ARROW_H = 20 -- clickable scroll arrows above and below the grid

-- Icon/plate tint per item type, matching ui/item_tooltip.lua and the old stash list.
local TYPE_COLOR = {
    weapon = { 0.789, 0.361, 0.354 },
    armor = { 0.391, 0.549, 0.812 },
    consumable = { 0.361, 0.671, 0.480 },
    ability = { 0.568, 0.414, 0.786 },
    utility = { 0.865, 0.707, 0.341 },
    -- LOOT WITH NO USE BUT TO BE SOLD (models/valuable.lua), and it earns a colour rather than falling
    -- through to the default for one reason: the decision it exists to create is taken by SCANNING a
    -- full stash for what to jettison, and a kind that reads as "unrecognised" is a kind the player has
    -- to open every tile to find. Pale gold -- brighter and whiter than the utility amber above it, so
    -- the two are told apart at tile size rather than only side by side.
    valuable = { 0.925, 0.851, 0.573 },
}
local DEFAULT_COLOR = { 0.80, 0.80, 0.86 }

-- The two measurements a host needs BEFORE it builds a pool, so it can lay several of them out in a
-- fixed column (the shop stacks one per rack) without duplicating the cell metrics here.
function PoolGrid.colsFor(w) return math.max(1, math.floor((w + GAP) / (CELL + GAP))) end
-- The inverse, for a host laying a COLUMN out around a rack rather than a rack inside a column: the
-- shop sets its detail column to a whole number of cells so the house shelf and the Market wrap the
-- same stock the same way (ui/panels/shop.lua).
function PoolGrid.widthForCols(cols)
    cols = math.max(1, cols)
    return cols * CELL + (cols - 1) * GAP
end
function PoolGrid.heightForRows(rows)
    rows = math.max(1, rows)
    return ARROW_H * 2 + rows * CELL + (rows - 1) * GAP
end

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
    -- Unseen marks: which cells wear the red dot, and who to tell when one is looked at. Both
    -- optional -- a pool given neither simply never dots anything.
    self.isNew = opts.isNew
    self.onSeen = opts.onSeen
    -- `isAtRisk(item)` badges anything this expedition FOUND -- a wipe leaves it on the floor
    -- (models/player.lua's Player.atRisk). Optional and nil outside a descent, so a campaign Loadout
    -- and every shop shelf draw exactly what they always did.
    self.isAtRisk = opts.isAtRisk
    -- `priceOf(item, cell) -> string|nil` puts a gold badge on a STASH cell: the shop's Sell shelf is
    -- the stash with a price on it, and what a piece is worth is the whole of the decision there. A
    -- store cell has its price already (from the entry) and never asks; a pool given neither draws no
    -- badge at all, which is every other stash in the game.
    self.priceOf = opts.priceOf
    -- `purse() -> gold`, optional: what the company can spend, for reddening a store price it cannot
    -- reach. A function rather than a number because the figure moves with every purchase.
    self.purse = opts.purse
    self.nameFont = Theme.body(11)
    self.smallFont = Theme.body(11)
    self.bigFont = Theme.display(20)

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
--
-- An entry that already carries an `item` hands its own display copy over instead. A shelf sells a
-- ware at a LEVEL (Item.instantiate(id, nil, entry.level)), and a cell that re-instantiated the bare
-- id would quote the plain piece's name and stats under the levelled one's price.
function PoolGrid:setStore(entries)
    self.mode = "store"
    self.source = entries or {}
    self.cells = {}
    for _, entry in ipairs(self.source) do
        self.cells[#self.cells + 1] = {
            item = entry.item or Item.instantiate(entry.id),
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
    self:see(self.cursor)
end

-- The player is looking at cell `i`: clear its unseen mark. Called from every route the eye can
-- arrive by -- the pointer crossing it, the keyboard/gamepad cursor landing on it, a click -- so the
-- dot answers to a LOOK and not to a particular input device.
function PoolGrid:see(i)
    if not self.onSeen then return end
    local cell = self.cells[i]
    if cell and cell.item then self.onSeen(cell.item, cell) end
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
    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 6, 6)
    -- Amber border when this region holds focus, quiet bronze otherwise (the cursor cell inside carries
    -- the cool Theme.cursor ring, so region-focus and cell-cursor never read as one mark).
    Theme.set(self.focused and Theme.accentAmber or Theme.frame)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 6, 6)

    if self:count() == 0 then
        love.graphics.setFont(self.nameFont)
        Theme.set(Theme.muted)
        local empty = self.mode == "store" and "Nothing for sale" or "Stash is empty"
        love.graphics.printf(empty, self.x, self.y + self.h / 2 - 8, self.w, "center")
        love.graphics.setColor(1, 1, 1)
        return
    end

    -- Scroll arrows, dimmed at the ends of the list (still drawn, so the column never reflows).
    love.graphics.setFont(self.smallFont)
    local canUp, canDown = self.offset > 0, self.offset < self:maxOffset()
    Theme.set(Theme.muted, canUp and 0.95 or 0.25)
    love.graphics.printf("^", self.upArrow.x, self.upArrow.y + 4, self.upArrow.w, "center")
    Theme.set(Theme.muted, canDown and 0.95 or 0.25)
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

    Theme.set(Theme.panel2)
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
    -- One size for every cell in the pool (never scaled -- a scaled font blurs); a name too long for
    -- the band ellipsizes.
    local font, name = Theme.itemTileName(item.name or "?", CELL - 6)
    love.graphics.setFont(font)
    love.graphics.setColor(col[1] * dim, col[2] * dim, col[3] * dim)
    love.graphics.print(name, sx + CELL / 2 - font:getWidth(name) / 2, sy + CELL - 14)

    -- Corner badge: a store price, or a stack count. The unseen dot claims the same top-right corner
    -- (it is the mark the eye should find first), so the badge steps aside for it rather than printing
    -- underneath -- see the dot below.
    local unseen = self.isNew and self.isNew(item, cell) or false
    local badgeInset = unseen and 16 or 4
    love.graphics.setFont(self.smallFont)
    local price = (self.mode == "store") and (tostring(cell.price) .. "g")
        or (self.priceOf and self.priceOf(item, cell)) or nil
    local qty = (item.quantity or 1) > 1 and ("x" .. item.quantity) or nil
    if price then
        -- PRICED AGAINST THE PURSE. A store cell the company cannot afford draws its figure in the
        -- refusal colour rather than the gold every other price wears -- so "what can I take home" is
        -- answered by scanning the rack instead of by pressing each tile and being told no. Gold is read
        -- through a getter because it changes under a shelf that is not rebuilt (`purse`, optional: a
        -- pool given none prices everything in amber, which is every rack outside a shop).
        local afford = not (self.purse and cell.price and cell.price > (self.purse() or 0))
        Theme.set(afford and Theme.accentAmber or Theme.accentWeapon, dim)
        love.graphics.printf(price, sx, sy + 3, CELL - badgeInset, "right")
        -- A priced stack sends its count to the OPPOSITE corner: two numbers stacked in one corner
        -- read as one number, and the count is the smaller question of the two.
        if qty then
            Theme.set(Theme.ink, dim)
            love.graphics.print(qty, sx + 5, sy + 3)
        end
    elseif qty then
        Theme.set(Theme.ink, dim)
        love.graphics.printf(qty, sx, sy + 3, CELL - badgeInset, "right")
    end

    -- Quest-locked store cell: greyed, so seeing what more quests will buy is still possible.
    if cell.locked then
        Theme.set(Theme.mount, 0.6)
        love.graphics.rectangle("fill", sx, sy, CELL, CELL, 6, 6)
        Theme.set(Theme.accentWeapon, 0.9)
        love.graphics.printf("locked", sx, sy + CELL / 2 - 6, CELL, "center")
    end

    -- Unseen: the red dot, top-right, over the locked wash and the name band so it survives both.
    if unseen then Glyphs.unseenDot(sx + CELL - 7, sy + 7, 4) end

    -- AT-RISK: what this expedition found, and would leave on the floor if the company went down.
    -- Bottom-left, which is the corner the grid puts it in too (ui/inventory_grid.lua) -- an item has to
    -- carry the same answer in the same place whether the player is looking at it in somebody's hands
    -- or in the pile. Over the locked wash for the same reason the dot is.
    if self.isAtRisk and self.isAtRisk(item, cell) then
        Glyphs.atRisk(sx + 11, sy + CELL - 26, 10)
    end

    -- Overlays: picked (in hand), hover (mouse), the keyboard/gamepad cursor.
    if lifted then
        Theme.set(Theme.accentAmber)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", sx, sy, CELL, CELL, 6, 6)
        love.graphics.setLineWidth(1)
    end
    if self.hover == i then
        Theme.set(Theme.accentAmber, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx, sy, CELL, CELL, 6, 6)
        love.graphics.setLineWidth(1)
    end
    if self.focused and self.cursor == i then
        Theme.set(Theme.cursor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx - 2, sy - 2, CELL + 4, CELL + 4, 7, 7)
        love.graphics.setLineWidth(1)
    end
end

function PoolGrid:mousemoved(x, y)
    local was = self.hover
    self.hover = self:indexAt(x, y)
    -- Only on a CROSSING: a pointer resting on a cell must not re-ask (and re-save) every frame.
    if self.hover and self.hover ~= was then self:see(self.hover) end
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
    self:see(i)
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
