-- Blacksmith pop-up panel. Lists every forgeable weapon and armor the player owns -- across each
-- roster member's 3x3 grid and the stash -- in the left column, and on the right charts the highlighted
-- item's WHOLE forge path: a per-stat bar skyline over levels 0..10 (current level gold, next green, gains
-- ahead capped green), a footprint filmstrip for an area weapon whose shape opens as it forges (see
-- Item.growth + ui/footprint_diagram.lua), and the next upgrade's cost + exactly what it raises. Upgrading
-- swaps the item in place for a fresh "+n" instance (models/blacksmith.lua) and saves.
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
local ItemTooltip = require("ui.item_tooltip") -- printFlavor (sheared italic story line) + printDiscipline
local FootprintDiagram = require("ui.footprint_diagram") -- the drawn area shape, for a footprint that opens as it forges
local Colors = require("ui.colors")
local Scale = require("scale")
local InputMode = require("input_mode")

local BlacksmithPanel = {}
BlacksmithPanel.__index = BlacksmithPanel

-- Widened from the old two-column shape to make room for the growth sheet on the right: a per-stat
-- bar chart across levels 0..10, plus a footprint filmstrip for an area weapon whose shape opens up.
local BOX_W, BOX_H = 900, 520
local LIST_TOP = 110
local ROW_H, ROW_SPACING, MAX_VISIBLE = 34, 6, 8

-- Growth-sheet palette (level bars + filmstrip). OWNED = a level already forged, GHOST = one not yet
-- reached, MARK = the current level, NEXT = the level the forge button would buy, UP = an improvement.
local DIM = { 0.55, 0.60, 0.70 }
local BRIGHT = { 0.92, 0.93, 0.97 }
local OWNED = { 0.62, 0.68, 0.80 }
local GHOST = { 0.34, 0.37, 0.46 }
local MARK = { 0.95, 0.85, 0.55 }
local NEXT = { 0.55, 0.90, 0.58 }
local UP = { 0.55, 0.90, 0.58 }

function BlacksmithPanel.new(opts)
    opts = opts or {}
    local self = setmetatable({}, BlacksmithPanel)
    self.onClose = opts.onClose
    self.titleFont = love.graphics.newFont(28)
    self.headFont = love.graphics.newFont(18)
    self.bodyFont = love.graphics.newFont(15)
    self.smallFont = love.graphics.newFont(12) -- bar labels, level captions, the growth-sheet fine print

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
        buttonWidth = 290,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        startY = self.boxY + LIST_TOP,
        centerX = self.boxX + BOX_W * 0.185,
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

-- Bar geometry shared by the axis header and every stat row, derived from the detail column (x, w).
local LABEL_W, VALUE_W = 104, 56

-- One stat's whole forge path as a mini bar chart: 11 columns (levels 0..10), each column's HEIGHT the
-- value at that level, so the growth reads as a rising skyline. The current level is gold, the level the
-- Forge button would buy is green, already-forged levels are solid and unreached ones ghosted -- and a
-- level that steps the stat UP wears a green cap, so "what improves here" is legible without a number.
-- The right column quotes the exact value now, over the value at max.
function BlacksmithPanel:drawStatBar(stat, x, y, w, rowH, current, nextLevel)
    local maxLevel = Item.MAX_LEVEL
    local barsX = x + LABEL_W
    local barsW = w - LABEL_W - VALUE_W
    local colStep = barsW / (maxLevel + 1)
    local colW = math.max(2, colStep - 3)
    local baseline = y + rowH - 3
    local barMaxH = rowH - 5
    local span = (stat.max ~= stat.min) and (stat.max - stat.min) or 1

    love.graphics.setFont(self.smallFont)
    local labelCol = stat.primary and BRIGHT or DIM
    love.graphics.setColor(labelCol[1], labelCol[2], labelCol[3])
    love.graphics.print(stat.label, x, y + (rowH - self.smallFont:getHeight()) / 2)

    for i = 0, maxLevel do
        local v = stat.values[i]
        if v then
            -- Floor the fill so the smallest value still shows a stub, then scale the rest to the span.
            local frac = 0.20 + 0.80 * ((v - stat.min) / span)
            local h = math.max(2, math.floor(barMaxH * frac))
            local cx = barsX + i * colStep
            local col, a
            if i == current then col, a = MARK, 1
            elseif i == nextLevel then col, a = NEXT, 1
            elseif i < current then col, a = OWNED, 0.95
            else col, a = GHOST, 0.85 end
            love.graphics.setColor(col[1], col[2], col[3], a)
            love.graphics.rectangle("fill", cx, baseline - h, colW, h, 1, 1)
            -- A green cap marks a level that raises the stat (only the ones not yet forged, so the eye
            -- goes to the gains still ahead). The current/next columns already carry their own colour.
            if stat.changed[i] and i > current and i ~= nextLevel then
                love.graphics.setColor(UP[1], UP[2], UP[3], 0.55)
                love.graphics.rectangle("fill", cx, baseline - h - 2, colW, 2)
            end
        end
    end

    -- Value column: what the stat is at the CURRENT level, over its value at max.
    local vx = x + w - VALUE_W
    local nowV = stat.values[current] or stat.values[maxLevel]
    love.graphics.setColor(BRIGHT[1], BRIGHT[2], BRIGHT[3])
    love.graphics.printf(tostring(nowV), vx, y, VALUE_W, "right")
    love.graphics.setColor(DIM[1], DIM[2], DIM[3])
    love.graphics.printf("max " .. tostring(stat.max), vx, y + 12, VALUE_W, "right")
