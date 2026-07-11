-- Loadout pop-up panel: arrange a character's items in the 3x3 grid, and move gear between that
-- grid and the player's stash. This is where item positions change (combat never reorders), reached
-- from the hub (a building with panel = "loadout") and the overworld (states/game.lua opens it
-- directly). Hosts a ui/inventory_grid.lua editor beside a ui/stash_list.lua column, plus a
-- character selector that cycles the player's roster and a legend for the adjacency link colors.
--
-- Both widgets are PICK-THEN-PLACE surfaces, but neither moves an item across the boundary itself:
-- this panel owns every transfer (see :placeIntoGrid / :stowFromGrid), so the two can never disagree
-- about who holds what. Picking up in one clears any pickup in the other -- only one item is ever
-- in hand.
--
-- DRAG AND DROP rides on top of that same pickup rather than replacing it: a press that picks an
-- item up also arms a drag, and only a release that moved the mouse resolves it. A press and release
-- in place therefore still leaves the item in hand for a second click, so both idioms work without
-- either widget knowing which one the player used.
--
-- Follows the modal-panel conventions of ui/panels/quest_board.lua (dim backdrop, centered box,
-- ui/close_button.lua) and the three-input standard: mouse (click cells / rows / arrows / X, drag
-- items between the grid and the stash, wheel to scroll the stash), keyboard (arrows + Enter to move
-- items, Tab to switch side, Q/E to switch character, Esc to close), gamepad (D-pad + A, Y to switch
-- side, shoulder buttons to switch character, B to close).
--
--   local panel = Loadout.new({ player = player, onClose = fn })

local InventoryGrid = require("ui.inventory_grid")
local StashList = require("ui.stash_list")
local AdjacencyLinks = require("ui.adjacency_links")
local CloseButton = require("ui.close_button")
local QuantityPopup = require("ui.quantity_popup")
local Character = require("models.character")
local Player = require("models.player")
local Item = require("models.item")
local Scale = require("scale")

local Loadout = {}
Loadout.__index = Loadout

local BOX_W, BOX_H = 800, 560
local STASH_W = 300

-- Pixels the mouse must travel before a press becomes a drag rather than a click. Below it a
-- release is a plain click and the pickup stays in hand (pick-then-place).
local DRAG_THRESHOLD = 5
local GHOST = 48 -- size of the item icon that follows the cursor mid-drag

-- Legend rows: adjacency link kind -> human label (colors come from AdjacencyLinks.COLOR).
local LEGEND = {
    { kind = "aura",        label = "Aura (grants to neighbor)" },
    { kind = "boost",       label = "Scales off neighbor" },
    { kind = "requirement", label = "Requirement met" },
}

function Loadout.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Loadout)
    self.onClose = opts.onClose
    self.player = opts.player

    self.titleFont = love.graphics.newFont(28)
    self.headFont = love.graphics.newFont(18)
    self.bodyFont = love.graphics.newFont(15)
    self.smallFont = love.graphics.newFont(13)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    -- Characters that can be arranged: the whole roster (party members reference the same
    -- instances), falling back to the party if a roster isn't present.
    self.chars = (self.player and self.player.roster) or (self.player and self.player.party) or {}
    self.charIndex = 1
    self.focus = "grid" -- which surface the keyboard/gamepad cursor drives
    self.drag = nil     -- in-flight drag: { from = "grid"|"stash", index, x, y, startX, startY, active }
    self.quantityPopup = nil -- open "how many?" picker when splitting a stash stack, else nil

    local gridW = InventoryGrid.new({}).gridW
    local contentY = self.boxY + 130
    self.grid = InventoryGrid.new({
        x = self.boxX + 40 + (BOX_W - STASH_W - 80 - gridW) / 2,
        y = contentY,
        char = self.chars[1],
    })
    self.stash = StashList.new({
        x = self.boxX + BOX_W - STASH_W - 30,
        y = contentY,
        w = STASH_W,
        h = 330,
        stash = self.player and self.player.stash,
    })

    -- Prev/next character arrows (clickable for mouse-only play), flanking the name header.
    local ay = self.boxY + 78
    self.prevArrow = { x = self.boxX + 40, y = ay, w = 34, h = 30 }
    self.nextArrow = { x = self.boxX + BOX_W - 74, y = ay, w = 34, h = 30 }

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

function Loadout:close()
    if self.onClose then self.onClose() end
end

function Loadout:currentChar()
    return self.chars[self.charIndex]
end

function Loadout:switchChar(delta)
    if #self.chars == 0 then return end
    self.charIndex = (self.charIndex - 1 + delta) % #self.chars + 1
    self.grid:setChar(self:currentChar())
    self.stash:cancelPickup()
    self:cancelDrag()
end

