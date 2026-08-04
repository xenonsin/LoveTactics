-- The Forge pop-up panel: the one bench in the city, and the only screen that spends materials.
-- Lists everything the player owns that a level can improve -- across each roster member's 3x3 grid
-- and the stash -- in the left column, and on the right charts the highlighted thing's WHOLE path: the
-- level ladder over 0..10 (ui/growth_ladder.lua), a footprint filmstrip for an area weapon whose shape
-- opens as it forges, and the next rung's bill plus exactly what it raises.
--
--   local panel = Forge.new({ player = p, onClose = fn })
--
-- THREE CATEGORIES, because the bench does three kinds of work and one flat list of 40 rows is not a
-- list anybody reads (models/forge.lua):
--   Gear        weapons, armor, utility -- per instance, swapped in place for a fresh "+n"
--   Abilities   per instance too. Used to be the class vendor's Upgrade tab.
--   Recipes     consumables, per TYPE -- refine the recipe and every copy bought after comes at that
--               tier. Only consumables the player actually holds are listed, so the bench works on
--               what you own, exactly like the other two.
-- The segment strip is the same widget the shop uses for Buy/Sell, down to the Tab / LB-RB bindings.

local Menu = require("ui.menu")
local Forge = require("models.forge")
local Item = require("models.item")
local Material = require("models.material")
local Character = require("models.character")
local Player = require("models.player")
local Discipline = require("models.discipline")
local Vendor = require("models.vendor")
local CloseButton = require("ui.close_button")
local ItemTooltip = require("ui.item_tooltip") -- printFlavor (sheared italic story line) + printDiscipline
local FootprintDiagram = require("ui.footprint_diagram") -- the drawn area shape, for a footprint that opens as it forges
local GrowthLadder = require("ui.growth_ladder") -- the level-by-level upgrade path
local Colors = require("ui.colors")
local Scale = require("scale")
local InputMode = require("input_mode")
local Theme = require("ui.theme")

local ForgePanel = {}
ForgePanel.__index = ForgePanel

local BOX_W, BOX_H = 1000, 580
local LIST_TOP = 112
local ROW_H, ROW_SPACING, MAX_VISIBLE = 34, 6, 9

local MODES = { "gear", "ability", "recipe" }
local MODE_LABEL = { gear = "Gear", ability = "Abilities", recipe = "Recipes" }
local EMPTY_LABEL = {
    gear = "No weapons, armor or gear to forge.",
    ability = "No abilities to hone.",
    recipe = "No recipes to refine.",
}

-- Growth-sheet palette (the footprint filmstrip + cost band; the level table owns its own colours).
-- MARK = the current level, UP = an improvement, DIM = captions.
local DIM = Theme.muted
local MARK = Theme.accentAmber
local UP = { 0.55, 0.90, 0.58 } -- an improvement: kept heal-green (semantic)

