-- The Merchant: a wandering market on the trail (states/game.lua's openEncounter routes a `merchant`
-- cell here). It offers a small, fixed shelf of ordinary GOODS -- the priced gear and supplies the road
-- deals in (models/spoils.lua's Spoils.shelf) -- for SCRIP, the run's own coin, so what a company
-- forages or skims finally has somewhere to go ON the map instead of three menus later at the hub. Buy
-- what you can afford; leave the rest. Modeled on ui/panels/rest_choice.lua: a state owns it as
-- game.activePanel and forwards input; three-input + mouse-only.
--
--   Merchant.new({ title=, stock={ {id, price}, ... }, gold=fn, unit=, suffix=,
--                  onBuy=fn(entry)->bool, onClose= })
--
-- IT TOOK GOLD UNTIL THE ECONOMY SPLIT, and that is why the purse accessor is still called `gold`: the
-- panel does not know or care which purse is behind the function, and renaming the field would have
-- been a change to four call sites to record a fact none of them act on. What it does know is what to
-- CALL the coin, which is `unit` and `suffix` -- because the player has two of them now and a counter
-- that does not say which one it takes is a counter that will be paid in the wrong one.
--
-- The caller passes ids and prices; the panel instantiates a DISPLAY copy of each (Item.instantiate)
-- for its icon, its type line and its tooltip, exactly as ui/panels/loot_reveal.lua does. It never
-- grants anything -- the real spend + grant happen in the caller's onBuy (returning true on success) --
-- so a shelf redrawn every frame can no more mint an item than a chest reveal can.
--
-- Every row carries its full item tooltip (ui/item_tooltip.lua), pinned beside the FOCUSED row rather
-- than hung off the cursor. Buying a weapon sight unseen is the one thing a shop must never ask, and
-- the road's shop has no detail column to dock the reading in: the tooltip is the whole of what this
-- panel can say about a piece, and the keyboard and the pad reach it by moving the focus, same as the
-- mouse does by hovering.

local CloseButton = require("ui.close_button")
local DebugMenu = require("ui.panels.debug_menu") -- the right-click item menu (development builds only)
local GlossaryPanel = require("ui.glossary_panel") -- only for WIDTH: the room the aside needs beside the tooltip
local InputMode = require("input_mode")
local ItemTooltip = require("ui.item_tooltip")
local Item = require("models.item")
local RelicCard = require("ui.relic_card") -- a relic row's colour, chip and dwell surface
local Scale = require("scale")
local Theme = require("ui.theme")

local Merchant = {}
Merchant.__index = Merchant

local BOX_W = 500
local PAD = 24
local ROW_H = 64
local ROW_GAP = 10
local ICON = 34 -- the item's art (or its letter plate) at the head of a row

-- The room the reading takes to the RIGHT of the box: the tooltip's own cursor offset, the tooltip, and
-- the glossary column that opens beside it. Reserved whether or not the focused ware has definitions to
-- show, so moving the focus can never slide the shelf sideways under the player's hand.
local TIP_GAP = 14 -- ItemTooltip.draw's own offset from the anchor it is handed
local READING_W = TIP_GAP + ItemTooltip.WIDTH + 8 + GlossaryPanel.WIDTH

local GOLD = { 0.90, 0.78, 0.36 }

-- Accent per item type, the same five the shop shelf and the item tooltip wear -- a weapon reads the
-- same red on the road as it does in town.
local TYPE_COLOR = {
    weapon = { 0.789, 0.361, 0.354 },
    armor = { 0.391, 0.549, 0.812 },
    consumable = { 0.361, 0.671, 0.480 },
    ability = { 0.568, 0.414, 0.786 },
    utility = { 0.865, 0.707, 0.341 },
}
local DEFAULT_COLOR = { 0.85, 0.85, 0.90 }

local function inRect(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

-- What a row says under the item's name: what the thing IS, and which house's rack it came off. A
-- classless good (a traveler's supply no sin claims) shows its type alone rather than a dangling dot.
local function tagLine(item)
    local type_ = (item.type or "item"):upper()
    local class = Item.classDisplayName(item.class)
    return class and (type_ .. " · " .. class:upper()) or type_
end

function Merchant.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Merchant)
    self.title = opts.title or "Merchant"
    self.stock = opts.stock or {}
    self.gold = opts.gold or function() return 0 end
    -- WHICH COIN THIS COUNTER TAKES, as a word and as the mark a price wears. The road's Merchant is
    -- paid in scrip now (models/scrip.lua) and the panel is not -- it is a shelf with a purse behind it,
    -- and which purse is the caller's business. Defaults to gold so any other counter built on this
    -- widget keeps the wording it had.
    self.unit = opts.unit or "gold"
    self.suffix = opts.suffix or "g"
    self.onBuy = opts.onBuy
    self.onClose = opts.onClose
    self.finished = false
    self.focus = 1

    self.titleFont = Theme.display(28)
    self.goldFont = Theme.body(15)
    self.nameFont = Theme.display(18)
    self.tagFont = Theme.body(11)
    self.priceFont = Theme.body(16)
    self.hintFont = Theme.body(13)

    self.boxW = BOX_W
    self.boxH = 96 + math.max(1, #self.stock) * (ROW_H + ROW_GAP) + 20
    -- The shelf and the reading beside it are ONE composition, so the box is not centred on its own: it
    -- sits far enough left that the focused row's tooltip lands clear of the panel instead of over the
    -- prices. A shelf with nothing on it has nothing to read, and centres.
    self.boxX = (#self.stock > 0)
        and math.max(24, (Scale.WIDTH - (BOX_W + READING_W)) / 2)
        or (Scale.WIDTH / 2 - BOX_W / 2)
    self.boxY = Scale.HEIGHT / 2 - self.boxH / 2
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    for i, entry in ipairs(self.stock) do
        -- A RELIC ROW carries its own info and never touches Item: it is not an item, has no icon and
        -- no type line, and its reading is RelicCard.tooltip rather than ItemTooltip. The branch is
        -- here and at the four draw points below; everything else about a row is shared.
        if not entry.relic then
            entry.item = entry.item or Item.instantiate(entry.id) -- display copy: icon, type line, tooltip
        end
        entry.rect = {
            x = self.boxX + PAD, y = self.boxY + 84 + (i - 1) * (ROW_H + ROW_GAP),
            w = BOX_W - PAD * 2, h = ROW_H,
        }
    end
    return self
end

function Merchant:buy(i)
    local entry = self.stock[i]
    if not entry or entry.bought then return end
    if self.gold() < (entry.price or 0) then return end -- can't afford: inert
    if self.onBuy and self.onBuy(entry) then entry.bought = true end
end

function Merchant:close()
    if self.finished then return end
    self.finished = true
    self.itemDebug = nil -- a context menu never outlives the panel it was opened over
    if self.onClose then self.onClose() end
end

-- The item's art at the head of a row, or -- while the art is still outstanding (models/sprite.lua
-- hands back the path string) -- a plate carrying its initial, the same fallback the loot reveal uses.
function Merchant:drawIcon(item, x, y, accent, dim)
    local sprite = item.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(dim, dim, dim, 1)
        local iw, ih = sprite:getDimensions()
        local scale = math.min(ICON / iw, ICON / ih)
        love.graphics.draw(sprite, x + ICON / 2, y + ICON / 2, 0, scale, scale, iw / 2, ih / 2)
        return
    end
    love.graphics.setColor(accent[1] * 0.30 * dim, accent[2] * 0.30 * dim, accent[3] * 0.30 * dim, 1)
    love.graphics.rectangle("fill", x, y, ICON, ICON, 5, 5)
    love.graphics.setColor(accent[1] * dim, accent[2] * dim, accent[3] * dim, 0.9)
    love.graphics.rectangle("line", x, y, ICON, ICON, 5, 5)
    love.graphics.setFont(self.nameFont)
    love.graphics.printf((item.name or "?"):sub(1, 1), x, y + ICON / 2 - self.nameFont:getHeight() / 2,
        ICON, "center")
end

function Merchant:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local bx, by = self.boxX, self.boxY
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, bx, by + 18, self.boxW, "center")

    love.graphics.setFont(self.goldFont)
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 1)
    love.graphics.printf("Your " .. self.unit .. ": " .. self.gold(),
        bx, by + 54, self.boxW - PAD, "right")

    local myGold = self.gold()
    for i, entry in ipairs(self.stock) do
        local r = entry.rect
        local item = entry.item
        local relic = entry.relic
        local accent = relic and RelicCard.accentOf(relic) or (TYPE_COLOR[item.type] or DEFAULT_COLOR)
        local focused = (i == self.focus)
        local afford = not entry.bought and myGold >= (entry.price or 0)

        love.graphics.setColor(0.12, 0.13, 0.16, (focused and not entry.bought) and 0.95 or 0.55)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 7, 7)
        love.graphics.setColor(accent[1], accent[2], accent[3], entry.bought and 0.25 or (focused and 1 or 0.4))
        love.graphics.setLineWidth(focused and not entry.bought and 2 or 1)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 7, 7)
        love.graphics.setLineWidth(1)

        local dim = entry.bought and 0.45 or 1
        if relic then
            RelicCard.chip(r.x + 12, r.y + r.h / 2 - ICON / 2, ICON, relic, entry.held, { dim = dim })
        else
            self:drawIcon(item, r.x + 12, r.y + r.h / 2 - ICON / 2, accent, dim)
        end

        -- A long name steps down a size rather than running under the price (never a scale factor on a
        -- font -- Theme.fitText swaps the face, since a scaled one blurs).
        local nameX = r.x + 12 + ICON + 12
        local label = relic and (relic.name or entry.id) or (item.name or entry.id)
        local nameFont, name = Theme.fitText(Theme.display, label, r.w - (nameX - r.x) - 90, 18, 14)
        love.graphics.setFont(nameFont)
        love.graphics.setColor(0.95 * dim, 0.94 * dim, 0.9 * dim, 1)
        love.graphics.print(name, nameX, r.y + 10)

        -- The under-line: a ware says what it IS and whose rack it came off; a relic says its rung, and
        -- how many the company already holds, because a duplicate DEEPENS what you carry and that is the
        -- one other fact that changes the purchase.
        love.graphics.setFont(self.tagFont)
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.85 * dim)
        local tag
        if relic then
            tag = "Relic  -  " .. (relic.tier or "common")
            if (entry.held or 0) > 0 then tag = tag .. "  -  held x" .. entry.held end
        else
            tag = tagLine(item)
        end
        love.graphics.print(tag, nameX, r.y + 38)

        -- Price / state, right-aligned.
        love.graphics.setFont(self.priceFont)
        local label, col
        if entry.bought then label, col = "Bought", { 0.55, 0.58, 0.62 }
        elseif not afford then label, col = (entry.price or 0) .. self.suffix, { 0.7, 0.45, 0.42 }
        else label, col = (entry.price or 0) .. self.suffix, GOLD end
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.printf(label, r.x, r.y + r.h / 2 - self.priceFont:getHeight() / 2, r.w - 16, "right")
    end

    local hint = InputMode.isGamepad() and "D-pad move  -  A buy  -  B leave"
        or "Arrows move  -  Enter buy  -  Esc leave"
    love.graphics.setFont(self.hintFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.printf(hint, bx, by + self.boxH - 22, self.boxW, "center")

    self.closeButton:draw()

    -- What the focused row actually IS, last so it sits over everything. Anchored past the box's right
    -- edge, level with the row it reads: the shelf inspects one row at a time whichever input is
    -- driving, and a box that followed the mouse would read differently for the pad than for the hand.
    local entry = self.stock[self.focus]
    if entry and not self.itemDebug then
        if entry.relic then
            -- The relic's own dwell surface (ui/relic_card.lua), which is the same one the overworld
            -- tray draws -- so a relic held twice reads the same on the shelf as it does in the tray.
            -- Read at `held + 1`: a shelf quotes the stack BUYING would leave you on, which is what the
            -- Reliquary's cards already do -- and on the ordinary row, where nothing is held yet, it is
            -- the difference between "+2 damage and skill" and a literal "%d".
            RelicCard.tooltip(bx + self.boxW + TIP_GAP, entry.rect.y - 8, entry.relic, entry.held,
                { at = (entry.held or 0) + 1 })
        else
            ItemTooltip.draw(entry.item, bx + self.boxW, entry.rect.y - 24, Scale.WIDTH)
        end
    end
    if self.itemDebug then self.itemDebug:draw() end -- modal over the shelf, and over the reading
    love.graphics.setColor(1, 1, 1)
end

-- Open the debug context menu on the ware under the pointer (development builds only). Returns true
-- when one opened. A BOUGHT row counts: the blueprint is the same one either way, and it is a reading,
-- not a purchase. The panel holds display copies rather than the granted item, so a reload re-stamps
-- what the shelf is drawing and nothing the player owns -- which is the right half to touch here.
function Merchant:openItemDebug(x, y)
    for _, entry in ipairs(self.stock) do
        -- A relic row has no item behind it, and the debug menu is an ITEM inspector -- so a right-click
        -- on one is simply not a gesture rather than a nil handed to DebugMenu.forItem.
        if not entry.relic and inRect(entry.rect, x, y) then
            local menu = DebugMenu.forItem({
                x = x, y = y,
                item = entry.item,
                onClose = function() self.itemDebug = nil end,
            })
            if not menu then return false end
            self.itemDebug = menu
            return true
        end
    end
    return false
end

function Merchant:mousemoved(x, y)
    if self.itemDebug then self.itemDebug:mousemoved(x, y) return end
    self.closeButton:mousemoved(x, y)
    for i, entry in ipairs(self.stock) do
        if inRect(entry.rect, x, y) then self.focus = i; break end
    end
end

function Merchant:cursorKind(x, y)
    if self.itemDebug then return self.itemDebug:cursorKind(x, y) end
    if self.closeButton:contains(x, y) then return "hand" end
    for _, entry in ipairs(self.stock) do if inRect(entry.rect, x, y) then return "hand" end end
    return "arrow"
end

function Merchant:mousepressed(x, y, button)
    if self.itemDebug then self.itemDebug:mousepressed(x, y, button) return end
    if button == 2 then self:openItemDebug(x, y) return end
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close(); return end
    for i, entry in ipairs(self.stock) do
        if inRect(entry.rect, x, y) then self:buy(i); return end
    end
end

-- The shelf itself does not scroll -- it is a handful of fixed rows -- so the wheel exists here only
-- for the debug menu's grade page, which is long enough to.
function Merchant:wheelmoved(dx, dy)
    if self.itemDebug then self.itemDebug:wheelmoved(dx, dy) end
end

function Merchant:moveFocus(d)
    if #self.stock == 0 then return end
    self.focus = ((self.focus - 1 + d) % #self.stock) + 1
end

function Merchant:keypressed(key)
    if self.itemDebug then self.itemDebug:keypressed(key) return end
    if key == "escape" then self:close()
    elseif key == "up" or key == "w" then self:moveFocus(-1)
    elseif key == "down" or key == "s" then self:moveFocus(1)
    elseif key == "return" or key == "kpenter" or key == "space" then self:buy(self.focus) end
end

function Merchant:gamepadpressed(joystick, button)
    if self.itemDebug then self.itemDebug:gamepadpressed(joystick, button) return end
    if button == "b" then self:close()
    elseif button == "dpup" then self:moveFocus(-1)
    elseif button == "dpdown" then self:moveFocus(1)
    elseif button == "a" or button == "start" then self:buy(self.focus) end
end

return Merchant
