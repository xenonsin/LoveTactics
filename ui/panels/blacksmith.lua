-- Blacksmith pop-up panel. Lists every forgeable weapon and armor the player owns -- across each
-- roster member's 3x3 grid and the stash -- in the left column, and details the highlighted item's
-- next upgrade (its cost in gold and materials) on the right. Upgrading swaps the item in place for a
-- fresh "+n" instance (models/blacksmith.lua) and saves. Same two-column shape as ui/panels/vendor.
--
--   local panel = Blacksmith.new({ player = p, onClose = fn })
--
-- Abilities are NOT forged here -- they are upgraded at their class vendor (see ui/panels/vendor).

local Menu = require("ui.menu")
local Blacksmith = require("models.blacksmith")
local Item = require("models.item")
local Material = require("models.material")
local Character = require("models.character")
local Player = require("models.player")
local CloseButton = require("ui.close_button")
local Scale = require("scale")
local InputMode = require("input_mode")

local BlacksmithPanel = {}
BlacksmithPanel.__index = BlacksmithPanel

local BOX_W, BOX_H = 720, 480
local LIST_TOP = 110
local ROW_H, ROW_SPACING, MAX_VISIBLE = 38, 8, 6

function BlacksmithPanel.new(opts)
    opts = opts or {}
    local self = setmetatable({}, BlacksmithPanel)
    self.onClose = opts.onClose
    self.titleFont = love.graphics.newFont(28)
    self.headFont = love.graphics.newFont(18)
    self.bodyFont = love.graphics.newFont(15)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    self.player = opts.player
    self.title = opts.title or "Blacksmith"

    self:refresh()
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