end

-- The footprint filmstrip: a small drawn picture of the area shape at each level it changes (a line
-- opening into a cone). The form the item is on RIGHT NOW is boxed in gold; the rest sit muted. Nothing
-- to show for a single-target weapon (growth.footprint is nil) or a shape that never moves past base.
function BlacksmithPanel:drawFootprintStrip(footprint, x, y, w, current)
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(DIM[1], DIM[2], DIM[3])
    love.graphics.print("FOOTPRINT", x, y)

    -- The form the current level is on = the last change at or below it.
    local currentForm = footprint.changedAt[1]
    for _, lvl in ipairs(footprint.changedAt) do
        if lvl <= current then currentForm = lvl end
    end

    local box, gap, sy = 46, 14, y + 16
    local sx = x
    for _, lvl in ipairs(footprint.changedAt) do
        local isNow = (lvl == currentForm)
        love.graphics.setColor(0.10, 0.11, 0.15, 0.9)
        love.graphics.rectangle("fill", sx, sy, box, box, 3, 3)
        FootprintDiagram.draw(footprint.levels[lvl], sx, sy, box, isNow and MARK or Colors.AOE)
        if isNow then
            love.graphics.setColor(MARK[1], MARK[2], MARK[3], 0.9)
            love.graphics.rectangle("line", sx + 0.5, sy + 0.5, box - 1, box - 1, 3, 3)
        end
        local cap = (lvl == 0) and "base" or ("+" .. lvl)
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(isNow and MARK[1] or DIM[1], isNow and MARK[2] or DIM[2], isNow and MARK[3] or DIM[3])
        love.graphics.printf(cap, sx, sy + box + 1, box, "center")
        sx = sx + box + gap
    end
end

