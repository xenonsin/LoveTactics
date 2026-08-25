-- The Cafe: a menu, not a shelf. One supper, bought before the road, worn by the whole company for the
-- whole quest -- see models/meal.lua for the rules and docs/meals.md for why they are those rules.
--
-- It is deliberately built like ui/panels/shop.lua and deliberately is not that panel. Same box, same
-- three columns (shopkeeper | list | detail), same one-focus-zone navigation that makes a screen
-- gamepad-friendly. What is different is everything the transaction is:
--
--   * THERE IS NO SELL SIDE, so there are no mode tabs. You cannot bring a meal back.
--   * THERE IS NO STASH. A meal is never an item and never occupies a grid cell; buying one writes a
--     single id onto the player and nothing else changes hands.
--   * YOU MAY HOLD ONE. Once the company has eaten, every row refuses until a quest eats it through --
--     so the panel's loudest element is the banner saying what is currently on the table.
--
-- That last point is why the held meal is drawn at the TOP of the detail column and again as a line
-- under the portrait, rather than as a greyed-out list: the reason a row will not buy is not a property
-- of that row, and a player who has forgotten they ordered this morning must be told what they ordered,
-- not merely that they cannot order again.
--
--   local panel = Cafe.new({ vendor = "cafe", player = p, onClose = fn })

local Menu = require("ui.menu")
local Choice = require("ui.panels.choice") -- the generic yes/no modal, hosted here as the order confirmation
local CloseButton = require("ui.close_button")
local ItemTooltip = require("ui.item_tooltip") -- printFlavor: the sheared italic story line, as everywhere else
local Meal = require("models.meal")
local Vendor = require("models.vendor") -- only for the shopkeeper's name and pitch
local Player = require("models.player")
local VendorIcons = require("ui.vendor_icons") -- the counter's mark, worn on its name in the header
local Scale = require("scale")
local InputMode = require("input_mode")
local Sound = require("models.sound")
local Theme = require("ui.theme")

local Cafe = {}
Cafe.__index = Cafe

local BOX_W, BOX_H = 1000, 580
local ROW_H, ROW_SPACING, MAX_VISIBLE = 38, 6, 9

-- The two halves of a platter, coloured apart wherever both are drawn: the courses are plain numbers
-- (jade, the restorative family) and the kitchen skill is the rule you are really paying for (amber,
-- the same spotlight gold a focused thing wears everywhere else).
local COURSE_COLOR = { 0.42, 0.80, 0.62 }