-- Move the keyboard/gamepad cursor between the two surfaces, dropping whatever is in hand: an
-- in-progress pickup belongs to the surface it came from.
function Loadout:setFocus(which)
    self.focus = which
    self.stash.focused = (which == "stash")
    self.grid:cancelPickup()
    self.stash:cancelPickup()
    self:cancelDrag()
end

-- Forget an in-flight drag without touching the pickup it was carrying: a drag is only ever a way
-- to aim a pickup that already happened, so cancelling one leaves the item wherever it was.
function Loadout:cancelDrag()
    self.drag = nil
end

function Loadout:toggleFocus()
    self:setFocus(self.focus == "grid" and "stash" or "grid")
end

-- ---------------------------------------------------------------------------
-- Transfers. The panel owns both directions, so an item is never in two places at once.
-- ---------------------------------------------------------------------------

-- Place the stash item held at row `stashIndex` into grid cell `cell`. A cell that already holds an
-- item swaps: whatever was there goes back to the stash, so the grid never silently overflows.
function Loadout:placeIntoGrid(stashIndex, cell)
    local char = self:currentChar()
    if not (char and self.player) then return end
    local incoming = Player.takeFromStash(self.player, stashIndex)
    if not incoming then return end

    local displaced = char.inventory[cell]
    char.inventory[cell] = incoming
    if displaced then Player.addToStash(self.player, displaced) end

    self.stash:refresh()
end

-- The stash row currently holding `item` (identity match), or nil. The stash list is mutated as
-- items move, so a captured index can go stale; a captured reference does not.
function Loadout:stashIndexOf(item)
    for i, it in ipairs((self.player and self.player.stash) or {}) do
        if it == item then return i end
    end
    return nil
end

-- Route a stash row toward grid cell `cell`. A stackable consumable holding more than one first
-- asks how many to move (openQuantityPopup); everything else moves in full straight away. This is
-- the single entry point for both a click-to-place and a drag-drop from the stash.
function Loadout:transferStashToGrid(stashIndex, cell)
    local stashItem = self.player and self.player.stash and self.player.stash[stashIndex]
    if not stashItem then return end
    if Item.isStackable(stashItem) and (stashItem.quantity or 1) > 1 then
        self:openQuantityPopup(stashItem, cell)
    else
        self:commitStashToGrid(stashItem, cell, stashItem.quantity or 1)
    end
end

-- Move `count` of the stash item (by reference) onto the current character. A stackable consumable
-- merges into the character's existing same-id stack(s) first -- so re-dropping a potion the party
-- already carries just grows that stack rather than swapping a cell -- and only the leftover claims
-- a cell. A non-stackable item ignores `count` and does the plain whole-item place/swap.
function Loadout:commitStashToGrid(stashItem, cell, count)
    local char = self:currentChar()
    if not (char and self.player and stashItem) then return end

    if not Item.isStackable(stashItem) then
        local index = self:stashIndexOf(stashItem)
        if index then self:placeIntoGrid(index, cell) end
        return
    end

    count = math.max(1, math.min(count or stashItem.quantity, stashItem.quantity))

    -- Whether the character already holds this consumable decides where any leftover lands: overflow
    -- from an existing (now-full) stack spills to a free cell, but a brand-new consumable honors the
    -- dropped cell so the player places it where they aimed.
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
        -- slot nil (grid full while every existing stack was full): the leftover stays in the stash.
    end

    -- Draw the stash stack down by whatever actually left it, dropping the row once it empties.
    stashItem.quantity = stashItem.quantity - (count - remaining)
    if stashItem.quantity <= 0 then
        local index = self:stashIndexOf(stashItem)
        if index then Player.takeFromStash(self.player, index) end
    end

    self.stash:cancelPickup()
    self.stash:refresh()
end

-- Open the "how many?" picker for splitting a multi-count stash stack. Captures the item by
-- reference (its stash row may shift as things move) and finishes the transfer on confirm.
function Loadout:openQuantityPopup(stashItem, cell)
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
            self.stash:cancelPickup()
        end,
    })
end

-- Send the grid item held in cell `cell` out to the stash, emptying the cell.
function Loadout:stowFromGrid(cell)
    local char = self:currentChar()
    if not (char and self.player) then return end
    local item = char.inventory[cell]
    if not item then return end
    Character.removeItem(char, item)
    Player.addToStash(self.player, item)

    self.grid:cancelPickup()
    self.stash:refresh()
end

-- A confirm on grid cell `cell`. With a stash row in hand this lands the transfer; otherwise the
-- grid handles it as an ordinary pick-then-swap within the 3x3.
function Loadout:activateGrid(cell)
    if self.stash.picked then
        self:transferStashToGrid(self.stash.picked, cell)
    else
        self.grid:activate(cell)
    end