-- Every forgeable item the player owns, each with where it lives so an upgrade can swap it back in
-- place: a roster member's grid cell, or a stash slot.
function BlacksmithPanel:collect()
    local entries = {}
    for _, char in ipairs(self.player.roster or {}) do
        for cell = 1, Character.MAX_INVENTORY do
            local item = char.inventory[cell]
            if item and Blacksmith.canForge(item) then
                entries[#entries + 1] = { item = item, where = char.name or "?",
                    loc = { kind = "grid", char = char, cell = cell } }
            end
        end
    end
    for i, item in ipairs(self.player.stash or {}) do
        if Blacksmith.canForge(item) then
            entries[#entries + 1] = { item = item, where = "Stash", loc = { kind = "stash", index = i } }
        end
    end
    return entries
end

-- Rebuild the item list and menu (called on open and after every forge).
function BlacksmithPanel:refresh()
    local selected = self.menu and self.menu.selected or 1
    local scroll = self.menu and self.menu.scroll or 0

    self.entries = self:collect()

    local items = {}
    for i, entry in ipairs(self.entries) do
        local it = entry.item
        local label = it.name .. "  -  " .. entry.where
        items[#items + 1] = { label = label, action = function() self:upgrade(self.entries[i]) end }
    end

    self.menu = Menu.new(items, {
        buttonWidth = 300,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        startY = self.boxY + LIST_TOP,
        centerX = self.boxX + BOX_W * 0.26,
        font = self.bodyFont,
        maxVisible = MAX_VISIBLE,
    })
    self.menu.selected = math.min(selected, math.max(#items, 1))
    self.menu.scroll = scroll
    self.menu:scrollToSelection()
end

function BlacksmithPanel:hasItems()
    return self.entries and #self.entries > 0
end

-- Forge the highlighted item up one level: check gold + materials, spend them, swap the fresh "+n"
-- instance into the slot it came from, and save. Every refusal names itself in self.message.
function BlacksmithPanel:upgrade(entry)
    if not entry then return end
    local item = entry.item
    local cost = Blacksmith.upgradeCost(item)
    if not cost then
        self.message, self.messageOk = (item.name .. " is at maximum level."), false
        return
    end
    local newItem, reason = Blacksmith.upgrade(self.player, item)
    if not newItem then
        self.message = (reason == "gold" and "Not enough gold.")
            or (reason == "materials" and "Not enough materials.")
            or "It cannot be upgraded."
        self.messageOk = false
        return
    end
    if entry.loc.kind == "grid" then
        entry.loc.char.inventory[entry.loc.cell] = newItem
    else
        self.player.stash[entry.loc.index] = newItem
    end
    Player.save()
    self.message, self.messageOk = (newItem.name .. " forged."), true
    self:refresh()
end

function BlacksmithPanel:close()
    if self.onClose then self.onClose() end
end

function BlacksmithPanel:update(dt)
    if self:hasItems() then self.menu:update(dt) end
end

function BlacksmithPanel:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(self.title, self.boxX, self.boxY + 20, BOX_W, "center")

    -- Gold, top-left: one of the two things a forge spends.
    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(self.player.gold .. " gold", self.boxX + 24, self.boxY + 66, 240, "left")

    if not self:hasItems() then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.printf("No weapons or armor to forge.", self.boxX, self.boxY + BOX_H / 2, BOX_W, "center")
    else
        self.menu:draw()
        self:drawDetail()
    end

    if self.message then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(self.messageOk and 0.6 or 0.9, self.messageOk and 0.85 or 0.6,
            self.messageOk and 0.6 or 0.55)
        love.graphics.printf(self.message, self.boxX, self.boxY + BOX_H - 58, BOX_W, "center")
    end

    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    -- Show the glyphs for the device last used: pad buttons only in gamepad mode, keyboard/mouse otherwise.
    local hint = InputMode.isGamepad()
        and "A: Forge    D-pad: Scroll    B: Close"
        or "Click an item / Enter: Forge    Wheel: Scroll    Click X / Esc: Close"
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 32, BOX_W, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

function BlacksmithPanel:drawDetail()
    local entry = self.entries[self.menu.selected]
    if not entry then return end
    local item = entry.item

    local x = self.boxX + BOX_W * 0.52
    local w = BOX_W * 0.42
    local y = self.boxY + LIST_TOP

    love.graphics.setFont(self.headFont)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.printf(item.name, x, y, w, "left")

    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.6, 0.65, 0.75)
    love.graphics.printf(item.type .. "   (level " .. (item.level or 0) .. " / " .. Item.MAX_LEVEL .. ")",
        x, y + 26, w, "left")

    love.graphics.setColor(0.8, 0.82, 0.88)
    love.graphics.printf(item.description or "", x, y + 54, w, "left")

    local cost = Blacksmith.upgradeCost(item)
    if not cost then
        love.graphics.setColor(0.7, 0.85, 0.7)
        love.graphics.printf("At maximum level.", x, y + 150, w, "left")
        return
    end

    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("Upgrade to +" .. cost.level, x, y + 148, w, "left")

    -- Gold line, tinted red when short.
    local goldOk = self.player.gold >= cost.gold
    love.graphics.setColor(goldOk and 0.85 or 0.9, goldOk and 0.85 or 0.55, goldOk and 0.6 or 0.5)
    love.graphics.printf(cost.gold .. " gold  (have " .. self.player.gold .. ")", x, y + 176, w, "left")

    -- Material lines, one per required tier, tinted red when short.
    local row = 0
    for id, count in pairs(cost.materials) do
        local have = Player.materialCount(self.player, id)
        local def = Material.get(id)
        local ok = have >= count
        love.graphics.setColor(ok and 0.8 or 0.9, ok and 0.82 or 0.55, ok and 0.88 or 0.5)
        love.graphics.printf((def and def.name or id) .. ": " .. count .. "  (have " .. have .. ")",
            x, y + 202 + row * 24, w, "left")
        row = row + 1
    end
end

local function isInsideBox(self, x, y)
    return x >= self.boxX and x <= self.boxX + BOX_W
        and y >= self.boxY and y <= self.boxY + BOX_H
end

function BlacksmithPanel:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    if self:hasItems() then self.menu:mousemoved(x, y) end
end

-- Hand over the close X or any craftable row; arrow elsewhere. See ui/cursor.lua.
function BlacksmithPanel:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    if self:hasItems() and self.menu:mouseOverItem(x, y) then return "hand" end
    return "arrow"
end

function BlacksmithPanel:wheelmoved(dx, dy)
    if self:hasItems() then self.menu:wheelmoved(dx, dy) end
end

function BlacksmithPanel:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then
        self:close()
    elseif not isInsideBox(self, x, y) then
        self:close()
    elseif self:hasItems() then
        self.menu:mousepressed(x, y, button)
    end
end

function BlacksmithPanel:keypressed(key)
    if key == "escape" then
        self:close()
    elseif self:hasItems() then
        self.menu:keypressed(key)
    end
end

function BlacksmithPanel:gamepadpressed(joystick, button)
    if button == "b" then
        self:close()
    elseif self:hasItems() then
        self.menu:gamepadpressed(joystick, button)
    end
end

return BlacksmithPanel