-- The forge target and its cost, plus a one-line summary of exactly what the next level raises -- the
-- per-level "what improves" the skyline shows all at once, spelled out for the step the button buys.
function BlacksmithPanel:drawCostBand(item, growth, x, y, w)
    local cost = Blacksmith.upgradeCost(item)
    if not cost then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.7, 0.85, 0.7)
        love.graphics.printf("At maximum level -- fully forged.", x, y + 20, w, "left")
        return
    end

    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(MARK[1], MARK[2], MARK[3])
    love.graphics.print("Forge to +" .. cost.level, x, y)

    -- What that level raises: each scaling stat's step, plus a note if the footprint opens up here.
    local raises = {}
    for _, stat in ipairs(growth and growth.stats or {}) do
        if stat.changed[cost.level] then
            local d = stat.values[cost.level] - stat.values[cost.level - 1]
            raises[#raises + 1] = stat.label .. " " .. (d >= 0 and "+" or "") .. d
        end
    end
    if growth and growth.footprint then
        for _, lvl in ipairs(growth.footprint.changedAt) do
            if lvl == cost.level then raises[#raises + 1] = "footprint opens" end
        end
    end
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(UP[1], UP[2], UP[3])
    love.graphics.printf(#raises > 0 and ("Raises  " .. table.concat(raises, ",  ")) or "No stat change",
        x, y + 24, w, "left")

    -- Cost, in coloured segments so the resource actually short turns red on its own.
    love.graphics.setFont(self.bodyFont)
    local cy = y + 44
    local cx = x
    local function seg(text, ok)
        love.graphics.setColor(ok and 0.85 or 0.92, ok and 0.85 or 0.45, ok and 0.6 or 0.42)
        love.graphics.print(text, cx, cy)
        cx = cx + self.bodyFont:getWidth(text)
    end
    love.graphics.setColor(DIM[1], DIM[2], DIM[3])
    love.graphics.print("Cost  ", cx, cy); cx = cx + self.bodyFont:getWidth("Cost  ")
    seg(cost.gold .. " gold", self.player.gold >= cost.gold)
    for id, count in pairs(cost.materials) do
        local have = Player.materialCount(self.player, id)
        local def = Material.get(id)
        love.graphics.setColor(DIM[1], DIM[2], DIM[3]); love.graphics.print("  +  ", cx, cy)
        cx = cx + self.bodyFont:getWidth("  +  ")
        seg(count .. " " .. (def and def.name or id) .. " (" .. have .. ")", have >= count)
    end
end

function BlacksmithPanel:drawDetail()
    local entry = self.entries[self.menu.selected]
    if not entry then return end
    local item = entry.item

    local x = self.boxX + 350
    local w = 520
    local y = self.boxY + LIST_TOP

    -- Growth is memoized per blueprint: the curve is identical at every level, so only the current-level
    -- marker moves -- and that reads item.level live each frame.
    if self.growthId ~= item.id then
        self.growth = Item.growth(item.id)
        self.growthId = item.id
    end
    local growth = self.growth

    love.graphics.setFont(self.headFont)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.printf(item.name, x, y, w - 40, "left")

    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.6, 0.65, 0.75)
    love.graphics.printf(item.type .. "   (level " .. (item.level or 0) .. " / " .. Item.MAX_LEVEL .. ")",
        x, y + 26, w, "left")
    ItemTooltip.printDiscipline(item, x, y + 26, w, self.bodyFont)

    love.graphics.setColor(0.8, 0.82, 0.88)
    love.graphics.printf(item.description or "", x, y + 50, w, "left")

    local current = item.level or 0
    local nextLevel = current + 1
    if nextLevel > Item.MAX_LEVEL then nextLevel = nil end

    -- Growth sheet header + level axis ends over the bar columns.
    local sheetY = y + 96
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(DIM[1], DIM[2], DIM[3])
    love.graphics.print("GROWTH", x, sheetY)
    love.graphics.print("0", x + LABEL_W, sheetY)
    love.graphics.printf("10", x + LABEL_W, sheetY, w - LABEL_W - VALUE_W, "right")

    -- Bars, then (only when the ability's area footprint actually OPENS as it forges -- a static shape
    -- is not growth and would just steal rows from the real stats) the filmstrip below them, then the
    -- cost band pinned near the bottom. Rows are capped to the room above whichever section comes next.
    local showStrip = growth and growth.footprint and #growth.footprint.changedAt > 1
    local costBandY = self.boxY + BOX_H - 150
    local stripY = showStrip and (costBandY - 76) or nil
    local barsTop = sheetY + 16
    local barsBottom = (stripY or costBandY) - 6
    local rowH = 24
    local maxRows = math.max(1, math.floor((barsBottom - barsTop) / rowH))

    local stats = growth and growth.stats or {}
    local shown = math.min(#stats, maxRows)
    for i = 1, shown do
        self:drawStatBar(stats[i], x, barsTop + (i - 1) * rowH, w, rowH, current, nextLevel)
    end
    if #stats > shown then
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(DIM[1], DIM[2], DIM[3])
        love.graphics.print("+" .. (#stats - shown) .. " more", x, barsTop + shown * rowH)
    elseif #stats == 0 then
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(DIM[1], DIM[2], DIM[3])
        love.graphics.print("This piece has no scaling stat to chart.", x, barsTop)
    end

    if stripY then
        self:drawFootprintStrip(growth.footprint, x, stripY, w, current)
    end

    self:drawCostBand(item, growth, x, costBandY, w)
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