local function pointIn(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function ForgePanel.new(opts)
    opts = opts or {}
    local self = setmetatable({}, ForgePanel)
    self.onClose = opts.onClose
    self.player = opts.player
    self.title = opts.title or "The Forge"
    self.mode = "gear"

    self.titleFont = Theme.display(28)
    self.headFont = Theme.display(18)
    self.bodyFont = Theme.body(15)
    self.smallFont = Theme.body(12) -- level captions, the growth-sheet fine print

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    -- Columns: list (left) | detail (right). No portrait -- the Forge has no vendor behind it.
    self.listLeft = self.boxX + 24
    self.listW = 320
    self.detailX = self.listLeft + self.listW + 24
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

-- ---------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------

-- Everything the player owns that passes `predicate`, each with where it lives so an upgrade can swap
-- it back in place: a roster member's grid cell, or a stash slot. The single walk both the instance
-- categories use -- the shop and the smithy each used to keep their own copy of it.
function ForgePanel:collect(predicate)
    local out = {}
    for _, char in ipairs(self.player.roster or {}) do
        for cell = 1, Character.MAX_INVENTORY do
            local item = char.inventory[cell]
            if item and predicate(item) then
                out[#out + 1] = { item = item, where = char.name or "?",
                    loc = { kind = "grid", char = char, cell = cell } }
            end
        end
    end
    for i, item in ipairs(self.player.stash or {}) do
        if predicate(item) then
            out[#out + 1] = { item = item, where = "Stash", loc = { kind = "stash", index = i } }
        end
    end
    return out
end

-- The distinct consumable blueprints the player holds anywhere. A recipe is per-TYPE, so five potions
-- in three places are one row -- keyed by id, listed in a stable order.
function ForgePanel:collectRecipes()
    local seen, ids = {}, {}
    local function note(item)
        if item and Forge.canRefine(item) and not seen[item.id] then
            seen[item.id] = true
            ids[#ids + 1] = item.id
        end
    end
    for _, char in ipairs(self.player.roster or {}) do
        for cell = 1, Character.MAX_INVENTORY do note(char.inventory[cell]) end
    end
    for _, item in ipairs(self.player.stash or {}) do note(item) end
    table.sort(ids)
    return ids
end

-- The tail of a row label: what the next rung costs, or why it can't be bought. Discipline stock is
-- billed in technique rather than gold (models/forge.lua), so its tail names the currency -- "40 Ninja"
-- against a plain "160g" -- and the difference is legible from the list without opening the row.
local function costTail(cost)
    if not cost then return "max" end
    if cost.locked then return "locked" end
    if cost.technique > 0 then
        local name = Discipline.displayName(cost.techniqueId) or cost.techniqueId
        return cost.technique .. " " .. name
    end
    return cost.gold .. "g"
end

-- Rebuild self.rows + the Menu for the current category. Called on open, on category switch, and after
-- every forge so spent gold and materials are reflected without reopening.
function ForgePanel:refresh()
    local selected = self.menu and self.menu.selected or 1
    self.rows = {}

    if self.mode == "recipe" then
        for _, id in ipairs(self:collectRecipes()) do
            local level = Player.recipeLevel(self.player, id)
            local sample = Item.instantiate(id, nil, level)
            local cost = Forge.recipeCost(self.player, id)
            self.rows[#self.rows + 1] = {
                kind = "recipe", id = id, item = sample, level = level, cost = cost,
                label = sample.name .. "  -  " .. costTail(cost),
                locked = (cost == nil) or cost.locked,
            }
        end
    else
        local wantAbility = (self.mode == "ability")
        local entries = self:collect(function(item)
            return Forge.canWork(item) and ((item.type == "ability") == wantAbility)
        end)
        for _, up in ipairs(entries) do
            local cost = Forge.upgradeCost(self.player, up.item)
            self.rows[#self.rows + 1] = {
                kind = "instance", item = up.item, up = up, level = up.item.level or 0, cost = cost,
                label = up.item.name .. " (" .. up.where .. ")  -  " .. costTail(cost),
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
        startY = self.boxY + LIST_TOP,
        centerX = self.listLeft + self.listW / 2,
        font = self.bodyFont,
        maxVisible = MAX_VISIBLE,
    })
    self.menu.selected = math.min(selected, math.max(#items, 1))
    self.menu:scrollToSelection()
    -- Compute row rects now so the first draw/click works before the first update() tick.
    self.menu:layout()
end

function ForgePanel:hasRows() return self.rows and #self.rows > 0 end

function ForgePanel:setMode(mode)
    self.mode = mode
    self.menu = nil
    self:refresh()
end

function ForgePanel:cycleMode(delta)
    local idx = 1
    for i, m in ipairs(MODES) do if m == self.mode then idx = i end end
    self:setMode(MODES[(idx - 1 + delta) % #MODES + 1])
end

function ForgePanel:setMsg(text, ok) self.message, self.messageOk = text, ok end

function ForgePanel:close()
    if self.onClose then self.onClose() end
end

-- ---------------------------------------------------------------------------
-- The ceiling, in words
-- ---------------------------------------------------------------------------

-- What is holding this item's ladder short, phrased as the thing the player would go and do. Two rules
-- now, mirroring Forge.ceilingFor: a class item waits on that house's quest line, and a classless item
-- is never locked at all. DISCIPLINE STOCK NO LONGER APPEARS HERE -- it has no ceiling, only a price in
-- technique, so what stops it is affordability and it says so through the "technique" refusal instead.
function ForgePanel:ceilingReason(item)
    local class = Item.classOf(item)
    if class then
        local vendorId = Forge.houseVendorFor(class)
        local house = vendorId and (Vendor.get(vendorId) or {}).name or "its house"
        return "Complete more of " .. house .. "'s quests to forge past this."
    end
    return "Locked."
end

-- The standing line under the item's type: what this thing's ladder is measured against. For a
-- DISCIPLINE item that is the bank and who holds it -- "Ninja  -  62 held by Clem" -- because there is
-- no ceiling left to name and the only question is whether the technique is there. For a plain class
-- item it is still the house and the ceiling its standing sets. Nothing for classless stock.
function ForgePanel:standingLine(item)
    if item.discipline and Discipline.defs[item.discipline] then
        local name = Discipline.displayName(item.discipline) or item.discipline
        local holder, held = Discipline.techniqueHolder(self.player, item.discipline)
        if not holder then
            return name .. "  -  none banked yet"
        end
        return name .. "  -  " .. held .. " held by " .. (holder.name or "?")
    end
    local ceiling = Forge.ceilingFor(self.player, item)
    local class = Item.classOf(item)
    if class then
        local vendorId = Forge.houseVendorFor(class)
        local house = vendorId and (Vendor.get(vendorId) or {}).name or class
        return house .. "  -  ceiling +" .. ceiling
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Transactions
-- ---------------------------------------------------------------------------

-- One reason table for both paths: models/forge.lua deliberately returns the same reason set from
-- Forge.upgrade and Forge.refineRecipe.
function ForgePanel:refusal(reason, item)
    if reason == "gold" then return "Not enough gold." end
    -- Names the verb that earns it, because "not enough technique" is only actionable if the player
    -- knows technique comes from casting the discipline's own gear in a fight.
    if reason == "technique" then
        local name = Discipline.displayName(item.discipline) or "that discipline"
        return "Not enough technique. Fight with " .. name .. " gear to bank more."
    end
    if reason == "materials" then return "Not enough materials." end
    if reason == "locked" then return self:ceilingReason(item) end
    if reason == "max level" then return (item.name or "That") .. " is at maximum level." end
    return "It cannot be forged."
end

function ForgePanel:activateRow(row)
    if not row then return end
    if row.kind == "recipe" then self:refine(row) else self:upgrade(row) end
end

-- Forge the highlighted instance up one level: check the ceiling, gold and materials, spend them, swap
-- the fresh "+n" instance into the slot it came from, and save.
function ForgePanel:upgrade(row)
    local up = row.up
    local newItem, reason = Forge.upgrade(self.player, up.item)
    if not newItem then
        self:setMsg(self:refusal(reason, up.item), false)
        return
    end
    if up.loc.kind == "grid" then
        up.loc.char.inventory[up.loc.cell] = newItem
    else
        self.player.stash[up.loc.index] = newItem
    end
    Player.save()
    self:setMsg(newItem.name .. " forged.", true)
    self:refresh()
end

-- Refine the highlighted recipe one tier: every copy bought from here on comes at that tier.
function ForgePanel:refine(row)
    local level, reason = Forge.refineRecipe(self.player, row.id)
    if not level then
        self:setMsg(self:refusal(reason, row.item), false)
        return
    end
    Player.save()
    self:setMsg(row.item.name .. " recipe refined to +" .. level .. ".", true)
    self:refresh()
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function ForgePanel:update(dt)
    if self:hasRows() then self.menu:update(dt) end
end

function ForgePanel:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, self.boxX, self.boxY + 18, BOX_W, "center")

    -- Gold, opposite the category strip: one of the two things a forge spends.
    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.player.gold .. " gold", self.boxX, self.modeY + 6, BOX_W - 24, "right")

    self:drawModeSelector()
    if self:hasRows() then
        self.menu:draw()
        self:drawLockedOverlay()
        self:drawDetail()
    else
        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.muted)
        love.graphics.printf(EMPTY_LABEL[self.mode] or "Nothing to forge.",
            self.listLeft, self.boxY + 200, self.listW, "center")
    end

    if self.message then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(self.messageOk and 0.6 or 0.9, self.messageOk and 0.85 or 0.6,
            self.messageOk and 0.6 or 0.55)
        love.graphics.printf(self.message, self.boxX, self.boxY + BOX_H - 54, BOX_W, "center")
    end

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    -- Show the glyphs for the device last used: pad buttons only in gamepad mode, keyboard/mouse otherwise.
    local hint = InputMode.isGamepad()
        and "A: forge    LB/RB: Gear/Abilities/Recipes    D-pad: scroll    B: close"
        or "Enter: forge    Tab: Gear/Abilities/Recipes    Wheel: scroll    Click X / Esc: close"
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 30, BOX_W, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

function ForgePanel:drawModeSelector()
    love.graphics.setFont(self.bodyFont)
    for _, m in ipairs(MODES) do
        local r = self.segRects[m]
        local active = (self.mode == m)
        Theme.set(active and Theme.panel or Theme.panel2)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
        love.graphics.setLineWidth(active and 1.5 or 1)
        Theme.set(active and Theme.accentAmber or Theme.frame)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
        love.graphics.setLineWidth(1)
        Theme.set(active and Theme.accentAmber or Theme.muted)
        love.graphics.printf(MODE_LABEL[m], r.x, r.y + r.h / 2 - 10, r.w, "center")
    end
end

-- Menu has no disabled row, so grey the locked/maxed ones by painting over them.
function ForgePanel:drawLockedOverlay()
    for i, row in ipairs(self.rows) do
        local slot = self.menu.items[i]
        if row.locked and slot and slot.x then
            Theme.set(Theme.mount, 0.6)
            love.graphics.rectangle("fill", slot.x, slot.y, slot.w, slot.h, Theme.R, Theme.R)
        end
    end
end

-- The footprint filmstrip: a small drawn picture of the area shape at each level it changes (a line
-- opening into a cone). The form the item is on RIGHT NOW is boxed in gold; the rest sit muted. Nothing
-- to show for a single-target weapon (growth.footprint is nil) or a shape that never moves past base.
function ForgePanel:drawFootprintStrip(footprint, x, y, w, current)
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
        Theme.set(Theme.slot)
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

-- The forge target and its bill, plus a one-line summary of exactly what the next level raises. The
-- bill is three tracks (gold, craft stock, house stock) in coloured segments, so whichever resource is
-- actually short turns red on its own -- and each material carries the count already held in brackets,
-- which is what makes a house material read as "go run that line".
function ForgePanel:drawCostBand(row, growth, x, y, w)
    local cost = row.cost
    if not cost then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.7, 0.85, 0.7)
        love.graphics.printf("At maximum level -- fully forged.", x, y + 20, w, "left")
        return
    end

    love.graphics.setFont(self.bodyFont)
    local verb = row.kind == "recipe" and "Refine to +" or "Forge to +"
    love.graphics.setColor(MARK[1], MARK[2], MARK[3])
    love.graphics.print(verb .. cost.level, x, y)

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

    -- The bill. Materials in a fixed order (pairs would reshuffle the line every frame).
    local ids = {}
    for id in pairs(cost.materials) do ids[#ids + 1] = id end
    table.sort(ids)

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
    -- The currency track: technique for discipline stock, gold for everything else -- never both, so
    -- exactly one of these draws (models/forge.lua). The technique segment carries the bank in
    -- parentheses the way each material carries what is held, since that is the same question.
    if cost.technique > 0 then
        local name = Discipline.displayName(cost.techniqueId) or cost.techniqueId
        seg(cost.technique .. " " .. name .. " (" .. cost.techniqueHeld .. ")",
            cost.techniqueHeld >= cost.technique)
    else
        seg(cost.gold .. " gold", self.player.gold >= cost.gold)
    end
    for _, id in ipairs(ids) do
        local count = cost.materials[id]
        local have = Player.materialCount(self.player, id)
        local def = Material.get(id)
        love.graphics.setColor(DIM[1], DIM[2], DIM[3]); love.graphics.print("  +  ", cx, cy)
        cx = cx + self.bodyFont:getWidth("  +  ")
        seg(count .. " " .. (def and def.name or id) .. " (" .. have .. ")", have >= count)
    end

    -- Why the button will refuse, when the ceiling is what is refusing it.
    if cost.locked then
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.9, 0.6, 0.55)
        love.graphics.printf(self:ceilingReason(row.item), x, cy + 24, w, "left")
    end
end

function ForgePanel:drawDetail()
    local row = self.rows[self.menu.selected]
    if not row then return end
    local item = row.item

    local x = self.detailX
    local w = self.detailW
    local y = self.boxY + LIST_TOP

    -- Growth is memoized per blueprint: the curve is identical at every level, so only the current-level
    -- marker moves -- and that reads the row's level live each frame.
    if self.growthId ~= item.id then
        self.growth = Item.growth(item.id)
        self.growthId = item.id
    end
    local growth = self.growth

    love.graphics.setFont(self.headFont)
    Theme.set(Theme.ink)
    love.graphics.printf(item.name, x, y, w - 40, "left")

    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.muted)
    local kindLabel = row.kind == "recipe" and "recipe" or item.type
    love.graphics.printf(kindLabel .. "   (level " .. (row.level or 0) .. " / " .. Item.MAX_LEVEL .. ")",
        x, y + 26, w, "left")
    ItemTooltip.printDiscipline(item, x, y + 26, w, self.bodyFont)

    -- What sets this thing's ceiling, and where it currently stands.
    local standing = self:standingLine(item)
    if standing then
        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.cursor)
        love.graphics.printf(standing, x, y + 48, w, "left")
    end

    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.ink)
    love.graphics.printf(item.description or "", x, y + 66, w, "left")

    local current = row.level or 0
    local nextLevel = row.cost and row.cost.level or nil

    -- Growth caption, then the level ladder: every level 0..10 with the value each grants, current row
    -- gold, the rung the button buys green, and everything past the ceiling dimmed (ui/growth_ladder.lua
    -- -- `lockedFrom` is the first level out of reach). The ladder gets its FULL width on the left; when
    -- the area footprint opens as it forges (a static shape is not growth), the filmstrip sits to its
    -- right rather than below, so the ladder never gives up rows. The bill pins near the bottom.
    local sheetY = y + 110
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(DIM[1], DIM[2], DIM[3])
    love.graphics.print("GROWTH", x, sheetY)

    local showStrip = growth and growth.footprint and #growth.footprint.changedAt > 1
    local costBandY = self.boxY + BOX_H - 152 -- leaves the ladder room for all 11 levels + header
    local ladderTop = sheetY + 18
    local ladderH = costBandY - 6 - ladderTop
    local ladderW = showStrip and 230 or w
    local ceiling = Forge.ceilingFor(self.player, item)
    GrowthLadder.draw(growth, x, ladderTop, ladderW, ladderH, {
        current = current, nextLevel = nextLevel,
        lockedFrom = (ceiling < Item.MAX_LEVEL) and (ceiling + 1) or nil,
        rowFont = self.smallFont, headFont = self.smallFont,
    })

    if showStrip then
        self:drawFootprintStrip(growth.footprint, x + ladderW + 16, ladderTop + 8, w - ladderW - 16, current)
    end

    self:drawCostBand(row, growth, x, costBandY, w)
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function ForgePanel:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    if self:hasRows() then self.menu:mousemoved(x, y) end
end

