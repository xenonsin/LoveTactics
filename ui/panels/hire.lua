-- The hiring board: the Lodge's room where strangers wait for a company (models/hire.lua).
--
-- Built like ui/panels/cafe.lua and deliberately the same box: the keeper on the left, the three
-- strangers as a list, the one under the cursor read out in full on the right. Same one-focus-zone
-- navigation, so it plays on a mouse, a keyboard or a pad with nothing extra.
--
-- WHAT A CARD SAYS, and why in that order: who they are (name, class, people), then their numbers
-- AGAINST THE CLASS STANDARD -- "Speed 5 (+2)" -- because a raw 5 means nothing until you know a
-- hunter's standard is 3 (round 1, "stats-delta"). Then the stat they grow fastest in, then what they
-- carry, then the fee. A gifted stranger says so above the numbers and names the find they bring.
--
-- Hiring ASKS first, for the reason ordering at the Cafe does: on a pad, confirm is also the button that
-- walks the list, and a stray press here spends gold on a body you meant to look at.
--
--   local panel = HirePanel.new({ vendor = "hunters_lodge", player = p, onClose = fn })

local Menu = require("ui.menu")
local Choice = require("ui.panels.choice")
local CloseButton = require("ui.close_button")
local Keeper = require("ui.keeper")
local Vendor = require("models.vendor")
local Player = require("models.player")
local Character = require("models.character")
local Item = require("models.item")
local Class = require("models.class")
local Race = require("models.race")
local Hire = require("models.hire")
local Scale = require("scale")
local InputMode = require("input_mode")
local Sound = require("models.sound")
local Theme = require("ui.theme")

local HirePanel = {}
HirePanel.__index = HirePanel

local BOX_W, BOX_H = 1000, 580
local ROW_H, ROW_SPACING = 52, 8
local TOKEN = 72

-- The Armory sheet's own words for each stat (ui/panels/party.lua's STAT_ROWS), so a number read here
-- is the same number the player finds on the sheet after hiring.
local STAT_LABEL = {
    health = "HP", mana = "MP", stamina = "SP", damage = "Attack", magicDamage = "Magic",
    defense = "Defense", magicDefense = "M.Def", speed = "Speed", skill = "Skill", luck = "Luck",
}
local UP_COLOR = { 0.55, 0.82, 0.58 }
local DOWN_COLOR = { 0.88, 0.58, 0.52 }

