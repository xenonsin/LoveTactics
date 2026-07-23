-- Shop pop-up panel: a decluttered vendor screen with no member data on it. A prominent vendor
-- portrait sits on the left; the middle is a single Buy / Sell / Upgrade list; the right is a detail
-- pane for the highlighted row. It replaces the store half of the old unified Party screen (arranging
-- gear onto characters is the Armory's job, ui/panels/party.lua) and carries the ability-honing
-- feature that lived in the retired ui/panels/vendor.lua.
--
-- One list at a time means ONE focus zone, which is what makes this gamepad-friendly: D-pad moves the
-- row (the detail follows with no extra press), A buys/sells/upgrades it, the shoulder buttons cycle
-- Buy<->Sell<->Upgrade, B closes. No drag, no member targeting.
--
--   local panel = Shop.new({ vendor = "colosseum", player = p, onClose = fn })

local Menu = require("ui.menu")
local QuantityPopup = require("ui.quantity_popup")
local CloseButton = require("ui.close_button")
local ItemTooltip = require("ui.item_tooltip") -- for printFlavor: the sheared italic story line
local Vendor = require("models.vendor")
local Player = require("models.player")
local Item = require("models.item")
local Character = require("models.character")
local Discipline = require("models.discipline") -- unlockedSet: gates a shelf's locked discipline cut
local Combat = require("models.combat")
local Sprite = require("models.sprite")
local Scale = require("scale")
local InputMode = require("input_mode")

local Shop = {}
Shop.__index = Shop

local BOX_W, BOX_H = 1000, 580
local ROW_H, ROW_SPACING, MAX_VISIBLE = 38, 6, 9

local MODES = { "buy", "sell", "upgrade" }
local MODE_LABEL = { buy = "Buy", sell = "Sell", upgrade = "Upgrade" }

-- Detail accent per item type (matches ui/item_tooltip.lua).
local TYPE_COLOR = {
    weapon = { 0.90, 0.58, 0.48 },
    armor = { 0.58, 0.72, 0.92 },
    consumable = { 0.52, 0.85, 0.55 },
    ability = { 0.78, 0.62, 0.96 },
    utility = { 0.92, 0.82, 0.52 },
}
local DEFAULT_COLOR = { 0.85, 0.85, 0.9 }

-- Placeholder tint for a missing vendor portrait, keyed by the vendor's deadly sin.
local SIN_COLOR = {
    wrath = { 0.52, 0.22, 0.22 }, gluttony = { 0.30, 0.44, 0.26 }, greed = { 0.50, 0.42, 0.18 },
    sloth = { 0.28, 0.34, 0.46 }, envy = { 0.22, 0.44, 0.38 }, lust = { 0.46, 0.26, 0.44 },
    pride = { 0.40, 0.28, 0.52 },
}
local SIN_DEFAULT = { 0.26, 0.28, 0.36 }

local TARGET_LABEL = { enemy = "Enemy", ally = "Ally", self = "Self", tile = "Tile" }

local function pointIn(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function Shop.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Shop)
    self.onClose = opts.onClose
    self.player = opts.player
    self.vendorId = opts.vendor
    self.def = Vendor.get(self.vendorId) or {}
    self.title = self.def.name or opts.title or "Shop"
    self.mode = "buy"

    self.titleFont = love.graphics.newFont(28)
    self.headFont = love.graphics.newFont(18)
    self.bodyFont = love.graphics.newFont(15)
    self.smallFont = love.graphics.newFont(13)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    self.vendorSprite = self.def.sprite and Sprite.load(self.def.sprite) or nil

    -- Columns: vendor (left) | list (middle) | detail (right).
    self.vendorX = self.boxX + 24
    self.vendorY = self.boxY + 64
    self.vendorW = 260
    self.listLeft = self.vendorX + self.vendorW + 24
    self.listW = 300
    self.detailX = self.listLeft + self.listW + 24
    self.detailY = self.boxY + 112
    self.detailW = self.boxX + BOX_W - 24 - self.detailX

    -- Mode selector segments above the list.
    self.modeY = self.boxY + 66
    self.modeH = 30
    self.segRects = {}
    local segW = self.listW / #MODES
    for i, m in ipairs(MODES) do
        self.segRects[m] = { x = self.listLeft + (i - 1) * segW, y = self.modeY, w = segW, h = self.modeH }
    end

    self:refresh()
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

-- Owned items this vendor hones PER INSTANCE (Vendor.canUpgradeHere: abilities of its class --
-- consumables refine per-type instead, see the recipe rows in refresh), with where each lives so an
-- upgrade can swap it back in place: a roster member's grid cell, or a stash slot.
function Shop:collectUpgrades()
    local out = {}
    for _, char in ipairs(self.player.roster or {}) do
        for cell = 1, Character.MAX_INVENTORY do
            local item = char.inventory[cell]
            if item and Vendor.canUpgradeHere(self.vendorId, item) then
                out[#out + 1] = { item = item, where = char.name or "?",
                    loc = { kind = "grid", char = char, cell = cell } }
            end
        end
    end
    for i, item in ipairs(self.player.stash or {}) do
        if Vendor.canUpgradeHere(self.vendorId, item) then
            out[#out + 1] = { item = item, where = "Stash", loc = { kind = "stash", index = i } }
        end
    end
    return out
end

-- Rebuild self.rows + the Menu for the current mode. Called on open, on mode switch, and after every
-- transaction so a rank-up / spent gold / changed stash is reflected without reopening.
function Shop:refresh()
    local selected = self.menu and self.menu.selected or 1
    self.rank = Player.repRank(self.player, self.vendorId)
    self.rows = {}

    if self.mode == "buy" then
        for _, entry in ipairs(Vendor.stock(self.vendorId, self.rank, self.player.recipes, Discipline.unlockedSet(self.player))) do
            -- Instantiate at the item's recipe tier, so its name (+n) and stats reflect what's bought.
            local item = Item.instantiate(entry.id, nil, entry.level)
            self.rows[#self.rows + 1] = {
                item = item, entry = entry,
                label = item.name .. "  -  " .. (entry.locked and "locked" or (entry.price .. "g")),
                locked = entry.locked,
            }
        end
    elseif self.mode == "sell" then
        for i, item in ipairs(self.player.stash or {}) do
            local value = Vendor.sellValue(item)
            local qty = (item.quantity or 1) > 1 and ("  x" .. item.quantity) or ""
            self.rows[#self.rows + 1] = {
                item = item, index = i, value = value,
                label = (item.name or "?") .. "  -  " .. (value > 0 and (value .. "g") or "--") .. qty,
                locked = value <= 0,
            }
        end
    else -- upgrade
        -- Consumable recipe tiers: this vendor's own consumable shelf, refined per-type. Upgrading one
        -- raises the tier every future purchase comes at (Vendor.upgradeRecipe / Player.recipeLevel).
        for _, entry in ipairs(Vendor.stock(self.vendorId, self.rank, self.player.recipes, Discipline.unlockedSet(self.player))) do
            local sample = entry.type == "consumable" and Item.instantiate(entry.id, nil, entry.level)
            -- Only the bench that refines a consumable lists it: the Market resells potions but hones
            -- none, so a resold potion never shows here (Vendor.canRefineHere).
            if sample and Vendor.canRefineHere(self.vendorId, sample) then
                local cost = Vendor.recipeUpgradeCost(entry.level, self.rank)
                local tail = cost and (cost.locked and "locked" or (cost.gold .. "g")) or "max"
                self.rows[#self.rows + 1] = {
                    kind = "recipe", id = entry.id, item = sample, cost = cost,
                    label = sample.name .. "  -  " .. tail,
                    locked = (cost == nil) or cost.locked,
                }
            end
        end
        -- Ability instances, honed per-item (Vendor.canUpgradeHere excludes consumables).
        for _, up in ipairs(self:collectUpgrades()) do
            local cost = Vendor.abilityUpgradeCost(up.item, self.rank)
            local tail = cost and (cost.locked and "locked" or (cost.gold .. "g")) or "max"
            self.rows[#self.rows + 1] = {
                kind = "instance", item = up.item, up = up, cost = cost,
                label = up.item.name .. " (" .. up.where .. ")  -  " .. tail,
                locked = (cost == nil) or cost.locked,
            }
        end
    end

    local items = {}
    for i, row in ipairs(self.rows) do
        items[#items + 1] = { label = row.label, action = function() self:activateRow(self.rows[i]) end }
    end
    self.menu = Menu.new(items, {
        buttonWidth = self.listW,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        startY = self.boxY + 112,
        centerX = self.listLeft + self.listW / 2,
        font = self.bodyFont,
        maxVisible = MAX_VISIBLE,
    })
    self.menu.selected = math.min(selected, math.max(#items, 1))
    self.menu:scrollToSelection()
    -- Compute row rects now so the first draw/click works before the first update() tick.
    self.menu:layout()
end

function Shop:hasRows() return self.rows and #self.rows > 0 end

function Shop:setMode(mode)
    self.mode = mode
    self.menu = nil
    self:refresh()
end

function Shop:cycleMode(delta)
    local idx = 1
    for i, m in ipairs(MODES) do if m == self.mode then idx = i end end
    self:setMode(MODES[(idx - 1 + delta) % #MODES + 1])
end

function Shop:setMsg(text, ok) self.message, self.messageOk = text, ok end

function Shop:close()
    if self.onClose then self.onClose() end
end

-- ---------------------------------------------------------------------------
-- Transactions
-- ---------------------------------------------------------------------------

function Shop:activateRow(row)
    if not row then return end
    if self.mode == "buy" then self:buy(row)
    elseif self.mode == "sell" then self:sell(row)
    else self:upgrade(row) end
end

function Shop:buy(row)
    local entry = row.entry
    if entry.locked then
        self:setMsg("Requires " .. Vendor.rankName(self.vendorId, entry.repRank) .. " standing.", false)
        return
    end
    if not Player.spendGold(self.player, entry.price) then
        self:setMsg("Not enough gold.", false)
        return
    end
    local item = Item.instantiate(entry.id, nil, entry.level)
    Player.addToStash(self.player, item)
    Player.save()
    self:setMsg(item.name .. " bought. It is in your stash.", true)
    self:refresh()
end

function Shop:sell(row)
    local item = row.item
    local value = Vendor.sellValue(item)
    if value <= 0 then
        self:setMsg((item.name or "That") .. " can't be sold here.", false)
        return
    end
    if Item.isStackable(item) and (item.quantity or 1) > 1 then
        self.quantityPopup = QuantityPopup.new({
            max = item.quantity, value = item.quantity,
            title = "Sell how many?", label = item.name,
            onConfirm = function(n) self.quantityPopup = nil; self:commitSell(item, value, n) end,
            onCancel = function() self.quantityPopup = nil end,
        })
        return
    end
    self:commitSell(item, value, 1)
end

function Shop:commitSell(item, value, n)
    n = math.max(1, math.min(n, item.quantity or 1))
    item.quantity = (item.quantity or 1) - n
    if item.quantity <= 0 then
        for i, it in ipairs(self.player.stash or {}) do
            if it == item then Player.takeFromStash(self.player, i) break end
        end
    end
    Player.addGold(self.player, value * n)
    Player.save()
    self:setMsg("Sold " .. n .. "x " .. (item.name or "item") .. " for " .. (value * n) .. "g.", true)
    self:refresh()
end

function Shop:upgrade(row)
    if row.kind == "recipe" then
        local level, reason = Vendor.upgradeRecipe(self.player, self.vendorId, row.id)
        if not level then
            self:setMsg((reason == "gold" and "Not enough gold.")
                or (reason == "locked" and "Needs higher standing to refine further.")
                or (reason == "max level" and (row.item.name .. " is at its highest tier."))
                or "It cannot be refined here.", false)
            return
        end
        Player.save()
        self:setMsg(row.item.name .. " recipe refined to +" .. level .. ".", true)
        self:refresh()
        return
    end

    local up = row.up
    local newItem, reason = Vendor.upgradeAbility(self.player, self.vendorId, up.item)
    if not newItem then
        self:setMsg((reason == "gold" and "Not enough gold.")
            or (reason == "locked" and "Needs higher standing to upgrade further.")
            or (reason == "max level" and (up.item.name .. " is at maximum level."))
            or "It cannot be upgraded here.", false)
        return
    end
    if up.loc.kind == "grid" then
        up.loc.char.inventory[up.loc.cell] = newItem
    else
        self.player.stash[up.loc.index] = newItem
    end
    Player.save()
    self:setMsg(newItem.name .. " honed.", true)
    self:refresh()
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function Shop:update(dt)
    if self.quantityPopup then self.quantityPopup:update(dt) return end
    if self:hasRows() then self.menu:update(dt) end
end

function Shop:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)
    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(self.title, self.boxX, self.boxY + 18, BOX_W, "center")

    self:drawVendor()
    self:drawModeSelector()
    if self:hasRows() then
        self.menu:draw()
        self:drawLockedOverlay()
        self:drawDetail()
    else
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.6, 0.63, 0.72)
        local empty = (self.mode == "buy" and "Nothing for sale.")
            or (self.mode == "sell" and "Your stash is empty.") or "Nothing to upgrade here."
        love.graphics.printf(empty, self.listLeft, self.boxY + 200, self.listW, "center")
    end

    self:drawFooter()
    self.closeButton:draw()
    if self.quantityPopup then self.quantityPopup:draw() end
    love.graphics.setColor(1, 1, 1)
end

function Shop:drawVendor()
    local x, y, w = self.vendorX, self.vendorY, self.vendorW
    local h = self.boxY + BOX_H - 44 - y
    love.graphics.setColor(0.09, 0.10, 0.14)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    love.graphics.setColor(0.4, 0.44, 0.55)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)

    local portraitH = h - 92
    local pad = 12
    local px, py, pw, ph = x + pad, y + pad, w - pad * 2, portraitH - pad * 2
    if type(self.vendorSprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = self.vendorSprite:getDimensions()
        local scale = math.min(pw / sw, ph / sh)
        love.graphics.draw(self.vendorSprite, px + pw / 2, py + ph / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        local tint = SIN_COLOR[self.def.sin] or SIN_DEFAULT
        love.graphics.setColor(tint[1], tint[2], tint[3])
        love.graphics.rectangle("fill", px, py, pw, ph, 8, 8)
        love.graphics.setFont(self.titleFont)
        love.graphics.setColor(0.92, 0.93, 0.97)
        love.graphics.printf((self.def.name or "?"):sub(1, 1), px, py + ph / 2 - 20, pw, "center")
    end

    local ty = y + portraitH + 2
    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.print(self.player.gold .. " gold", x + 12, ty)
    love.graphics.setColor(0.7, 0.78, 0.9)
    local rep = Player.reputation(self.player, self.vendorId)
    local standing = Vendor.rankName(self.vendorId, self.rank)
    local toNext, nextRank = Vendor.nextRank(self.vendorId, rep)
    if toNext then
        standing = standing .. "  (" .. toNext .. " to " .. Vendor.rankName(self.vendorId, nextRank) .. ")"
    end
    love.graphics.printf(standing, x + 12, ty + 22, w - 24, "left")
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.6, 0.63, 0.72)
    love.graphics.printf(self.def.description or "", x + 12, ty + 44, w - 24, "left")
end

function Shop:drawModeSelector()
    love.graphics.setFont(self.bodyFont)
    for _, m in ipairs(MODES) do
        local r = self.segRects[m]
        local active = (self.mode == m)
        love.graphics.setColor(active and 0.32 or 0.18, active and 0.36 or 0.2, active and 0.48 or 0.26)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
        love.graphics.setColor(active and 0.6 or 0.4, active and 0.72 or 0.44, active and 0.9 or 0.54)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
        love.graphics.setColor(active and 0.95 or 0.7, active and 0.9 or 0.72, active and 0.6 or 0.78)
        love.graphics.printf(MODE_LABEL[m], r.x, r.y + r.h / 2 - 10, r.w, "center")
    end
end

-- Menu has no disabled row, so grey the locked/unsellable/maxed ones by painting over them.
function Shop:drawLockedOverlay()
    for i, row in ipairs(self.rows) do
        local slot = self.menu.items[i]
        if row.locked and slot and slot.x then
            love.graphics.setColor(0.12, 0.13, 0.18, 0.6)
            love.graphics.rectangle("fill", slot.x, slot.y, slot.w, slot.h, 8, 8)
        end
    end
end

function Shop:drawDetail()
    local row = self.rows[self.menu.selected]
    if not row then return end
    local item = row.item
    local x, y, w = self.detailX, self.detailY, self.detailW
    local accent = TYPE_COLOR[item.type] or DEFAULT_COLOR

    love.graphics.setFont(self.headFont)
    love.graphics.setColor(accent[1], accent[2], accent[3])
    love.graphics.printf(item.name or "?", x, y, w, "left")
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.6, 0.63, 0.72)
    love.graphics.printf((item.type or "item"):upper(), x, y + 26, w, "left")

    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.8, 0.82, 0.88)
    local desc = item.description or ""
    love.graphics.printf(desc, x, y + 48, w, "left")

    -- The story line rides under the description, in the gap ahead of the stat block below.
    if item.flavor and item.flavor ~= "" then
        local _, descLines = self.bodyFont:getWrap(desc, w)
        local descH = #descLines * self.bodyFont:getHeight()
        ItemTooltip.printFlavor(item.flavor, x, y + 48 + descH + 6, w, self.bodyFont)
    end

    -- Quick stats. The item's primary stat -- the one magnitude that defines it (armor's defense, a
    -- blade's Power), quoted at its current level -- leads the block for ANY item, armor included.
    local sy = y + 130
    love.graphics.setFont(self.smallFont)
    local function statLine(label, value, valueColor)
        love.graphics.setColor(0.6, 0.64, 0.72)
        love.graphics.print(label, x, sy)
        local vc = valueColor or { 0.9, 0.91, 0.96 }
        love.graphics.setColor(vc[1], vc[2], vc[3])
        love.graphics.printf(value, x, sy, w, "right")
        sy = sy + 20
    end
    local ab = item.activeAbility
    -- A dry-run against a zero-stat caster surfaces a healing ability's restored amount by the Power.
    local out = ab and Combat.abilityOutput(nil, item)
    local primaryValue, primaryLabel = Item.primaryStat(item)
    if primaryValue then statLine(primaryLabel, tostring(primaryValue), { 0.95, 0.72, 0.48 }) end
    if out and out.heal > 0 then statLine("Heal", "+" .. out.heal, { 0.55, 0.90, 0.58 }) end
    if ab then
        if ab.target then statLine("Target", TARGET_LABEL[ab.target] or ab.target) end
        statLine("Range", tostring(ab.range or 1))
        if ab.speed then statLine("Speed", tostring(ab.speed)) end
        -- One line however many pools it draws on: the shelf is comparing weapons, not budgeting a
        -- turn, so "4 mana + 5 stamina" is the useful shape here (the in-battle tooltip splits them).
        local costs = Item.costs(ab)
        if #costs > 0 then
            local parts = {}
            for _, c in ipairs(costs) do parts[#parts + 1] = c.amount .. " " .. c.stat end
            statLine("Cost", table.concat(parts, " + "))
        end
    end

    -- The transaction line for this mode.
    love.graphics.setFont(self.bodyFont)
    local ty = self.boxY + BOX_H - 96
    if self.mode == "buy" then
        if row.entry.locked then
            love.graphics.setColor(0.9, 0.6, 0.55)
            love.graphics.printf("Locked: needs " .. Vendor.rankName(self.vendorId, row.entry.repRank),
                x, ty, w, "left")
        else
            love.graphics.setColor(0.95, 0.85, 0.55)
            love.graphics.printf("Price: " .. row.entry.price .. " gold", x, ty, w, "left")
        end
    elseif self.mode == "sell" then
        if row.value > 0 then
            love.graphics.setColor(0.7, 0.85, 0.7)
            love.graphics.printf("Sell value: " .. row.value .. " gold each", x, ty, w, "left")
        else
            love.graphics.setColor(0.9, 0.6, 0.55)
            love.graphics.printf("Cannot be sold here.", x, ty, w, "left")
        end
    else
        local cost = row.cost
        if not cost then
            love.graphics.setColor(0.7, 0.85, 0.7)
            love.graphics.printf("At maximum level.", x, ty, w, "left")
        elseif cost.locked then
            love.graphics.setColor(0.9, 0.6, 0.55)
            love.graphics.printf("Locked: needs higher standing for +" .. cost.level, x, ty, w, "left")
        else
            love.graphics.setColor(0.95, 0.85, 0.55)
            love.graphics.printf("Upgrade to +" .. cost.level .. ": " .. cost.gold .. " gold", x, ty, w, "left")
        end
    end
end

function Shop:drawFooter()
    love.graphics.setFont(self.smallFont)
    if self.message then
        love.graphics.setColor(self.messageOk and 0.6 or 0.9, self.messageOk and 0.85 or 0.6,
            self.messageOk and 0.6 or 0.55)
        love.graphics.printf(self.message, self.boxX, self.boxY + BOX_H - 52, BOX_W, "center")
    end
    love.graphics.setColor(0.55, 0.6, 0.7)
    -- Show the glyphs for the device last used: pad buttons only in gamepad mode, keyboard/mouse otherwise.
    local hint = InputMode.isGamepad()
        and "A: confirm    LB/RB: Buy/Sell/Upgrade    D-pad: scroll    B: close"
        or "Enter: confirm    Tab: Buy/Sell/Upgrade    Wheel: scroll    Esc: close"
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 30, BOX_W, "center")
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function Shop:mousemoved(x, y)
    if self.quantityPopup then self.quantityPopup:mousemoved(x, y) return end
    self.closeButton:mousemoved(x, y)
    if self:hasRows() then self.menu:mousemoved(x, y) end
end

-- Hand over the close X, the Buy/Sell/Upgrade mode tabs, or any item row; arrow elsewhere. When the
-- sell-quantity popup is open it owns the pointer. See ui/cursor.lua.
function Shop:cursorKind(x, y)
    if self.quantityPopup then return self.quantityPopup:cursorKind(x, y) end
    if self.closeButton:contains(x, y) then return "hand" end
    for _, m in ipairs(MODES) do
        if pointIn(self.segRects[m], x, y) then return "hand" end
    end
    if self:hasRows() and self.menu:mouseOverItem(x, y) then return "hand" end
    return "arrow"
end

function Shop:wheelmoved(dx, dy)
    if self.quantityPopup then self.quantityPopup:wheelmoved(dy) return end
    if self:hasRows() then self.menu:wheelmoved(dx, dy) end
end

function Shop:mousepressed(x, y, button)
    if self.quantityPopup then self.quantityPopup:mousepressed(x, y, button) return end
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end
    for _, m in ipairs(MODES) do
        if pointIn(self.segRects[m], x, y) then self:setMode(m) return end
    end
    if self:hasRows() then
        self.menu:mousepressed(x, y, button)
        -- Keep the detail/selection in sync even if the click missed a row.
        return
    end
    if not pointIn({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then self:close() end
end

function Shop:keypressed(key)
    if self.quantityPopup then self.quantityPopup:keypressed(key) return end
    if key == "escape" then self:close()
    elseif key == "tab" then self:cycleMode(1)
    elseif key == "left" or key == "a" then self:cycleMode(-1)
    elseif key == "right" or key == "d" then self:cycleMode(1)
    elseif self:hasRows() then self.menu:keypressed(key) end
end

function Shop:gamepadpressed(joystick, button)
    if self.quantityPopup then self.quantityPopup:gamepadpressed(joystick, button) return end
    if button == "b" then self:close()
    elseif button == "leftshoulder" then self:cycleMode(-1)
    elseif button == "rightshoulder" then self:cycleMode(1)
    elseif self:hasRows() then self.menu:gamepadpressed(joystick, button) end
end

return Shop