-- Hand over the close X, the category tabs, or any forgeable row; arrow elsewhere. See ui/cursor.lua.
function ForgePanel:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    for _, m in ipairs(MODES) do
        if pointIn(self.segRects[m], x, y) then return "hand" end
    end
    if self:hasRows() and self.menu:mouseOverItem(x, y) then return "hand" end
    return "arrow"
end

function ForgePanel:wheelmoved(dx, dy)
    if self:hasRows() then self.menu:wheelmoved(dx, dy) end
end

function ForgePanel:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end
    for _, m in ipairs(MODES) do
        if pointIn(self.segRects[m], x, y) then self:setMode(m) return end
    end
    if self:hasRows() then
        self.menu:mousepressed(x, y, button)
        return
    end
    if not pointIn({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then self:close() end
end

function ForgePanel:keypressed(key)
    if key == "escape" then self:close()
    elseif key == "tab" then self:cycleMode(1)
    elseif key == "left" or key == "a" then self:cycleMode(-1)
    elseif key == "right" or key == "d" then self:cycleMode(1)
    elseif self:hasRows() then self.menu:keypressed(key) end
end

function ForgePanel:gamepadpressed(joystick, button)
    if button == "b" then self:close()
    elseif button == "leftshoulder" then self:cycleMode(-1)
    elseif button == "rightshoulder" then self:cycleMode(1)
    elseif self:hasRows() then self.menu:gamepadpressed(joystick, button) end
end

return ForgePanel