local function pointIn(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function printWrapped(text, font, x, y, w)
    if not text or text == "" then return 0 end
    love.graphics.setFont(font)
    love.graphics.printf(text, x, y, w, "left")
    local _, lines = font:getWrap(text, w)
    return math.max(1, #lines) * font:getHeight()
end

local function asSentence(reason)
    if not reason or reason == "" then return "" end
    return reason:sub(1, 1):upper() .. reason:sub(2) .. "."
end

-- "Dwarf Knight", from the id alone.
local function calling(id)
    local class, race = Hire.split(id)
    local r = race and Race.get(race)
    return ((r and r.name) or race or "?") .. " " .. (Class.displayName(class) or class or "?")
end

function HirePanel.new(opts)
    opts = opts or {}
    local self = setmetatable({}, HirePanel)
    self.onClose = opts.onClose
    self.player = opts.player
    self.vendorId = opts.vendor or "hunters_lodge"
    self.def = Vendor.get(self.vendorId) or {}
    self.title = "The Hiring Board"

    self.titleFont = Theme.display(28)
    self.headFont = Theme.display(20)
    self.bodyFont = Theme.body(15)
    self.smallFont = Theme.body(13)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2
    self.vendorX = self.boxX + 24
    self.keeperY = self.boxY + 64
    self.keeperH = 296
    self.vendorY = self.keeperY + self.keeperH + 12
    self.vendorW = Keeper.W
    self.listLeft = self.vendorX + self.vendorW + 24
    self.listW = 260
    self.listTop = self.boxY + 96
    self.detailX = self.listLeft + self.listW + 24
    self.detailY = self.boxY + 72
    self.detailW = self.boxX + BOX_W - 24 - self.detailX

    self:refresh()
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

-- Rebuild the list off the board as it stands, so a stranger just hired reads as taken.
function HirePanel:refresh()
    local selected = self.menu and self.menu.selected or 1
    self.board = Hire.board(self.player)
    local items = {}
    for slot, offer in ipairs((self.board and self.board.offers) or {}) do
        local def = Character.defs[offer.id]
        local label = (def and def.name or "?") .. "  -  " .. calling(offer.id)
        if offer.hired then label = label .. "  (hired)" end
        items[#items + 1] = { label = label, action = function() self:ask(slot) end }
    end
    self.menu = Menu.new(items, {
        buttonWidth = self.listW,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        startY = self.listTop,
        centerX = self.listLeft + self.listW / 2,
        font = self.bodyFont,
        maxVisible = Hire.SLATE,
    })
    self.menu.selected = math.min(selected, math.max(#items, 1))
    self.menu:layout()
end

function HirePanel:hasRows() return self.board and #self.board.offers > 0 end
function HirePanel:selectedSlot() return self.menu and self.menu.selected end
function HirePanel:selectedOffer()
    return self.board and self.board.offers[self:selectedSlot() or 0]
end
function HirePanel:setMsg(text, ok) self.message, self.messageOk = text, ok end
function HirePanel:close() if self.onClose then self.onClose() end end

-- ---------------------------------------------------------------------------
-- Hiring
-- ---------------------------------------------------------------------------

function HirePanel:ask(slot)
    local offer = self.board and self.board.offers[slot]
    if not offer then return end
    local why = Hire.blockReason(self.player, slot)
    if why then
        Sound.play("ui.denied")
        self:setMsg(asSentence(why), false)
        return
    end
    local def = Character.defs[offer.id]
    self.confirm = Choice.new({
        title = "Hire This Stranger?",
        prompt = (def and def.name or "?") .. ", " .. calling(offer.id) .. "  -  " .. Hire.FEE .. " gold",
        options = {
            { label = "Hire", accent = UP_COLOR,
                cb = function() self.confirm = nil; self:commit(slot) end },
            { label = "Cancel", accent = { 0.78, 0.52, 0.50 },
                cb = function() self.confirm = nil end },
        },
        onClose = function() self.confirm = nil end,
    })
end

function HirePanel:commit(slot)
    local char, why = Hire.hire(self.player, slot)
    if not char then
        Sound.play("ui.denied")
        self:setMsg(asSentence(why or "not today"), false)
        return
    end
    Player.save()
    Sound.play("ui.confirm")
    self:setMsg(char.name .. " joins the company. Find them in the Armory.", true)
    self:refresh()
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function HirePanel:update(dt)
    if self.confirm then return end
    if self:hasRows() then self.menu:update(dt) end
end

function HirePanel:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, self.boxX, self.boxY + 18, BOX_W, "center")

    self:drawVendor()
    if self:hasRows() then
        self.menu:draw()
        self:drawTakenOverlay()
        self:drawDetail()
    else
        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.muted)
        love.graphics.printf("Nobody is waiting today.", self.listLeft, self.boxY + 200, self.listW, "center")
    end

    self:drawFooter()
    self.closeButton:draw()
    if self.confirm then self.confirm:draw() end
    love.graphics.setColor(1, 1, 1)
end

-- The keeper, then the purse and the board's one rule: whoever is not hired moves on.
function HirePanel:drawVendor()
    Keeper.draw(self.vendorId, self.vendorX, self.keeperY, self.vendorW, self.keeperH, {
        nameFont = self.bodyFont,
        title = self.def.name,
        line = false,
    })
    local x, y, w = self.vendorX, self.vendorY, self.vendorW
    local h = 96
    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", x, y, w, h, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", x, y, w, h, Theme.R, Theme.R)
    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.accentAmber)
    love.graphics.print((self.player and self.player.gold or 0) .. " gold", x + 12, y + 12)
    Theme.set(Theme.muted)
    printWrapped("Hiring costs " .. Hire.FEE .. " gold. Whoever you leave moves on before you're back.",
        self.smallFont, x + 12, y + 38, w - 24)
end

function HirePanel:drawTakenOverlay()
    for i, offer in ipairs(self.board.offers) do
        local slot = self.menu.items[i]
        if slot and slot.x and offer.hired then
            Theme.set(Theme.mount, 0.55)
            love.graphics.rectangle("fill", slot.x, slot.y, slot.w, slot.h, Theme.R, Theme.R)
        end
    end
end

function HirePanel:drawDetail()
    local offer = self:selectedOffer()
    if not offer then return end
    local def = Character.defs[offer.id]
    if not def then return end
    local x, y, w = self.detailX, self.detailY, self.detailW

    -- The token, in the stranger's own tint, beside the name.
    local Sprite = require("models.sprite")
    local sprite = Sprite.load(def.sprite)
    if type(sprite) == "userdata" then
        local t = def.tint or { 1, 1, 1 }
        love.graphics.setColor(t[1], t[2], t[3])
        local sw, sh = sprite:getDimensions()
        local scale = math.min(TOKEN / sw, TOKEN / sh)
        love.graphics.draw(sprite, x + TOKEN / 2, y + TOKEN / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        Theme.set(Theme.slot)
        love.graphics.rectangle("fill", x, y, TOKEN, TOKEN, 6, 6)
    end
    local tx = x + TOKEN + 14
    Theme.set(Theme.accentAmber)
    printWrapped(def.name, self.headFont, tx, y + 8, w - TOKEN - 14)
    Theme.set(Theme.ink)
    printWrapped(calling(offer.id), self.bodyFont, tx, y + 38, w - TOKEN - 14)

    local ty = y + TOKEN + 12
    if def.gifted then
        Theme.set(Theme.accentAmber)
        local gift = offer.gift and Item.defs[offer.gift]
        ty = ty + printWrapped("Gifted" .. (gift and ("  -  brings " .. gift.name) or ""),
            self.bodyFont, x, ty, w) + 6
    end

    -- Every rolled stat against the class standard. Two columns, so all ten fit above the kit.
    Theme.set(Theme.muted)
    ty = ty + printWrapped("Against the class standard", self.smallFont, x, ty, w) + 4
    -- The number the Armory will show once they are hired: the rolled line PLUS the people's own
    -- (Race.statBonus), which Character.instantiate folds in. The bracket is the roll alone, since the
    -- people is already named on the line above.
    local raceLine = Race.statBonus(def.race) or {}
    local colW = math.floor(w / 2)
    local rowH = self.bodyFont:getHeight() + 2
    love.graphics.setFont(self.bodyFont)
    for i, stat in ipairs(Hire.SPREAD_STATS) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local cx, cy = x + col * colW, ty + row * rowH
        local value = (def.stats[stat] or 0) + (raceLine[stat] or 0)
        local d = (def.rolled or {})[stat] or 0
        Theme.set(Theme.muted)
        love.graphics.print(STAT_LABEL[stat] or stat, cx, cy)
        Theme.set(Theme.ink)
        love.graphics.print(tostring(value), cx + 70, cy)
        if d ~= 0 then
            love.graphics.setColor(d > 0 and UP_COLOR or DOWN_COLOR)
            love.graphics.print(string.format("(%s%d)", d > 0 and "+" or "", d), cx + 110, cy)
        end
    end
    ty = ty + math.ceil(#Hire.SPREAD_STATS / 2) * rowH + 8

    -- The aptitude: the one stat this body grows faster in, worded the way the sheet marks it.
    for stat, amount in pairs(def.personalGrowth or {}) do
        Theme.set(Theme.accentAmber)
        ty = ty + printWrapped("Grows fast in " .. (STAT_LABEL[stat] or stat) .. " (+" .. amount
            .. " a level)", self.bodyFont, x, ty, w) + 6
    end

    -- What they walk in carrying: the class's standard kit, then the find if they have one.
    local names = {}
    for _, id in ipairs(def.startingItems or {}) do
        local idef = Item.defs[id]
        names[#names + 1] = idef and idef.name or id
    end
    Theme.set(Theme.muted)
    ty = ty + printWrapped("Carries: " .. table.concat(names, ", "), self.smallFont, x, ty, w) + 6

    local footY = self.boxY + BOX_H - 96
    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(offer.hired and "Hired" or (Hire.FEE .. " gold"), x, footY, w, "left")
    local why = not offer.hired and Hire.blockReason(self.player, self:selectedSlot())
    if why then
        love.graphics.setColor(DOWN_COLOR)
        printWrapped(asSentence(why), self.smallFont, x, footY + 22, w)
    end
end

function HirePanel:drawFooter()
    love.graphics.setFont(self.smallFont)
    if self.message then
        love.graphics.setColor(self.messageOk and UP_COLOR or DOWN_COLOR)
        love.graphics.printf(self.message, self.boxX, self.boxY + BOX_H - 52, BOX_W, "center")
    end
    Theme.set(Theme.muted)
    local hint = InputMode.isGamepad()
        and "A: hire    D-pad: choose    B: close"
        or "Enter: hire    Arrows: choose    Esc: close"
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 30, BOX_W, "center")
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function HirePanel:mousemoved(x, y)
    if self.confirm then self.confirm:mousemoved(x, y) return end
    self.closeButton:mousemoved(x, y)
    if self:hasRows() then self.menu:mousemoved(x, y) end
end

function HirePanel:cursorKind(x, y)
    if self.confirm then return self.confirm:cursorKind(x, y) end
    if self.closeButton:contains(x, y) then return "hand" end
    if self:hasRows() and self.menu:mouseOverItem(x, y) then return "hand" end
    return "arrow"
end

function HirePanel:wheelmoved(dx, dy)
    if self.confirm then return end
    if self:hasRows() then self.menu:wheelmoved(dx, dy) end
end

function HirePanel:mousepressed(x, y, button)
    if self.confirm then self.confirm:mousepressed(x, y, button) return end
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end
    if self:hasRows() and self.menu:mouseOverItem(x, y) then
        self.menu:mousepressed(x, y, button)
        return
    end
    if not pointIn({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then self:close() end
end

function HirePanel:keypressed(key)
    if self.confirm then self.confirm:keypressed(key) return end
    if key == "escape" then self:close()
    elseif self:hasRows() then self.menu:keypressed(key) end
end

function HirePanel:gamepadpressed(joystick, button)
    if self.confirm then self.confirm:gamepadpressed(joystick, button) return end
    if button == "b" then self:close()
    elseif self:hasRows() then self.menu:gamepadpressed(joystick, button) end
end

return HirePanel
