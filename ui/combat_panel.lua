-- Right-side combat HUD: the turn-order strip (portraits + resource bars) and the current
-- character's item grid. Persistent (not a modal) and owned by states/battle.lua, which
-- routes input to it and feeds it a per-frame view via setView. Follows the project's
-- three-input standard: mouse hover/click on item slots here, while the battle state maps
-- keyboard number keys and the gamepad to the same arm/cancel actions.
--
-- Layout (per the design sketch): the turn-order strip fills the panel top-down but is
-- BOTTOM-aligned so the current turn sits just above the item grid at the very bottom.
--
--   local panel = CombatPanel.new(combat, {
--       onActivateItem = function(item, index) ... end,  -- slot clicked (arm / toggle)
--       onHoverItem    = function(item_or_nil) ... end,  -- hover changed (drives preview)
--   })
--   panel:setView({ order = {units}, current = unit, isPartyTurn = bool,
--                   items = {inventory}, armedItem = item_or_nil })
--   panel:draw(); panel:mousemoved(x, y); panel:mousepressed(x, y, button)

local Scale = require("scale")

local CombatPanel = {}
CombatPanel.__index = CombatPanel

local PANEL_W = 320
CombatPanel.WIDTH = PANEL_W -- so states can reserve the same right-side margin
local ENTRY_H = 58
local ENTRY_GAP = 6
local SLOT = 56
local SLOT_GAP = 6
local COLS, ROWS = 3, 3