local function pointIn(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- Print wrapped text and return the height it actually took, so the detail column can stack blocks of
-- unknown length without any of them guessing at the one above. Measured through font:getWrap rather
-- than by dividing widths, which under a proportional face is wrong by a line often enough to overlap
-- the price at the foot of the pane.
local function printWrapped(text, font, x, y, w)
    if not text or text == "" then return 0 end
    love.graphics.setFont(font)
    love.graphics.printf(text, x, y, w, "left")
    local _, lines = font:getWrap(text, w)
    return math.max(1, #lines) * font:getHeight()
end

-- A refusal, said as a sentence: Meal.blockReason speaks in lower-case fragments so it can also be
-- dropped mid-line, and every place this panel shows one wants it capitalised and stopped.
local function asSentence(reason)
    if not reason or reason == "" then return "" end
    return reason:sub(1, 1):upper() .. reason:sub(2) .. "."
end

function Cafe.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Cafe)
    self.onClose = opts.onClose
    self.player = opts.player
    self.prestige = opts.prestige or (self.player and self.player.prestige) or 1
    self.vendorId = opts.vendor or "cafe"
    self.def = Vendor.get(self.vendorId) or {}
    self.title = self.def.name or opts.title or "The Cafe"

    self.titleFont = Theme.display(28)
    self.headFont = Theme.display(18)
    self.bodyFont = Theme.body(15)
    self.smallFont = Theme.body(13)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2


    self.vendorX = self.boxX + 24
    self.vendorY = self.boxY + 64
    self.vendorW = 260
    self.listLeft = self.vendorX + self.vendorW + 24
    self.listW = 300
    self.listTop = self.boxY + 96
    self.detailX = self.listLeft + self.listW + 24
    self.detailY = self.boxY + 96
    self.detailW = self.boxX + BOX_W - 24 - self.detailX

    self:refresh()
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

-- ---------------------------------------------------------------------------
-- The menu
-- ---------------------------------------------------------------------------

-- Rebuild the list. Called on open and after an order, so the held-meal banner and every row's refusal
-- reflect the counter as it stands rather than as it stood when the panel opened.
function Cafe:refresh()
    local selected = self.menu and self.menu.selected or 1
    local scroll = self.menu and self.menu.scroll or 0

    self.held = Meal.held(self.player)
    self.rows = {}
    for _, row in ipairs(Meal.menu(self.prestige)) do
        row.kind = "meal"
        self.rows[#self.rows + 1] = row
    end

    -- THE KITCHEN NO LONGER SETS BONES. A wounded body was mended here for gold, on a row appended
    -- after the dishes -- and a wound settled at a counter costs a decision once and nothing after, so
    -- the whole ladder in models/wound.lua never bit. Mending is a STAY at the Inn now: coin at the
    -- door, a day per wound, and the body out of the company while it takes them (models/gate.lua).

    local items = {}
    for i, row in ipairs(self.rows) do
        -- A dish the city has not grown into shows its rank instead of its price: naming a number you
        -- cannot pay says nothing, and naming the prestige it opens at says when to come back.
        local right = row.locked and ("prestige " .. (row.def.unlockPrestige or 1))
            or (row.def.price .. "g")
        local label = row.def.name .. "  -  " .. right
        items[#items + 1] = {
            label = label,
            action = function() self:order(self.rows[i]) end,
        }
    end

    self.menu = Menu.new(items, {
        buttonWidth = self.listW,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        startY = self.listTop,
        centerX = self.listLeft + self.listW / 2,
        font = self.bodyFont,
        maxVisible = MAX_VISIBLE,
    })
    self.menu.selected = math.min(selected, math.max(#items, 1))
    self.menu.scroll = scroll
    self.menu:scrollToSelection()
    self.menu:layout()
end

function Cafe:hasRows() return self.rows and #self.rows > 0 end

function Cafe:selectedRow()
    return self.rows and self.menu and self.rows[self.menu.selected]
end

function Cafe:setMsg(text, ok) self.message, self.messageOk = text, ok end

function Cafe:close()
    if self.onClose then self.onClose() end
end

-- ---------------------------------------------------------------------------
-- Ordering
-- ---------------------------------------------------------------------------

-- Ordering ASKS first, for the same reason buying at a shop does (ui/panels/shop.lua): on the pad and
-- the keyboard, confirm is the button that also walks the list, and a stray press here costs both the
-- gold AND the quest -- you cannot un-eat a meal to order the right one. The refusal is settled BEFORE
-- the question, so nobody is walked through a confirmation only to be told no at the end of it.
function Cafe:order(row)
    if not row then return end
    local why = Meal.blockReason(self.player, row.id, self.prestige)
    if why then
        Sound.play("ui.denied")
        self:setMsg(asSentence(why), false)
        return
    end
    self.confirm = Choice.new({
        title = "Order This?",
        prompt = row.def.name .. "  -  " .. row.def.price .. " gold",
        options = {
            { label = "Eat", accent = COURSE_COLOR,
                cb = function() self.confirm = nil; self:commit(row) end },
            { label = "Cancel", accent = { 0.78, 0.52, 0.50 },
                cb = function() self.confirm = nil end },
        },
        onClose = function() self.confirm = nil end,
    })
end

function Cafe:commit(row)
    local ok, why = Meal.eat(self.player, row.id, self.prestige)
    if not ok then
        Sound.play("ui.denied")
        self:setMsg(asSentence(why or "not today"), false)
        return
    end
    Player.save()
    Sound.play("ui.confirm")
    self:setMsg(row.def.name .. " -- the company eats. It lasts until the next quest is done.", true)
    self:refresh()
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function Cafe:update(dt)
    -- The confirmation owns the stick as well as the buttons while it is up: Menu:update reads the
    -- stick directly, so leaving it ticking would scroll the list under the question.
    if self.confirm then return end
    if self:hasRows() then self.menu:update(dt) end
end

function Cafe:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    VendorIcons.drawNamed(self.vendorId, self.title, self.titleFont, self.boxX, self.boxY + 18, BOX_W)

    self:drawVendor()
    if self:hasRows() then
        self.menu:draw()
        self:drawLockedOverlay()
        self:drawDetail()
    else
        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.muted)
        love.graphics.printf("The kitchen is cold.", self.listLeft, self.boxY + 200, self.listW, "center")
    end

    self:drawFooter()
    self.closeButton:draw()
    if self.confirm then self.confirm:draw() end
    love.graphics.setColor(1, 1, 1)
end

-- NO PORTRAIT PANE, and the slot is measured off its content rather than running to the foot of the
-- panel -- see the note in ui/panels/shop.lua, which this matches so two counters still look like two
-- counters. The Cafe's mark rides on its name in the header.
function Cafe:drawVendor()
    local x, y, w = self.vendorX, self.vendorY, self.vendorW

    local _, wrapped = self.smallFont:getWrap(self.def.description or "", w - 24)
    local h = 12 + 68 + #wrapped * self.smallFont:getHeight() + 12

    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", x, y, w, h, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", x, y, w, h, Theme.R, Theme.R)

    local ty = y + 12
    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.accentAmber)
    love.graphics.print((self.player and self.player.gold or 0) .. " gold", x + 12, ty)

    -- WHAT IS ON THE TABLE. The one-ration rule is invisible until it bites, so it is stated here in
    -- the fixed corner of the panel a player already reads for their purse -- not discovered by
    -- pressing a row and being refused.
    love.graphics.setFont(self.smallFont)
    if self.held then
        Theme.set(Theme.ink)
        love.graphics.printf("Eaten: " .. (self.held.name or "?"), x + 12, ty + 24, w - 24, "left")
        Theme.set(Theme.muted)
        love.graphics.printf("It lasts until this quest is done.", x + 12, ty + 42, w - 24, "left")
    else
        Theme.set(Theme.muted)
        love.graphics.printf("One meal each quest. Nobody has eaten yet.", x + 12, ty + 24, w - 24, "left")
    end
    love.graphics.printf(self.def.description or "", x + 12, ty + 68, w - 24, "left")
end

-- Menu has no disabled row, so the ones this player cannot order are greyed by painting over them --
-- the same overlay the shop's locked shelf rows wear, so "you can look but not buy" reads identically
-- on both counters. A row is dimmed for a rank it has not reached OR because the company has already
-- eaten: both are refusals, and the detail column says which.
function Cafe:drawLockedOverlay()
    for i, row in ipairs(self.rows) do
        local slot = self.menu.items[i]
        if slot and slot.x and (row.locked or self.held) then
            Theme.set(Theme.mount, self.held and 0.45 or 0.6)
            love.graphics.rectangle("fill", slot.x, slot.y, slot.w, slot.h, Theme.R, Theme.R)
        end
    end
end

function Cafe:drawDetail()
    local row = self:selectedRow()
    if not row then return end
    local def = row.def
    local x, y, w = self.detailX, self.detailY, self.detailW

    Theme.set(Theme.accentAmber)
    local ty = y + printWrapped(def.name or "?", self.headFont, x, y, w) + 8

    Theme.set(Theme.ink)
    ty = ty + printWrapped(def.description or "", self.bodyFont, x, ty, w) + 12


    -- THE COURSES: the flat half of the platter, worn by every member. Worded by the model
    -- (Meal.courses), so this column and any future readout cannot describe one platter two ways.
    local courses = Meal.courses(def)
    if #courses > 0 then
        Theme.set(Theme.muted)
        ty = ty + printWrapped("The whole company, all quest:", self.smallFont, x, ty, w) + 4
        love.graphics.setColor(COURSE_COLOR)
        for _, line in ipairs(courses) do
            ty = ty + printWrapped(line, self.bodyFont, x + 8, ty, w - 8) + 2
        end
        ty = ty + 10
    end

    -- THE KITCHEN SKILL: the half you are really buying on the expensive platters, so it gets the
    -- heading and the accent. Its wording comes off the trait blueprint itself (Meal.skill), which is
    -- the same text the battle's own glossary shows -- one rule, one sentence, everywhere.
    local skill = Meal.skill(def)
    if skill then
        Theme.set(Theme.muted)
        ty = ty + printWrapped("Kitchen skill", self.smallFont, x, ty, w) + 4
        Theme.set(Theme.accentAmber)
        ty = ty + printWrapped(skill.name, self.bodyFont, x, ty, w) + 2
        Theme.set(Theme.ink)
        ty = ty + printWrapped(skill.description or "", self.smallFont, x, ty, w) + 12
    end

    if def.flavor then
        ty = ty + (ItemTooltip.printFlavor(def.flavor, x, ty, w, self.smallFont) or 0)
    end

    -- The price, and -- when it will not sell -- why. The refusal lives here rather than on the row
    -- because it is usually not about the row at all: "you have already eaten" is a fact about the
    -- company, and stating it against one dish would read as that dish being unavailable.
    local footY = self.boxY + BOX_H - 96
    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(def.price .. " gold", x, footY, w, "left")
    local why = Meal.blockReason(self.player, row.id, self.prestige)
    if why then
        love.graphics.setColor(0.9, 0.6, 0.55)
        printWrapped(asSentence(why), self.smallFont, x, footY + 22, w)
    end
end

function Cafe:drawFooter()
    love.graphics.setFont(self.smallFont)
    if self.message then
        love.graphics.setColor(self.messageOk and 0.6 or 0.9, self.messageOk and 0.85 or 0.6,
            self.messageOk and 0.6 or 0.55)
        love.graphics.printf(self.message, self.boxX, self.boxY + BOX_H - 52, BOX_W, "center")
    end
    Theme.set(Theme.muted)
    local hint = InputMode.isGamepad()
        and "A: order    D-pad: scroll    B: close"
        or "Enter: order    Wheel: scroll    Esc: close"
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 30, BOX_W, "center")
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function Cafe:mousemoved(x, y)
    if self.confirm then self.confirm:mousemoved(x, y) return end
    self.closeButton:mousemoved(x, y)
    if self:hasRows() then self.menu:mousemoved(x, y) end
end

function Cafe:cursorKind(x, y)
    if self.confirm then return self.confirm:cursorKind(x, y) end
    if self.closeButton:contains(x, y) then return "hand" end
    if self:hasRows() and self.menu:mouseOverItem(x, y) then return "hand" end
    return "arrow"
end

function Cafe:wheelmoved(dx, dy)
    if self.confirm then return end -- the list must not scroll out from under the question
    if self:hasRows() then self.menu:wheelmoved(dx, dy) end
end

function Cafe:mousepressed(x, y, button)
    if self.confirm then self.confirm:mousepressed(x, y, button) return end
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end
    if self:hasRows() and self.menu:mouseOverItem(x, y) then
        self.menu:mousepressed(x, y, button)
        return
    end
    if not pointIn({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then self:close() end
end

function Cafe:keypressed(key)
    if self.confirm then self.confirm:keypressed(key) return end
    if key == "escape" then self:close()
    elseif self:hasRows() then self.menu:keypressed(key) end
end

function Cafe:gamepadpressed(joystick, button)
    if self.confirm then self.confirm:gamepadpressed(joystick, button) return end
    if button == "b" then self:close()
    elseif self:hasRows() then self.menu:gamepadpressed(joystick, button) end
end

return Cafe
