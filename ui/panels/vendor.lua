-- Vendor shop pop-up panel. Lists the vendor's stock (left column) and details the
-- highlighted item (right column), in the same two-column shape as ui/panels/quest_board.
-- Buying moves an item into the player's stash and saves.
--
--   local panel = Vendor.new({ vendor = "colosseum", player = p, onClose = fn })
--
-- Rank-locked items stay on the shelf, greyed out: seeing what reputation would buy you is
-- the point of the ladder, so they are shown rather than hidden.

local Menu = require("ui.menu")
local VendorModel = require("models.vendor")
local Player = require("models.player")
local Item = require("models.item")
local CloseButton = require("ui.close_button")
local Scale = require("scale")

local VendorPanel = {}
VendorPanel.__index = VendorPanel

local BOX_W, BOX_H = 700, 460

-- The shelf scrolls once a vendor stocks more than MAX_VISIBLE items (see ui/menu.lua).
local LIST_TOP = 110
local ROW_H, ROW_SPACING, MAX_VISIBLE = 38, 8, 5

function VendorPanel.new(opts)
    opts = opts or {}
    local self = setmetatable({}, VendorPanel)
    self.onClose = opts.onClose
    self.titleFont = love.graphics.newFont(28)
    self.headFont = love.graphics.newFont(18)
    self.bodyFont = love.graphics.newFont(15)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    self.player = opts.player
    self.vendorId = opts.vendor
    self.def = VendorModel.get(self.vendorId) or {}
    self.title = self.def.name or opts.title or "Vendor"

    self:refresh()

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

