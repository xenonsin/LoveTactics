-- Loadout pop-up panel: arrange each roster member's 3x3 item grid, where item POSITIONING drives
-- adjacency auras/boosts/requirements (ui/adjacency_links.lua) -- that's the point of this screen, so
-- the grid gets a legend. A scrollable portrait rail runs down the LEFT, then the focused member's
-- portrait + stats + traits, then that member's grid, then the shared stash (ui/pool_grid.lua).
-- Buying and selling live on the separate shop screen (ui/panels/shop.lua); this screen never touches
-- gold.
--
-- The panel owns EVERY item move -- the widgets never mutate ownership themselves -- so the two can't
-- disagree about who holds what. Dragging an item onto a rail portrait GIVES it to that member, so
-- cross-member transfers don't need a focus switch.
--
-- Stash -> character is one step: clicking (or confirming on) a stash item EQUIPS the whole thing to
-- the focused member's next open slot (stackables merge first). Reordering a member's grid is the
-- separate action -- pick-then-place with keyboard/gamepad, drag-and-drop with the mouse -- and a
-- mouse drag from the stash onto a specific cell/portrait is how you aim a slot, member, or quantity.
--
-- Three-input + mouse-only: click cells/rows/portraits, or drag; keyboard (arrows + Enter, Tab to
-- switch grid<->stash, Q/E character, Esc); gamepad (D-pad + A, Y grid<->stash, shoulders character,
-- B close).
--
--   local panel = Party.new({ player = player, onClose = fn })

local InventoryGrid = require("ui.inventory_grid")
local PoolGrid = require("ui.pool_grid")
local AdjacencyLinks = require("ui.adjacency_links")
local CloseButton = require("ui.close_button")
local QuantityPopup = require("ui.quantity_popup")
local ItemTooltip = require("ui.item_tooltip")
local ButtonPrompt = require("ui.button_prompt")
local InputMode = require("input_mode")
local Character = require("models.character")
local Player = require("models.player")
local Item = require("models.item")
local Trait = require("models.trait")
local Growth = require("models.growth")
local Scale = require("scale")

local Party = {}
Party.__index = Party

local BOX_W, BOX_H = 1160, 650
local DRAG_THRESHOLD = 5
local GHOST = 48

-- Vertical roster rail down the left.
local PORTRAIT = 72
local RAIL_CELL_H = PORTRAIT + 20 -- portrait + name line
local RAIL_GAP = 8

-- Stats shown in the focus sheet, in order. `res` stats are the { max, current } pools.
local STAT_ROWS = {
    { key = "health", label = "HP", res = true },
    { key = "mana", label = "MP", res = true },
    { key = "stamina", label = "SP", res = true },
    { key = "damage", label = "Attack" },
    { key = "magicDamage", label = "Magic" },
    { key = "defense", label = "Defense" },
    { key = "magicDefense", label = "M.Def" },
    { key = "movement", label = "Move" },
    { key = "speed", label = "Speed" },
}

-- Adjacency connector legend (colors from ui/adjacency_links.lua). Positioning is the mechanic this
-- screen exists for, so the legend is always shown under the grid.
local LEGEND = {
    { kind = "aura", label = "Aura (grants to neighbor)" },
    { kind = "boost", label = "Scales off neighbor" },
    { kind = "requirement", label = "Requirement met" },
}

-- Navigable regions, left to right. The focus sheet is skipped as a stop -- it has no interactive
-- cells -- so a single cursor flows Rail <-> Grid <-> Stash by pushing left/right at a column edge.
local REGIONS = { "rail", "grid", "pool" }

