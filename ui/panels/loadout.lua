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
-- Follows the modal-panel conventions of ui/panels/quest_board.lua (dim backdrop, centered box,
-- ui/close_button.lua) and the three-input standard: mouse (click cells / rows / arrows / X),
-- keyboard (arrows + Enter to move items, Tab to switch side, Q/E to switch character, Esc to
-- close), gamepad (D-pad + A, Y to switch side, shoulder buttons to switch character, B to close).
--
--   local panel = Loadout.new({ player = player, onClose = fn })

local InventoryGrid = require("ui.inventory_grid")
local StashList = require("ui.stash_list")
local CloseButton = require("ui.close_button")
local Character = require("models.character")
local Player = require("models.player")
local Scale = require("scale")

local Loadout = {}
Loadout.__index = Loadout

local BOX_W, BOX_H = 800, 560
local STASH_W = 300

-- Legend rows: adjacency link kind -> human label (colors come from InventoryGrid.LINK_COLOR).
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
end

-- Move the keyboard/gamepad cursor between the two surfaces, dropping whatever is in hand: an
-- in-progress pickup belongs to the surface it came from.
function Loadout:setFocus(which)
    self.focus = which
    self.stash.focused = (which == "stash")
    self.grid:cancelPickup()
    self.stash:cancelPickup()
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
        self:placeIntoGrid(self.stash.picked, cell)
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

function Loadout:update() end

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
        local c = InventoryGrid.LINK_COLOR[row.kind]
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
    local hint = "Click / Enter: pick up then place    Tab / Y: grid <-> stash    Q/E: character    Esc: close"
    if self.grid.picked then
        hint = "Holding an item -- click a grid cell to move it, or the stash to store it."
    elseif self.stash.picked then
        hint = "Holding a stashed item -- click a grid cell to equip it (a full cell swaps back)."
    end
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 30, BOX_W, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

function Loadout:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    self.grid:mousemoved(x, y)
    self.stash:mousemoved(x, y)
end

function Loadout:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then
        self:close()
        return
    end
    if #self.chars > 1 and pointIn(self.prevArrow, x, y) then self:switchChar(-1) return end
    if #self.chars > 1 and pointIn(self.nextArrow, x, y) then self:switchChar(1) return end

    local cell = self.grid:indexAt(x, y)
    if cell then
        self.focus = "grid"
        self.stash.focused = false
        self.grid.cursor = cell
        self:activateGrid(cell)
        return
    end

    -- The stash reports both "I consumed this click" (a scroll arrow) and, for a row, which one.
    local hit, row = self.stash:mousepressed(x, y, button)
    if hit then
        if row then
            self.focus = "stash"
            self.stash.focused = true
            self:activateStash(row)
        end
        return
    end

    if not pointIn({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then
        self:close() -- click outside dismisses the modal
    end
end

function Loadout:keypressed(key)
    if key == "escape" then
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
    if button == "b" then
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