-- Rebuild stock and the menu from the player's current standing. Called on open and after
-- every purchase, so a rank-up (or spent gold) is reflected without reopening the panel.
function VendorPanel:refresh()
    local selected = self.menu and self.menu.selected or 1
    local scroll = self.menu and self.menu.scroll or 0

    self.rank = Player.repRank(self.player, self.vendorId)
    self.stock = VendorModel.stock(self.vendorId, self.rank)

    local items = {}
    for _, entry in ipairs(self.stock) do
        local label = entry.name .. "  -  " .. entry.price .. "g"
        if entry.locked then label = entry.name .. "  -  locked" end
        items[#items + 1] = {
            label = label,
            action = function() self:buy(entry) end,
        }
    end

    self.menu = Menu.new(items, {
        buttonWidth = 280,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        startY = self.boxY + LIST_TOP,
        centerX = self.boxX + BOX_W * 0.26,
        font = self.bodyFont,
        maxVisible = MAX_VISIBLE,
    })
    -- A purchase rebuilds the menu; keep the player looking at the row they were on.
    self.menu.selected = math.min(selected, math.max(#items, 1))
    self.menu.scroll = scroll
    self.menu:scrollToSelection()
end

-- Attempt a purchase. Every refusal explains itself in `self.message` rather than silently
-- doing nothing -- a click that appears to do nothing reads as a bug.
function VendorPanel:buy(entry)
    if entry.locked then
        self.message = "Requires " .. VendorModel.rankName(self.vendorId, entry.repRank) .. " standing."
        self.messageOk = false
        return
    end
    if not Player.spendGold(self.player, entry.price) then
        self.message = "Not enough gold."
        self.messageOk = false
        return
    end

    Player.addToStash(self.player, Item.instantiate(entry.id))
    Player.save()
    self.message = entry.name .. " bought. It is in your stash."
    self.messageOk = true
    self:refresh()
end

function VendorPanel:close()
    if self.onClose then self.onClose() end
end

function VendorPanel:update(dt)
    -- Menu:update polls the analog stick and can move the selection, which is the same
    -- divide-by-zero as navigation; an empty shop skips it (see hasStock).
    if #self.stock > 0 then self.menu:update(dt) end
end

function VendorPanel:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(self.title, self.boxX, self.boxY + 20, BOX_W, "center")

    self:drawStanding()

    if #self.stock == 0 then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.printf("Nothing for sale.", self.boxX, self.boxY + BOX_H / 2, BOX_W, "center")
    else
        self.menu:draw()
        self:drawLockedOverlay()
        self:drawDetail()
    end

    if self.message then
        love.graphics.setFont(self.bodyFont)
        if self.messageOk then
            love.graphics.setColor(0.6, 0.85, 0.6)
        else
            love.graphics.setColor(0.9, 0.6, 0.55)
        end
        love.graphics.printf(self.message, self.boxX, self.boxY + BOX_H - 58, BOX_W, "center")
    end

    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.printf("Click an item / Enter / A: Buy    Wheel: Scroll    Click X / Esc / B: Close",
        self.boxX, self.boxY + BOX_H - 32, BOX_W, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

-- Gold on the left, standing on the right: the two numbers that decide what you may buy.
function VendorPanel:drawStanding()
    local rep = Player.reputation(self.player, self.vendorId)
    local standing = VendorModel.rankName(self.vendorId, self.rank)

    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(self.player.gold .. " gold", self.boxX + 24, self.boxY + 66, 200, "left")

    love.graphics.setColor(0.7, 0.78, 0.9)
    local toNext, nextRank = VendorModel.nextRank(self.vendorId, rep)
    local text = standing
    if toNext then
        text = text .. "  (" .. toNext .. " rep to " .. VendorModel.rankName(self.vendorId, nextRank) .. ")"
    end
    love.graphics.printf(text, self.boxX + BOX_W - 424, self.boxY + 66, 400, "right")
end

-- The Menu widget has no concept of a disabled row, so locked entries are dimmed by
-- painting over them. Cheaper than forking the widget, and keeps every other panel's
-- navigation identical.
function VendorPanel:drawLockedOverlay()
    for i, entry in ipairs(self.stock) do
        local item = self.menu.items[i]
        if entry.locked and item and item.x then
            love.graphics.setColor(0.12, 0.13, 0.18, 0.6)
            love.graphics.rectangle("fill", item.x, item.y, item.w, item.h, 8, 8)
        end
    end
end

function VendorPanel:drawDetail()
    local entry = self.stock[self.menu.selected]
    if not entry then return end

    local x = self.boxX + BOX_W * 0.52
    local w = BOX_W * 0.42
    local y = self.boxY + LIST_TOP

    love.graphics.setFont(self.headFont)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.printf(entry.name, x, y, w, "left")

    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.6, 0.65, 0.75)
    love.graphics.printf(entry.type, x, y + 26, w, "left")

    love.graphics.setColor(0.8, 0.82, 0.88)
    love.graphics.printf(entry.description or "", x, y + 54, w, "left")

    if entry.locked then
        love.graphics.setColor(0.9, 0.6, 0.55)
        love.graphics.printf("Locked: needs " .. VendorModel.rankName(self.vendorId, entry.repRank),
            x, y + 168, w, "left")
    else
        love.graphics.setColor(0.95, 0.85, 0.55)
        love.graphics.printf("Price: " .. entry.price .. " gold", x, y + 168, w, "left")
    end
end

local function isInsideBox(self, x, y)
    return x >= self.boxX and x <= self.boxX + BOX_W
        and y >= self.boxY and y <= self.boxY + BOX_H
end

-- Menu:moveSelection takes `#items` as a modulus, so navigating an empty shop would divide
-- by zero. An empty stock swallows navigation entirely; only Close still answers.
function VendorPanel:hasStock()
    return #self.stock > 0
end

function VendorPanel:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    if self:hasStock() then self.menu:mousemoved(x, y) end
end

function VendorPanel:wheelmoved(dx, dy)
    if self:hasStock() then self.menu:wheelmoved(dx, dy) end
end

function VendorPanel:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then
        self:close()
    elseif not isInsideBox(self, x, y) then
        self:close()
    elseif self:hasStock() then
        self.menu:mousepressed(x, y, button)
    end
end

function VendorPanel:keypressed(key)
    if key == "escape" then
        self:close()
    elseif self:hasStock() then
        self.menu:keypressed(key)
    end
end

function VendorPanel:gamepadpressed(joystick, button)
    if button == "b" then
        self:close()
    elseif self:hasStock() then
        self.menu:gamepadpressed(joystick, button)
    end
end

return VendorPanel