end

-- A confirm on stash row `row`. With a grid cell in hand this stows that item; otherwise it picks
-- the row up, ready to be placed into the grid.
function Loadout:activateStash(row)
    if self.grid.picked then
        self:stowFromGrid(self.grid.picked)
    else
        self.stash:activate(row)
    end
end

-- ---------------------------------------------------------------------------
-- Dragging. A drag never moves an item on its own -- it ends by calling the same transfers a click
-- would, so there is still exactly one code path per direction.
-- ---------------------------------------------------------------------------

-- Arm a drag on the item a press just picked up. Only a press that CREATED a pickup is draggable:
-- a press that placed or swapped an item already finished its transfer.
function Loadout:beginDrag(from, index, x, y)
    self.drag = { from = from, index = index, x = x, y = y, startX = x, startY = y, active = false }
end

-- The item a drag is carrying, read live from wherever it still lives (a drag doesn't remove it).
function Loadout:dragItem()
    local drag = self.drag
    if not drag then return nil end
    if drag.from == "stash" then
        return self.player and self.player.stash and self.player.stash[drag.index]
    end
    local char = self:currentChar()
    return char and char.inventory[drag.index]
end

-- Resolve a drag at the release point. Anywhere that isn't a valid destination puts the item back,
-- so a drag into empty space is a cancel rather than a loss.
function Loadout:dropDrag(x, y)
    local drag = self.drag
    self.drag = nil
    if not (drag and drag.active) then return end -- a click, not a drag: the pickup stays in hand

    local cell = self.grid:indexAt(x, y)
    if drag.from == "stash" then
        if cell then
            self:transferStashToGrid(drag.index, cell)
        else
            self.stash:cancelPickup()
        end
    elseif cell then
        self.grid:activate(cell) -- onto another cell: swap (onto its own cell: a no-op release)
    elseif self.stash:contains(x, y) then
        self:stowFromGrid(drag.index)
    else
        self.grid:cancelPickup()
    end
end

function Loadout:update(dt)
    if self.quantityPopup then self.quantityPopup:update(dt) end
end

local function pointIn(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function Loadout:draw()
    -- Dim the world behind the panel.
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    -- Panel frame.
    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)

    -- Title.
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("Loadout", self.boxX, self.boxY + 22, BOX_W, "center")

    local char = self:currentChar()
    if not char then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.printf("No characters to equip.", self.boxX, self.boxY + BOX_H / 2, BOX_W, "center")
        self.closeButton:draw()
        love.graphics.setColor(1, 1, 1)
        return
    end

    -- Character name + selector arrows.
    love.graphics.setFont(self.headFont)
    love.graphics.setColor(0.95, 0.95, 0.97)
    love.graphics.printf(char.name or "?", self.boxX, self.boxY + 82, BOX_W, "center")
    if #self.chars > 1 then
        for _, arrow in ipairs({ { r = self.prevArrow, g = "<" }, { r = self.nextArrow, g = ">" } }) do
            love.graphics.setColor(0.22, 0.24, 0.32)
            love.graphics.rectangle("fill", arrow.r.x, arrow.r.y, arrow.r.w, arrow.r.h, 6, 6)
            love.graphics.setColor(0.6, 0.65, 0.78)
            love.graphics.rectangle("line", arrow.r.x, arrow.r.y, arrow.r.w, arrow.r.h, 6, 6)
            love.graphics.setColor(0.95, 0.95, 0.97)
            love.graphics.printf(arrow.g, arrow.r.x, arrow.r.y + 6, arrow.r.w, "center")
        end
    end

    self.grid:draw()

    -- Stash column, headed so it reads as a separate place from the grid.
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.75, 0.78, 0.86)
    love.graphics.print("Stash (" .. self.stash:count() .. ")", self.stash.x, self.stash.y - 20)
    self.stash:draw()

    -- Legend for the connector-line colors, under the grid.
    local ly = self.grid.y + self.grid.gridH + 16
    love.graphics.setFont(self.bodyFont)
    local lx = self.grid.x
    for _, row in ipairs(LEGEND) do
        local c = AdjacencyLinks.COLOR[row.kind]
        love.graphics.setColor(c[1], c[2], c[3])
        love.graphics.setLineWidth(3)
        love.graphics.line(lx, ly + 8, lx + 26, ly + 8)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.8, 0.82, 0.88)
        love.graphics.print(row.label, lx + 36, ly)
        ly = ly + 24
    end

    -- Footer hint, naming the transfer the player has half-completed.
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    local hint = "Click or drag to move items    Wheel: scroll stash    Tab / Y: grid <-> stash    Q/E: character    Esc: close"
    if self.grid.picked then
        hint = "Holding an item -- drop it on a grid cell to move it, or on the stash to store it."
    elseif self.stash.picked then
        hint = "Holding a stashed item -- drop it on a grid cell to equip it (a full cell swaps back)."
    end
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 30, BOX_W, "center")

    self.closeButton:draw()
    self:drawDrag()

    -- The quantity picker rides above everything, dimming the panel behind it.
    if self.quantityPopup then self.quantityPopup:draw() end
    love.graphics.setColor(1, 1, 1)