-- Semantic prompt-glyph tints, kept across input modes (the glyph text changes A<->Enter, the
-- meaning doesn't): confirm reads green, cancel/close red.
local PROMPT_GO = { 0.55, 0.90, 0.58 }
local PROMPT_NO = { 0.95, 0.50, 0.47 }

-- Flat stat keys the focus sheet prints (STAT_ROWS minus the resource pools), so an equip-delta
-- preview only annotates a row that actually shows a plain number.
local DELTA_KEYS = {}
for _, row in ipairs(STAT_ROWS) do
    if not row.res then DELTA_KEYS[row.key] = true end
end

local function pointIn(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function classLabel(class)
    if not class then return "?" end
    return (class:gsub("^%l", string.upper))
end

-- "mage 18 · fighter 6" -- the character's top class-usage counts, most-used first, so the player can
-- see what a member is growing toward (and steer it by how they play). Empty until they cast something.
local function usageBreakdown(char)
    local ranked = {}
    for class, count in pairs(char.classUse or {}) do
        ranked[#ranked + 1] = { class = class, count = count }
    end
    table.sort(ranked, function(a, b) return a.count > b.count end)
    local parts = {}
    for i = 1, math.min(3, #ranked) do
        parts[#parts + 1] = ranked[i].class .. " " .. ranked[i].count
    end
    return table.concat(parts, "   ")
end

function Party.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Party)
    self.onClose = opts.onClose
    self.player = opts.player
    self.title = opts.title or "Loadout"

    self.titleFont = love.graphics.newFont(28)
    self.headFont = love.graphics.newFont(18)
    self.bodyFont = love.graphics.newFont(15)
    self.smallFont = love.graphics.newFont(13)
    self.tinyFont = love.graphics.newFont(11)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    self.chars = (self.player and self.player.roster) or (self.player and self.player.party) or {}
    self.charIndex = 1
    self.railOffset = 0
    self.railCursor = 1 -- rail navigation cursor (distinct from charIndex, the edited member)
    self.focus = "grid"
    self.axisActive = false -- analog-stick edge-detect flag (one nav step per push)
    self.axisThreshold = 0.5
    self.drag = nil
    self.quantityPopup = nil
    self.mx, self.my = 0, 0

    -- Layout: rail (left) | focus sheet | member grid | stash pool.
    local contentY = self.boxY + 96
    local bottom = self.boxY + BOX_H - 40
    self.railX = self.boxX + 24
    self.railY = contentY
    self.railW = 96
    self.railH = bottom - contentY
    self.railVisible = math.max(1, math.floor((self.railH + RAIL_GAP) / (RAIL_CELL_H + RAIL_GAP)))

    self.focusX = self.railX + self.railW + 20
    self.focusW = 300

    self.gridLabelY = contentY
    self.grid = InventoryGrid.new({
        x = self.focusX + self.focusW + 20,
        y = contentY + 24,
        char = self.chars[self.charIndex],
    })

    local poolX = self.grid.x + self.grid.gridW + 24
    self.poolHeaderY = contentY
    self.pool = PoolGrid.new({
        x = poolX,
        y = contentY + 24,
        w = self.boxX + BOX_W - 24 - poolX,
        h = bottom - (contentY + 24),
    })
    self.pool:setItems(self.player and self.player.stash or {})

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

function Party:setMsg(text, ok)
    self.message, self.messageOk = text, ok
end

function Party:close()
    if self.onClose then self.onClose() end
end

function Party:currentChar()
    return self.chars[self.charIndex]
end

function Party:switchChar(delta)
    if #self.chars == 0 then return end
    self.charIndex = (self.charIndex - 1 + delta) % #self.chars + 1
    self.railCursor = self.charIndex
    self.grid:setChar(self:currentChar())
    self.pool:cancelPickup()
    self.drag = nil
    self:railScrollToFocus()
end

function Party:focusChar(i)
    if not self.chars[i] then return end
    self.charIndex = i
    self.railCursor = i
    self.grid:setChar(self:currentChar())
    self:railScrollToFocus()
end

-- Single writer for the focused region, keeping the pool's cursor-highlight flag in sync (PoolGrid
-- only draws its cursor when focused). Every focus change -- nav, cycle, mouse -- goes through here.
function Party:setFocus(region)
    self.focus = region
    self.pool.focused = (region == "pool")
end

-- Region-cycle fallback (Tab / Y): advance through REGIONS and drop any in-progress pickup.
function Party:cycleFocus(delta)
    local idx = 1
    for i, r in ipairs(REGIONS) do if r == self.focus then idx = i break end end
    self:setFocus(REGIONS[(idx - 1 + delta) % #REGIONS + 1])
    self.grid:cancelPickup()
    self.pool:cancelPickup()
    self.drag = nil
end

-- ---------------------------------------------------------------------------
-- Rail (vertical, scrollable roster of portraits)
-- ---------------------------------------------------------------------------

-- Scroll the rail so 0-based `row` sits in the visible window.
function Party:railScrollTo(row)
    if row < self.railOffset then
        self.railOffset = row
    elseif row >= self.railOffset + self.railVisible then
        self.railOffset = row - self.railVisible + 1
    end
    self.railOffset = math.max(0, math.min(math.max(0, #self.chars - self.railVisible), self.railOffset))
end

function Party:railScrollToFocus()
    self:railScrollTo(self.charIndex - 1)
end

-- Move the rail navigation cursor, clamped, keeping it on screen (mirrors PoolGrid:moveCursor).
function Party:moveRailCursor(delta)
    if #self.chars == 0 then return end
    self.railCursor = math.max(1, math.min(#self.chars, self.railCursor + delta))
    self:railScrollTo(self.railCursor - 1)
end

function Party:railRect(i)
    local visRow = (i - 1) - self.railOffset
    if visRow < 0 or visRow >= self.railVisible then return nil end
    return self.railX, self.railY + visRow * (RAIL_CELL_H + RAIL_GAP), self.railW, RAIL_CELL_H
end

function Party:railIndexAt(x, y)
    for i = 1, #self.chars do
        local rx, ry, rw, rh = self:railRect(i)
        if rx and x >= rx and x <= rx + rw and y >= ry and y <= ry + rh then return i end
    end
    return nil
end

function Party:railContains(x, y)
    return x >= self.railX and x <= self.railX + self.railW
        and y >= self.railY and y <= self.railY + self.railH
end

-- Is `char` in the deployable party? (Shown as a badge; not editable here.)
function Party:inParty(char)
    for _, m in ipairs(self.player and self.player.party or {}) do
        if m == char then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Transfers -- item movement only, no gold (buying/selling is the shop's job).
-- ---------------------------------------------------------------------------

function Party:refreshStash()
    self.pool:refresh()
end

-- STASH -> current grid cell. Index into the pool maps 1:1 to the stash, since the pool was fed
-- player.stash directly.
function Party:placeIntoGrid(stashIndex, cell)
    local char = self:currentChar()
    if not (char and self.player) then return end
    local incoming = Player.takeFromStash(self.player, stashIndex)
    if not incoming then return end
    local displaced = char.inventory[cell]
    char.inventory[cell] = incoming
    if displaced then Player.addToStash(self.player, displaced) end
    self:refreshStash()
end

function Party:stashIndexOf(item)
    for i, it in ipairs((self.player and self.player.stash) or {}) do
        if it == item then return i end
    end
    return nil
end

function Party:transferStashToGrid(stashIndex, cell)
    local stashItem = self.player and self.player.stash and self.player.stash[stashIndex]
    if not stashItem then return end
    if Item.isStackable(stashItem) and (stashItem.quantity or 1) > 1 then
        self:openQuantityPopup(stashItem, cell)
    else
        self:commitStashToGrid(stashItem, cell, stashItem.quantity or 1)
    end
end

-- Move `count` of a stash item onto the current character, merging into an existing same-id stack
-- first and only spilling the leftover into a cell.
function Party:commitStashToGrid(stashItem, cell, count)
    local char = self:currentChar()
    if not (char and self.player and stashItem) then return end

    if not Item.isStackable(stashItem) then
        local index = self:stashIndexOf(stashItem)
        if index then self:placeIntoGrid(index, cell) end
        return
    end

    count = math.max(1, math.min(count or stashItem.quantity, stashItem.quantity))

    local hadExisting = false
    for i = 1, Character.MAX_INVENTORY do
        local existing = char.inventory[i]
        if existing and existing.id == stashItem.id and Item.isStackable(existing) then
            hadExisting = true
            break
        end
    end

    local remaining = count
    for i = 1, Character.MAX_INVENTORY do
        local existing = char.inventory[i]
        if existing and existing.id == stashItem.id and Item.isStackable(existing) then
            local room = Item.maxStack(existing) - existing.quantity
            if room > 0 then
                local moved = math.min(room, remaining)
                existing.quantity = existing.quantity + moved
                remaining = remaining - moved
                if remaining <= 0 then break end
            end
        end
    end

    if remaining > 0 then
        local slot = hadExisting and Character.firstEmptySlot(char) or cell
        if slot then
            local displaced = char.inventory[slot]
            char.inventory[slot] = Item.instantiate(stashItem.id, remaining, stashItem.level)
            remaining = 0
            if displaced then Player.addToStash(self.player, displaced) end
        end
    end

    stashItem.quantity = stashItem.quantity - (count - remaining)
    if stashItem.quantity <= 0 then
        local index = self:stashIndexOf(stashItem)
        if index then Player.takeFromStash(self.player, index) end
    end

    self.pool:cancelPickup()
    self:refreshStash()
end

function Party:openQuantityPopup(stashItem, cell)
    self.quantityPopup = QuantityPopup.new({
        max = stashItem.quantity,
        value = stashItem.quantity,
        title = "Move how many?",
        label = stashItem.name,
        onConfirm = function(n)
            self.quantityPopup = nil
            self:commitStashToGrid(stashItem, cell, n)
        end,
        onCancel = function()
            self.quantityPopup = nil
            self.pool:cancelPickup()
        end,
    })
end

-- Send the grid item in `cell` out to the stash.
function Party:stowFromGrid(cell)
    local char = self:currentChar()
    if not (char and self.player) then return end
    local item = char.inventory[cell]
    if not item then return end
    Character.removeItem(char, item)
    Player.addToStash(self.player, item)
    self.grid:cancelPickup()
    self:refreshStash()
end

-- Drop the held grid/pool item onto rail portrait `memberIdx` -> give it to that member.
function Party:giveGridItemToMember(cell, memberIdx)
    local member = self.chars[memberIdx]
    local char = self:currentChar()
    if not (member and char) then return end
    if member == char then self.grid:cancelPickup() return end
    local item = char.inventory[cell]
    if not item then return end
    Character.removeItem(char, item)
    if not Character.addItem(member, item) then
        -- No room: return it to where it came from (its cell just freed up).
        Character.addItem(char, item)
        self:setMsg((member.name or "That member") .. "'s grid is full.", false)
    else
        self:setMsg("Gave " .. (item.name or "item") .. " to " .. (member.name or "member") .. ".", true)
    end
    self.grid:cancelPickup()
end

function Party:givePoolItemToMember(poolIndex, memberIdx)
    local member = self.chars[memberIdx]
    if not member then return end
    local item = self.player and self.player.stash and self.player.stash[poolIndex]
    if not item then return end
    Player.takeFromStash(self.player, poolIndex)
    if not Character.addItem(member, item) then
        Player.addToStash(self.player, item)
        self:setMsg((member.name or "That member") .. "'s grid is full.", false)
    else
        self:setMsg("Gave " .. (item.name or "item") .. " to " .. (member.name or "member") .. ".", true)
    end
    self.pool:cancelPickup()
    self:refreshStash()
end

-- Confirm on a grid cell: land a held stash item, else pick/swap within the grid.
function Party:activateGrid(cell)
    if self.pool.picked then
        self:transferStashToGrid(self.pool.picked, cell)
    else
        self.grid:activate(cell)
    end
end

-- Confirm on a pool cell: stow a held grid item, else EQUIP the stash item to the focused member.
function Party:activatePool(index)
    if self.grid.picked then
        self:stowFromGrid(self.grid.picked)
    else
        self:equipStashItem(index)
    end
end

-- True if `stashItem` is a stackable an existing same-id stack on `char` still has room to absorb --
-- so it can be equipped even when every grid cell is occupied.
function Party:canMergeStack(char, stashItem)
    if not Item.isStackable(stashItem) then return false end
    for i = 1, Character.MAX_INVENTORY do
        local existing = char.inventory[i]
        if existing and existing.id == stashItem.id and Item.isStackable(existing)
            and existing.quantity < Item.maxStack(existing) then
            return true
        end
    end
    return false
end

-- Auto-equip a whole stash item onto the focused member's first empty slot (stackables merge into an
-- existing same-id stack first). This is what a plain click / confirm on a stash cell does; a mouse
-- drag onto a specific cell or portrait is the way to aim a slot, member, or a partial quantity.
function Party:equipStashItem(stashIndex)
    local char = self:currentChar()
    local stashItem = self.player and self.player.stash and self.player.stash[stashIndex]
    if not (char and stashItem) then return end
    local slot = Character.firstEmptySlot(char)
    if not slot and not self:canMergeStack(char, stashItem) then
        self:setMsg((char.name or "This character") .. "'s inventory is full.", false)
        return
    end
    self:commitStashToGrid(stashItem, slot, stashItem.quantity or 1)
end

-- ---------------------------------------------------------------------------
-- Unified navigation -- one cursor flowing across the three regions. Keyboard, D-pad, and the
-- analog stick all funnel through navigate/confirm so the three input paths can't desync.
-- ---------------------------------------------------------------------------

-- Pure edge-crossing rule: at column `col` of `cols`, pushed horizontally by `dc`, which region
-- (if any) does the cursor move into? Rail is leftmost and Stash rightmost, so those outer edges
-- clamp. Returns the target region, or nil to stay and move within the current one.
function Party.regionCross(region, col, cols, dc)
    if region == "grid" then
        if dc == -1 and col == 0 then return "rail" end
        if dc == 1 and col == cols - 1 then return "pool" end
    elseif region == "pool" then
        if dc == -1 and col == 0 then return "grid" end
    elseif region == "rail" then
        if dc == 1 then return "grid" end
    end
    return nil
end

-- One navigation step. A horizontal press at a column edge crosses to the neighbour region
-- (and does not also move within it); otherwise the focused widget moves its own cursor.
function Party:navigate(dc, dr)
    local region = self.focus
    if dc ~= 0 then
        local col, cols
        if region == "grid" then
            col, cols = (self.grid.cursor - 1) % Character.COLS, Character.COLS
        elseif region == "pool" then
            col, cols = (self.pool.cursor - 1) % self.pool.cols, self.pool.cols
        else -- rail is a single column
            col, cols = 0, 1
        end
        local target = Party.regionCross(region, col, cols, dc)
        if target then self:setFocus(target) return end
    end
    if region == "grid" then
        self.grid:moveCursor(dc, dr)
    elseif region == "pool" then
        self.pool:moveCursor(dc, dr)
    else
        self:moveRailCursor(dr)
    end
end

-- Confirm (A / Enter) on the focused region. On the rail this is where cross-member GIVE is
-- reached on a pad: a held item goes to the cursored portrait; empty-handed, it focuses them.
function Party:confirm()
    if self.focus == "rail" then
        if self.grid.picked then
            self:giveGridItemToMember(self.grid.picked, self.railCursor)
        elseif self.pool.picked then
            self:givePoolItemToMember(self.pool.picked, self.railCursor)
        else
            self:focusChar(self.railCursor)
        end
    elseif self.focus == "pool" then
        self:activatePool(self.pool.cursor)
    else
        self:activateGrid(self.grid.cursor)
    end
end

-- ---------------------------------------------------------------------------
-- Equip-delta preview (read-only): how a picked item would change the focused member's stats.
-- ---------------------------------------------------------------------------

-- The item currently in hand and where it came from ("grid" | "pool"), or nil.
function Party:pickedItem()
    if self.grid.picked then
        local char = self:currentChar()
        return char and char.inventory[self.grid.picked], "grid"
    elseif self.pool.picked then
        return self.pool:itemAt(self.pool.picked), "pool"
    end
    return nil
end

-- Flat stat changes `item.bonus` would apply, limited to the flat rows the sheet shows. Pure and
-- static (no Combat, no mutation) so it's unit-testable without constructing a panel.
function Party.equipDelta(item)
    local delta = {}
    if item and item.bonus then
        for k, v in pairs(item.bonus) do
            if DELTA_KEYS[k] then delta[k] = v end
        end
    end
    return delta
end

-- Sign of the picked item's effect on the FOCUSED member (the one the sheet shows): a stash item
-- lands on them (+1) unless it's being given to someone else; a grid item leaves them (-1) when
-- stowed or given away. A rearrange within the grid or a give-to-self nets nothing (0).
function Party:deltaSign(source)
    local toOther = (self.focus == "rail" and self.railCursor ~= self.charIndex)
    if source == "pool" then
        return toOther and 0 or 1
    elseif source == "grid" then
        if self.focus == "pool" or toOther then return -1 end
        return 0
    end
    return 0
end

-- ---------------------------------------------------------------------------
-- Dragging (aims an existing pickup; ends by calling the same transfers)
-- ---------------------------------------------------------------------------

function Party:beginDrag(from, index, x, y)
    self.drag = { from = from, index = index, x = x, y = y, startX = x, startY = y, active = false }
end

function Party:dragItem()
    local drag = self.drag
    if not drag then return nil end
    if drag.from == "pool" then return self.pool:itemAt(drag.index) end
    local char = self:currentChar()
    return char and char.inventory[drag.index]
end

function Party:dropDrag(x, y)
    local drag = self.drag
    self.drag = nil
    if not (drag and drag.active) then return end -- a click, not a drag: pickup stays in hand

    local cell = self.grid:indexAt(x, y)
    local ri = self:railIndexAt(x, y)
    if drag.from == "grid" then
        if cell then
            self.grid:activate(cell)
        elseif ri then
            self:giveGridItemToMember(drag.index, ri)
        elseif self.pool:contains(x, y) then
            self:stowFromGrid(drag.index)
        else
            self.grid:cancelPickup()
        end
    else -- from pool
        if cell then
            self:transferStashToGrid(drag.index, cell)
        elseif ri then
            self:givePoolItemToMember(drag.index, ri)
        else
            self.pool:cancelPickup()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Update / draw
-- ---------------------------------------------------------------------------

function Party:update(dt)
    if self.quantityPopup then self.quantityPopup:update(dt) return end
    -- Poll the analog stick for navigation, edge-detected so a held stick steps one cell per push
    -- (mirrors ui/battle_map.lua). D-pad is handled directly in gamepadpressed.
    if not love.joystick then return end
    for _, joy in ipairs(love.joystick.getJoysticks()) do
        if joy:isGamepad() then
            local ax, ay = joy:getGamepadAxis("leftx"), joy:getGamepadAxis("lefty")
            local dx, dy = 0, 0
            if ax <= -self.axisThreshold then dx = -1
            elseif ax >= self.axisThreshold then dx = 1
            elseif ay <= -self.axisThreshold then dy = -1
            elseif ay >= self.axisThreshold then dy = 1 end
            if dx == 0 and dy == 0 then
                self.axisActive = false
            elseif not self.axisActive then
                self.axisActive = true
                self:navigate(dx, dy)
            end
        end
    end
end

function Party:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(self.title, self.boxX, self.boxY + 18, BOX_W, "center")

    self:drawRail()
    self:drawFocus()
    self:drawMemberGrid()
    self:drawPool()

    self:drawFooter()
    self.closeButton:draw()
    self:drawDrag()
    if not self.drag then self:drawActiveTooltip() end
    if self.quantityPopup then self.quantityPopup:draw() end
    love.graphics.setColor(1, 1, 1)
end

function Party:drawRail()
    for i = 1, #self.chars do
        local rx, ry, rw, rh = self:railRect(i)
        if rx then self:drawRailPortrait(self.chars[i], i, rx, ry, rw, rh) end
    end
    -- Vertical scroll hint chevrons when the roster overflows.
    if #self.chars > self.railVisible then
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.6, 0.64, 0.75, self.railOffset > 0 and 0.9 or 0.2)
        love.graphics.printf("^", self.railX, self.railY - 16, self.railW, "center")
        local maxOff = #self.chars - self.railVisible
        love.graphics.setColor(0.6, 0.64, 0.75, self.railOffset < maxOff and 0.9 or 0.2)
        love.graphics.printf("v", self.railX, self.railY + self.railH + 2, self.railW, "center")
    end
end

function Party:drawRailPortrait(char, i, rx, ry, rw, rh)
    local focused = (i == self.charIndex)
    love.graphics.setColor(focused and 0.22 or 0.15, focused and 0.26 or 0.16, focused and 0.34 or 0.21)
    love.graphics.rectangle("fill", rx, ry, rw, rh, 6, 6)

    local sprite = char.sprite
    local px, py, ps = rx + (rw - PORTRAIT) / 2, ry + 4, PORTRAIT
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(ps / sw, ps / sh)
        love.graphics.draw(sprite, px + ps / 2, py + ps / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        love.graphics.setColor(0.3, 0.32, 0.4)
        love.graphics.rectangle("fill", px, py, ps, ps, 5, 5)
        love.graphics.setFont(self.headFont)
        love.graphics.setColor(0.9, 0.9, 0.95)
        love.graphics.printf((char.name or "?"):sub(1, 1), px, py + ps / 2 - 12, ps, "center")
    end

    love.graphics.setFont(self.tinyFont)
    love.graphics.setColor(0.85, 0.87, 0.92)
    love.graphics.printf(char.name or "?", rx + 2, ry + rh - 16, rw - 4, "center")

    if self:inParty(char) then
        love.graphics.setColor(0.95, 0.82, 0.4)
        love.graphics.circle("fill", rx + rw - 8, ry + 8, 4)
    end

    -- Warm-gold ring marks the EDITED member (whose grid/stats show); the cyan cursor ring marks
    -- where rail navigation currently points -- distinct colors so the two never read as one.
    if focused then
        love.graphics.setColor(0.95, 0.82, 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rx, ry, rw, rh, 6, 6)
        love.graphics.setLineWidth(1)
    end
    if self.focus == "rail" and i == self.railCursor then
        love.graphics.setColor(0.6, 0.75, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rx - 2, ry - 2, rw + 4, rh + 4, 7, 7)
        love.graphics.setLineWidth(1)
    end
end

-- Focus sheet: the selected member's big portrait, name, stats (two per row), and traits.
function Party:drawFocus()
    local char = self:currentChar()
    if not char then return end
    local x, y = self.focusX, self.boxY + 96

    local ps = 168
    local px = x + (self.focusW - ps) / 2
    love.graphics.setColor(0.09, 0.10, 0.14)
    love.graphics.rectangle("fill", px, y, ps, ps, 8, 8)
    local sprite = char.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local scale = math.min((ps - 12) / sw, (ps - 12) / sh)
        love.graphics.draw(sprite, px + ps / 2, y + ps / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        love.graphics.setFont(self.titleFont)
        love.graphics.setColor(0.8, 0.82, 0.9)
        love.graphics.printf((char.name or "?"):sub(1, 1), px, y + ps / 2 - 18, ps, "center")
    end
    love.graphics.setColor(0.4, 0.44, 0.55)
    love.graphics.rectangle("line", px, y, ps, ps, 8, 8)

    love.graphics.setFont(self.headFont)
    love.graphics.setColor(0.95, 0.95, 0.97)
    love.graphics.printf(char.name or "?", x, y + ps + 6, self.focusW, "center")

    -- Level + growth class: level tracks the player's prestige, and the member gains the stats of its
    -- most-used class on each level-up (models/growth.lua). The usage breakdown underneath shows what
    -- it is trending toward, which the player steers by which items they cast in battle.
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.72, 0.76, 0.84)
    love.graphics.printf("Lv " .. tostring(char.level or 1) .. "  -  Growing as "
        .. classLabel(Growth.dominantClass(char)), x, y + ps + 30, self.focusW, "center")
    local breakdown = usageBreakdown(char)
    if breakdown ~= "" then
        love.graphics.setColor(0.55, 0.58, 0.66)
        love.graphics.printf(breakdown, x, y + ps + 46, self.focusW, "center")
    end

    -- If an item is in hand, preview how it changes THIS member's flat stats (green gain / red
    -- loss). The sheet shows BASE stats -- equipped bonuses aren't folded in, a pre-existing gap --
    -- so this is an additive annotation next to the value, never a recomputation of it.
    local held, heldSource = self:pickedItem()
    local delta = held and Party.equipDelta(held) or nil
    local sign = held and self:deltaSign(heldSource) or 0

    -- Stats, two per row.
    love.graphics.setFont(self.bodyFont)
    local sy = y + ps + 70
    local colW = self.focusW / 2
    local n = 0
    for _, row in ipairs(STAT_ROWS) do
        local stat = char.stats and char.stats[row.key]
        if stat ~= nil then
            local col = n % 2
            local cx = x + col * colW
            local value
            if row.res and type(stat) == "table" then
                value = (stat.current or stat.max) .. "/" .. (stat.max or 0)
            else
                value = tostring(stat)
            end
            love.graphics.setColor(0.6, 0.64, 0.72)
            love.graphics.print(row.label, cx, sy)
            love.graphics.setColor(0.92, 0.93, 0.97)
            love.graphics.printf(value, cx, sy, colW - 16, "right")
            if delta and sign ~= 0 and delta[row.key] and delta[row.key] ~= 0 then
                local change = sign * delta[row.key]
                local text = (change > 0 and "+" or "") .. change
                if change > 0 then love.graphics.setColor(0.55, 0.9, 0.58)
                else love.graphics.setColor(0.95, 0.45, 0.42) end
                local dw = self.bodyFont:getWidth(text)
                local vw = self.bodyFont:getWidth(value)
                love.graphics.print(text, cx + (colW - 16) - vw - 6 - dw, sy)
            end
            n = n + 1
            if col == 1 then sy = sy + 22 end
        end
    end
    if n % 2 == 1 then sy = sy + 22 end

    -- Traits.
    sy = sy + 10
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.7, 0.74, 0.82)
    love.graphics.print("Traits", x, sy)
    sy = sy + 20
    local traits = char.traits or {}
    if #traits == 0 then
        love.graphics.setFont(self.tinyFont)
        love.graphics.setColor(0.55, 0.58, 0.66)
        love.graphics.print("None", x, sy)
    else
        for _, id in ipairs(traits) do
            local def = Trait.defs[id]
            if def then
                love.graphics.setFont(self.smallFont)
                love.graphics.setColor(0.85, 0.8, 0.55)
                love.graphics.print(def.name or id, x, sy)
                sy = sy + 18
                love.graphics.setFont(self.tinyFont)
                love.graphics.setColor(0.68, 0.7, 0.78)
                local _, lines = self.tinyFont:getWrap(def.description or "", self.focusW)
                love.graphics.printf(def.description or "", x, sy, self.focusW, "left")
                sy = sy + math.max(1, #lines) * 14 + 6
            end
        end
    end
end

-- The focused member's 3x3 grid (the anchor) with the adjacency legend beneath it.
function Party:drawMemberGrid()
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.75, 0.78, 0.86)
    love.graphics.print("Inventory", self.grid.x, self.gridLabelY)
    self.grid:draw()

    local ly = self.grid.y + self.grid.gridH + 16
    love.graphics.setFont(self.bodyFont)
    for _, row in ipairs(LEGEND) do
        local c = AdjacencyLinks.COLOR[row.kind]
        love.graphics.setColor(c[1], c[2], c[3])
        love.graphics.setLineWidth(3)
        love.graphics.line(self.grid.x, ly + 8, self.grid.x + 26, ly + 8)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.8, 0.82, 0.88)
        love.graphics.print(row.label, self.grid.x + 36, ly)
        ly = ly + 24
    end
end

function Party:drawPool()
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.75, 0.78, 0.86)
    love.graphics.print("Stash (" .. self.pool:count() .. ")", self.pool.x, self.poolHeaderY)
    self.pool:draw()
end

function Party:drawFooter()
    love.graphics.setFont(self.smallFont)
    if self.message then
        love.graphics.setColor(self.messageOk and 0.6 or 0.9, self.messageOk and 0.85 or 0.6,
            self.messageOk and 0.6 or 0.55)
        love.graphics.printf(self.message, self.boxX, self.boxY + BOX_H - 52, BOX_W, "center")
    end
    self:drawPromptBar()
end

-- Context-sensitive control hints, keyed on the focused region and whether an item is in hand -- so
-- the confirm button's meaning (Pick up / Place / Give / Stow) is always spelt out. The glyphs match
-- the device last used (pad buttons vs. keyboard keys); mouse falls back to the keyboard set.
function Party:drawPromptBar()
    local pad = InputMode.isGamepad()
    local confirmGlyph = pad and "A" or "Enter"
    local cancelGlyph = pad and "B" or "Esc"
    local regionGlyph = pad and "Y" or "Tab"
    local switchGlyph = pad and "LB/RB" or "Q/E"

    local segments = {}
    local function add(glyph, label, color) segments[#segments + 1] = { glyph = glyph, label = label, color = color } end

    local held = self.grid.picked or self.pool.picked
    if held then
        local label = (self.focus == "rail") and "Give"
            or (self.focus == "pool") and "Stow" or "Place/Swap"
        add(confirmGlyph, label, PROMPT_GO)
        add(cancelGlyph, "Cancel", PROMPT_NO)
        if self.focus == "rail" then
            add(regionGlyph, "Region")
            add(switchGlyph, "Switch")
        end
    else
        local label = (self.focus == "rail") and "Select"
            or (self.focus == "pool") and "Equip" or "Pick up"
        add(confirmGlyph, label, PROMPT_GO)
        add(cancelGlyph, "Close", PROMPT_NO)
        add(regionGlyph, "Region")
        add(switchGlyph, "Switch")
    end
    ButtonPrompt.draw(segments, self.boxX, self.boxY + BOX_H - 30, BOX_W, { align = "center" })
end

function Party:drawDrag()
    local drag = self.drag
    if not (drag and drag.active) then return end
    local item = self:dragItem()
    if not item then return end
    local x, y = drag.x - GHOST / 2, drag.y - GHOST / 2
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", x + 3, y + 3, GHOST, GHOST, 6, 6)
    local sprite = item.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1, 0.9)
        local iw, ih = sprite:getDimensions()
        local scale = math.min(GHOST / iw, GHOST / ih)
        love.graphics.draw(sprite, drag.x, drag.y, 0, scale, scale, iw / 2, ih / 2)
    else
        love.graphics.setColor(0.5, 0.5, 0.56, 0.9)
        love.graphics.rectangle("fill", x, y, GHOST, GHOST, 6, 6)
        love.graphics.setFont(self.headFont)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.printf((item.name or "?"):sub(1, 1), x, y + GHOST / 2 - 12, GHOST, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

-- Item tooltip, sourced by the device in use so it never lingers out of place: with the mouse it
-- follows the pointer and shows only while a cell is hovered (so it clears the moment the pointer
-- leaves); with keyboard/gamepad it sits at the active region's cursor cell. Out of combat there is
-- no acting unit, so `actor` is nil: ItemTooltip shows the item's static stats.
function Party:drawActiveTooltip()
    if InputMode.isMouse() then
        local item, maxRight
        if self.pool.hover then
            item, maxRight = self.pool:itemAt(self.pool.hover), Scale.WIDTH -- ItemTooltip flips left
        elseif self.grid.hover then
            local char = self:currentChar()
            item, maxRight = char and char.inventory[self.grid.hover], self.pool.x
        end
        if item then ItemTooltip.draw(item, self.mx, self.my, maxRight, nil) end
        return
    end

    -- Keyboard / gamepad: anchor at the focused region's cursor cell.
    local item, maxRight, ax, ay
    if self.focus == "pool" then
        item = self.pool:itemAt(self.pool.cursor)
        local cx, cy, cw = self.pool:cellRect(self.pool.cursor)
        if cx then maxRight, ax, ay = Scale.WIDTH, cx + cw, cy end
    elseif self.focus == "grid" then
        local char = self:currentChar()
        item = char and char.inventory[self.grid.cursor]
        local cx, cy, cw = self.grid:slotRect(self.grid.cursor)
        maxRight, ax, ay = self.pool.x, cx + cw, cy
    end
    if item and ax then ItemTooltip.draw(item, ax, ay, maxRight, nil) end
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function Party:mousemoved(x, y)
    self.mx, self.my = x, y
    if self.quantityPopup then self.quantityPopup:mousemoved(x, y) return end
    self.closeButton:mousemoved(x, y)
    self.grid:mousemoved(x, y)
    self.pool:mousemoved(x, y)
    local drag = self.drag
    if drag then
        drag.x, drag.y = x, y
        if math.abs(x - drag.startX) > DRAG_THRESHOLD or math.abs(y - drag.startY) > DRAG_THRESHOLD then
            drag.active = true
        end
    end
end

function Party:wheelmoved(_, dy)
    if dy == 0 then return end
    if self.quantityPopup then self.quantityPopup:wheelmoved(dy) return end
    local x, y = Scale.toGame(love.mouse.getPosition())
    if self.pool:contains(x, y) then
        self.pool:wheelmoved(dy)
        self.pool:mousemoved(x, y)
    elseif self:railContains(x, y) then
        local maxOff = math.max(0, #self.chars - self.railVisible)
        self.railOffset = math.max(0, math.min(maxOff, self.railOffset - dy))
    end
end

function Party:mousepressed(x, y, button)
    if self.quantityPopup then self.quantityPopup:mousepressed(x, y, button) return end
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end

    local empty = not (self.grid.picked or self.pool.picked)

    local ri = self:railIndexAt(x, y)
    if ri then
        self:setFocus("rail")
        self.railCursor = ri
        if self.grid.picked then
            self:giveGridItemToMember(self.grid.picked, ri)
        elseif self.pool.picked then
            self:givePoolItemToMember(self.pool.picked, ri)
        else
            self:focusChar(ri)
        end
        return
    end

    local cell = self.grid:indexAt(x, y)
    if cell then
        self:setFocus("grid")
        self.grid.cursor = cell
        self:activateGrid(cell)
        if empty and self.grid.picked == cell then self:beginDrag("grid", cell, x, y) end
        return
    end

    local hit, idx = self.pool:mousepressed(x, y, button)
    if hit then
        if idx then
            self:setFocus("pool")
            if self.grid.picked then
                self:stowFromGrid(self.grid.picked)
            else
                -- Begin a potential drag. Released without dragging, this reads as a click and
                -- auto-equips (mousereleased); dragged, it lets the player aim a slot/member/quantity.
                self:beginDrag("pool", idx, x, y)
            end
        end
        return
    end

    if not pointIn({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then
        self:close()
    end
end

function Party:mousereleased(x, y, button)
    if self.quantityPopup then self.quantityPopup:mousereleased(x, y, button) return end
    if button ~= 1 then return end
    local drag = self.drag
    if drag and drag.from == "pool" and not drag.active then
        -- A click on a stash cell (pressed and released in place): equip it to the focused member.
        self.drag = nil
        self:equipStashItem(drag.index)
        return
    end
    self:dropDrag(x, y)
end

function Party:keypressed(key)
    if self.quantityPopup then self.quantityPopup:keypressed(key) return end
    if key == "escape" then
        self.drag = nil
        if not (self.grid:cancelPickup() or self.pool:cancelPickup()) then self:close() end
    elseif key == "tab" then
        self:cycleFocus(1)
    elseif key == "q" then
        self:switchChar(-1)
    elseif key == "e" then
        self:switchChar(1)
    elseif key == "left" or key == "a" then self:navigate(-1, 0)
    elseif key == "right" or key == "d" then self:navigate(1, 0)
    elseif key == "up" or key == "w" then self:navigate(0, -1)
    elseif key == "down" or key == "s" then self:navigate(0, 1)
    elseif key == "return" or key == "kpenter" or key == "space" then self:confirm()
    end
end

function Party:gamepadpressed(joystick, button)
    if self.quantityPopup then self.quantityPopup:gamepadpressed(joystick, button) return end
    if button == "b" then
        self.drag = nil
        if not (self.grid:cancelPickup() or self.pool:cancelPickup()) then self:close() end
    elseif button == "y" then
        self:cycleFocus(1)
    elseif button == "leftshoulder" then
        self:switchChar(-1)
    elseif button == "rightshoulder" then
        self:switchChar(1)
    elseif button == "dpleft" then self:navigate(-1, 0)
    elseif button == "dpright" then self:navigate(1, 0)
    elseif button == "dpup" then self:navigate(0, -1)
    elseif button == "dpdown" then self:navigate(0, 1)
    elseif button == "a" then self:confirm()
    end
end

return Party