-- Resource bars drawn per turn-strip entry, in order (skipped when a resource's max is 0).
local RESOURCES = {
    { key = "health",  color = { 0.35, 0.80, 0.35 } },
    { key = "mana",    color = { 0.35, 0.55, 0.95 } },
    { key = "stamina", color = { 0.90, 0.75, 0.30 } },
}

function CombatPanel.new(combat, opts)
    opts = opts or {}
    local self = setmetatable({}, CombatPanel)
    self.combat = combat
    self.onActivateItem = opts.onActivateItem
    self.onHoverItem = opts.onHoverItem
    self.onHoverUnit = opts.onHoverUnit

    self.headFont = love.graphics.newFont(16)
    self.nameFont = love.graphics.newFont(14)
    self.smallFont = love.graphics.newFont(12)

    self.x = Scale.WIDTH - PANEL_W
    self.w = PANEL_W

    -- Item grid: 3x3, centred horizontally, anchored to the bottom.
    self.gridW = COLS * SLOT + (COLS - 1) * SLOT_GAP
    self.gridH = ROWS * SLOT + (ROWS - 1) * SLOT_GAP
    self.gridX = self.x + math.floor((PANEL_W - self.gridW) / 2)
    self.gridY = Scale.HEIGHT - self.gridH - 16
    -- Turn strip lives above the item grid.
    self.stripTop = 44
    self.stripBottom = self.gridY - 28

    self.view = { order = {}, items = {}, isPartyTurn = false }
    self.hoverIndex = nil
    self.hoverUnit = nil
    return self
end

-- Feed the per-frame render data (computed by the battle state).
function CombatPanel:setView(view)
    self.view = view or { order = {}, items = {}, isPartyTurn = false }
end

function CombatPanel:contains(px, py)
    return px >= self.x and px <= self.x + self.w and py >= 0 and py <= Scale.HEIGHT
end

-- Item-grid slot rect for a 1-based index (row-major).
function CombatPanel:slotRect(index)
    local col = (index - 1) % COLS
    local row = math.floor((index - 1) / COLS)
    return self.gridX + col * (SLOT + SLOT_GAP),
        self.gridY + row * (SLOT + SLOT_GAP), SLOT, SLOT
end

function CombatPanel:slotIndexAt(px, py)
    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        if px >= sx and px <= sx + sw and py >= sy and py <= sy + sh then return i end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function CombatPanel:draw()
    -- Panel background.
    love.graphics.setColor(0.10, 0.11, 0.15, 0.96)
    love.graphics.rectangle("fill", self.x, 0, self.w, Scale.HEIGHT)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.line(self.x, 0, self.x, Scale.HEIGHT)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(self.headFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("Turn Order", self.x, 14, self.w, "center")

    self:drawTurnStrip()
    self:drawItemGrid()
    love.graphics.setColor(1, 1, 1)
end

-- The on-screen rect of each visible turn-strip entry, shared by draw + hover hit-testing.
function CombatPanel:entryLayout()
    local out = {}
    local entries = self.view.order or {}
    for i, entry in ipairs(entries) do
        local bottom = self.stripBottom - (i - 1) * (ENTRY_H + ENTRY_GAP)
        local top = bottom - ENTRY_H
        if top < self.stripTop then break end -- ran out of room
        out[#out + 1] = { entry = entry, x = self.x + 8, y = top, w = self.w - 16, h = ENTRY_H }
    end
    return out
end

function CombatPanel:drawTurnStrip()
    for _, e in ipairs(self:entryLayout()) do
        self:drawEntry(e.entry, e.y)
    end
end

-- A gold dashed rectangle border, used to mark preview (ghost) entries as hypothetical.
function CombatPanel:dashedRect(x, y, w, h)
    love.graphics.setColor(0.95, 0.85, 0.55, 0.9)
    love.graphics.setLineWidth(1)
    local dash, gap = 6, 4
    local xx = x
    while xx < x + w do
        local seg = math.min(dash, x + w - xx)
        love.graphics.line(xx, y, xx + seg, y)
        love.graphics.line(xx, y + h, xx + seg, y + h)
        xx = xx + dash + gap
    end
    local yy = y
    while yy < y + h do
        local seg = math.min(dash, y + h - yy)
        love.graphics.line(x, yy, x, yy + seg)
        love.graphics.line(x + w, yy, x + w, yy + seg)
        yy = yy + dash + gap
    end
end

function CombatPanel:drawEntry(entry, ey)
    local unit = entry.unit
    local isPreview = entry.preview
    local isCurrent = (unit == self.view.current) and not isPreview
    local isParty = unit.side == "party"
    local ex = self.x + 8
    local ew = self.w - 16
    -- Preview ghosts render faded, so this alpha multiplier dims everything below.
    local a = isPreview and 0.55 or 1

    -- Entry plate, tinted by side (gold-ish for a ghost), brighter for whoever's turn it is.
    if isPreview then love.graphics.setColor(0.42, 0.38, 0.20, 0.40)
    elseif isParty then love.graphics.setColor(0.18, 0.24, 0.34, isCurrent and 1 or 0.8)
    else love.graphics.setColor(0.32, 0.18, 0.18, isCurrent and 1 or 0.8) end
    love.graphics.rectangle("fill", ex, ey, ew, ENTRY_H, 6, 6)

    if isPreview then
        self:dashedRect(ex, ey, ew, ENTRY_H)
    else
        if isCurrent then love.graphics.setColor(0.95, 0.85, 0.55)
        elseif isParty then love.graphics.setColor(0.4, 0.6, 0.85)
        else love.graphics.setColor(0.85, 0.45, 0.4) end
        love.graphics.rectangle("line", ex, ey, ew, ENTRY_H, 6, 6)
    end

    -- Debug: the entry's timeline value (initiative), including the preview ghost's new time.
    if self.view.showTime and entry.time then
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.98, 0.9, 0.6, 0.95)
        love.graphics.printf(string.format("%.1f", entry.time), ex, ey + 3, ew - 6, "right")
    end

    -- Portrait square on the left.
    local ps = ENTRY_H - 6
    local px, py = ex + 3, ey + 3
    local sprite = unit.char.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1, a)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(ps / sw, ps / sh)
        love.graphics.draw(sprite, px + ps / 2, py + ps / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        if isParty then love.graphics.setColor(0.35, 0.55, 0.85, a)
        else love.graphics.setColor(0.75, 0.35, 0.32, a) end
        love.graphics.rectangle("fill", px, py, ps, ps, 4, 4)
        love.graphics.setFont(self.headFont)
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.printf((unit.char.name or "?"):sub(1, 1), px, py + ps / 2 - 10, ps, "center")
    end

    local rx = px + ps + 8
    local rw = ex + ew - rx - 8
    love.graphics.setFont(self.smallFont)

    if isPreview then
        -- A ghost slot shows where the actor would land, not its live resources.
        love.graphics.setColor(0.95, 0.85, 0.55, 0.95)
        love.graphics.print(unit.char.name or "?", rx, ey + 8)
        love.graphics.print("would act here", rx, ey + 30)
        return
    end

    -- Name + resource bars to the right.
    love.graphics.setColor(0.92, 0.92, 0.95)
    love.graphics.print(unit.char.name or "?", rx, ey + 4)

    local by = ey + 22
    for _, res in ipairs(RESOURCES) do
        local stat = unit.char.stats[res.key]
        if type(stat) == "table" and (stat.max or 0) > 0 then
            local ratio = math.max(0, math.min(1, stat.current / stat.max))
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle("fill", rx, by, rw, 7, 2, 2)
            love.graphics.setColor(res.color[1], res.color[2], res.color[3])
            love.graphics.rectangle("fill", rx, by, rw * ratio, 7, 2, 2)
            by = by + 10
        end
    end
end

function CombatPanel:drawItemGrid()
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.7, 0.72, 0.8)
    love.graphics.printf("Items", self.x, self.gridY - 22, self.w, "center")

    local isPartyTurn = self.view.isPartyTurn
    local items = self.view.items or {}
    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        local item = items[i]
        local armed = item and item == self.view.armedItem
        local usable = item and item.activeAbility ~= nil and isPartyTurn

        -- Slot plate.
        love.graphics.setColor(0.16, 0.17, 0.22, isPartyTurn and 1 or 0.5)
        love.graphics.rectangle("fill", sx, sy, sw, sh, 5, 5)

        if item then
            local sprite = item.sprite
            local dim = (not usable) and 0.4 or 1
            if type(sprite) == "userdata" then
                love.graphics.setColor(dim, dim, dim)
                local iw, ih = sprite:getDimensions()
                local scale = math.min((sw - 8) / iw, (sh - 8) / ih)
                love.graphics.draw(sprite, sx + sw / 2, sy + sh / 2, 0, scale, scale,
                    iw / 2, ih / 2)
            else
                love.graphics.setColor(0.6 * dim, 0.6 * dim, 0.65 * dim)
                love.graphics.rectangle("fill", sx + 6, sy + 6, sw - 12, sh - 12, 4, 4)
                love.graphics.setColor(dim, dim, dim)
                love.graphics.printf((item.name or "?"):sub(1, 1), sx, sy + sh / 2 - 8, sw, "center")
            end
        end

        -- Border: armed/selected (green), hovered (gold), usable (blue), else idle.
        if armed then love.graphics.setColor(0.35, 0.85, 0.40)
        elseif usable and self.hoverIndex == i then love.graphics.setColor(0.95, 0.85, 0.55)
        elseif usable then love.graphics.setColor(0.4, 0.6, 0.85)
        else love.graphics.setColor(0.35, 0.37, 0.45) end
        love.graphics.setLineWidth(armed and 2 or 1)
        love.graphics.rectangle("line", sx, sy, sw, sh, 5, 5)
        love.graphics.setLineWidth(1)
    end
end

-- ---------------------------------------------------------------------------
-- Input  (mouse; keyboard/gamepad item arming is handled by the battle state)
-- ---------------------------------------------------------------------------

-- Returns the ability item under a usable, hovered slot (else nil).
function CombatPanel:usableItemAt(px, py)
    if not self.view.isPartyTurn then return nil end
    local i = self:slotIndexAt(px, py)
    local item = i and (self.view.items or {})[i]
    if item and item.activeAbility then return item, i end
    return nil
end

-- The unit whose turn-strip entry is under the cursor (else nil).
function CombatPanel:unitAt(px, py)
    for _, e in ipairs(self:entryLayout()) do
        if px >= e.x and px <= e.x + e.w and py >= e.y and py <= e.y + e.h then
            return e.entry.unit
        end
    end
    return nil
end

-- Set the hovered item / unit (either may be nil), firing the callbacks only on a change.
function CombatPanel:setHover(item, i, unit)
    if i ~= self.hoverIndex then
        self.hoverIndex = i
        if self.onHoverItem then self.onHoverItem(item) end
    end
    if unit ~= self.hoverUnit then
        self.hoverUnit = unit
        if self.onHoverUnit then self.onHoverUnit(unit) end
    end
end

-- Returns true when the cursor is over the panel (so the state won't also move the map
-- cursor). Reports item hover (turn-order preview) and unit hover (board highlight).
function CombatPanel:mousemoved(x, y)
    if not self:contains(x, y) then
        self:setHover(nil, nil, nil)
        return false
    end
    local item, i = self:usableItemAt(x, y)
    self:setHover(item, i, self:unitAt(x, y))
    return true
end

-- Returns true when the click was inside the panel (consumed).
function CombatPanel:mousepressed(x, y, button)
    if button ~= 1 or not self:contains(x, y) then return false end
    local item, i = self:usableItemAt(x, y)
    if item and self.onActivateItem then self.onActivateItem(item, i) end
    return true
end

return CombatPanel