end

-- The dragged item, drawn last so it rides over both surfaces and the panel frame.
function Loadout:drawDrag()
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

    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.95, 0.95, 0.97)
    love.graphics.printf(item.name or "?", drag.x - 70, y + GHOST + 4, 140, "center")
    love.graphics.setColor(1, 1, 1)
end

function Loadout:mousemoved(x, y)
    if self.quantityPopup then self.quantityPopup:mousemoved(x, y) return end
    self.closeButton:mousemoved(x, y)
    self.grid:mousemoved(x, y)
    self.stash:mousemoved(x, y)

    local drag = self.drag
    if drag then
        drag.x, drag.y = x, y
        if math.abs(x - drag.startX) > DRAG_THRESHOLD or math.abs(y - drag.startY) > DRAG_THRESHOLD then
            drag.active = true
        end
    end
end

-- The stash scrolls under the wheel when the pointer is over it. Read the pointer live rather than
-- from the last mousemoved, so the very first wheel notch after the panel opens already lands.
function Loadout:wheelmoved(_, dy)
    if dy == 0 then return end
    if self.quantityPopup then self.quantityPopup:wheelmoved(dy) return end
    local x, y = Scale.toGame(love.mouse.getPosition())
    if not self.stash:contains(x, y) then return end
    self.stash:wheelmoved(dy)
    self.stash:mousemoved(x, y) -- rows moved under the cursor: re-hover
end

function Loadout:mousepressed(x, y, button)
    if self.quantityPopup then self.quantityPopup:mousepressed(x, y, button) return end
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then
        self:close()
        return
    end
    if #self.chars > 1 and pointIn(self.prevArrow, x, y) then self:switchChar(-1) return end
    if #self.chars > 1 and pointIn(self.nextArrow, x, y) then self:switchChar(1) return end

    -- A press that lifts an item (rather than placing the one already in hand) can be dragged.
    local empty = not (self.grid.picked or self.stash.picked)

    local cell = self.grid:indexAt(x, y)
    if cell then
        self.focus = "grid"
        self.stash.focused = false
        self.grid.cursor = cell
        self:activateGrid(cell)
        if empty and self.grid.picked == cell then self:beginDrag("grid", cell, x, y) end
        return
    end

    -- The stash reports both "I consumed this click" (a scroll arrow) and, for a row, which one.
    local hit, row = self.stash:mousepressed(x, y, button)
    if hit then
        if row then
            self.focus = "stash"
            self.stash.focused = true
            self:activateStash(row)
            if empty and self.stash.picked == row then self:beginDrag("stash", row, x, y) end
        end
        return
    end

    if not pointIn({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then
        self:close() -- click outside dismisses the modal
    end
end

function Loadout:mousereleased(x, y, button)
    if self.quantityPopup then self.quantityPopup:mousereleased(x, y, button) return end
    if button ~= 1 then return end
    self:dropDrag(x, y)
end

function Loadout:keypressed(key)
    if self.quantityPopup then self.quantityPopup:keypressed(key) return end
    if key == "escape" then
        self:cancelDrag()
        if not (self.grid:cancelPickup() or self.stash:cancelPickup()) then self:close() end
    elseif key == "tab" then
        self:toggleFocus()
    elseif key == "q" then
        self:switchChar(-1)
    elseif key == "e" then
        self:switchChar(1)
    elseif self.focus == "stash" then
        local row = self.stash:keypressed(key)
        if row then self:activateStash(row) end
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:activateGrid(self.grid.cursor)
    else
        self.grid:keypressed(key)
    end
end

function Loadout:gamepadpressed(joystick, button)
    if self.quantityPopup then self.quantityPopup:gamepadpressed(joystick, button) return end
    if button == "b" then
        self:cancelDrag()
        if not (self.grid:cancelPickup() or self.stash:cancelPickup()) then self:close() end
    elseif button == "y" then
        self:toggleFocus()
    elseif button == "leftshoulder" then
        self:switchChar(-1)
    elseif button == "rightshoulder" then
        self:switchChar(1)
    elseif self.focus == "stash" then
        local row = self.stash:gamepadpressed(joystick, button)
        if row then self:activateStash(row) end
    elseif button == "a" then
        self:activateGrid(self.grid.cursor)
    else
        self.grid:gamepadpressed(joystick, button)
    end
end

return Loadout
