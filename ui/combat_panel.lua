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
local Combat = require("models.combat")

local CombatPanel = {}
CombatPanel.__index = CombatPanel

local PANEL_W = 320
CombatPanel.WIDTH = PANEL_W -- so states can reserve the same right-side margin
local ENTRY_H = 58
local ENTRY_GAP = 6
-- Item slots are rectangular (wider than tall) and kept compact so the turn-order
-- strip above them gets the bulk of the panel height.
local SLOT_W = 96
local SLOT_H = 58
local SLOT_GAP = 6
local COLS, ROWS = 3, 3

-- Resource bars drawn per turn-strip entry, in order (skipped when a resource's max is 0).
local RESOURCES = {
    { key = "health",  color = { 0.35, 0.80, 0.35 } },
    { key = "mana",    color = { 0.35, 0.55, 0.95 } },
    { key = "stamina", color = { 0.90, 0.75, 0.30 } },
}

-- Cost badge tint per resource stat (falls back to a neutral grey for anything else).
local RES_COLOR = {}
for _, r in ipairs(RESOURCES) do RES_COLOR[r.key] = r.color end
local COST_FALLBACK = { 0.75, 0.75, 0.80 }
local SPEED_COLOR = { 0.95, 0.85, 0.55 } -- gold, matching the timeline/initiative accent
local WARN_COLOR = { 0.95, 0.40, 0.38 }  -- red cost badge on an ability the actor can't afford

-- Draw a resource bar with an optional preview `delta` (an aimed action's projected change): the
-- "after" fill in the pool colour, then the lost slice in red (delta < 0, brighter when lethal) or
-- the gained slice in green (delta > 0) beside it. Mirrors ui/tile_tooltip.lua's bar so the banner
-- preview reads the same as the tooltip. No delta = a plain fill.
local function drawResourceBar(x, y, w, h, cur, max, color, delta, lethal)
    delta = delta or 0
    local ratio = (max > 0) and math.max(0, math.min(1, cur / max)) or 0
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x, y, w, h, 2, 2)
    if delta ~= 0 and max > 0 then
        local afterRatio = math.max(0, math.min(1, (cur + delta) / max))
        if delta < 0 then
            love.graphics.setColor(color[1], color[2], color[3], 0.95)
            love.graphics.rectangle("fill", x, y, w * afterRatio, h, 2, 2)
            local loseCol = lethal and { 1.0, 0.30, 0.28 } or { 0.90, 0.35, 0.30 }
            love.graphics.setColor(loseCol[1], loseCol[2], loseCol[3], 0.9)
            love.graphics.rectangle("fill", x + w * afterRatio, y, w * (ratio - afterRatio), h, 2, 2)
        else
            love.graphics.setColor(color[1], color[2], color[3], 0.95)
            love.graphics.rectangle("fill", x, y, w * ratio, h, 2, 2)
            love.graphics.setColor(0.55, 0.92, 0.58, 0.9)
            love.graphics.rectangle("fill", x + w * ratio, y, w * (afterRatio - ratio), h, 2, 2)
        end
    else
        love.graphics.setColor(color[1], color[2], color[3], 0.95)
        love.graphics.rectangle("fill", x, y, w * ratio, h, 2, 2)
    end
end

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
    self.slotFont = love.graphics.newFont(11)  -- item name inside a grid slot

    self.x = Scale.WIDTH - PANEL_W
    self.w = PANEL_W

    -- Item grid: 3x3, centred horizontally, anchored to the bottom.
    self.gridW = COLS * SLOT_W + (COLS - 1) * SLOT_GAP
    self.gridH = ROWS * SLOT_H + (ROWS - 1) * SLOT_GAP
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
    return self.gridX + col * (SLOT_W + SLOT_GAP),
        self.gridY + row * (SLOT_H + SLOT_GAP), SLOT_W, SLOT_H
end

function CombatPanel:slotIndexAt(px, py)
    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        if px >= sx and px <= sx + sw and py >= sy and py <= sy + sh then return i end
    end
    return nil
end

-- Can the current actor pay `item`'s ability cost right now? True for passive/costless items and
-- when there is no current actor. Drives the grayed-out "can't afford" slot state.
function CombatPanel:canAfford(item)
    local ab = item and item.activeAbility
    local cur = self.view.current
    if not ab or not cur then return true end
    return Combat.canAfford(cur.char, ab)
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function CombatPanel:draw()
    -- Panel background. Softened (lower opacity, a dim 1px divider) so it frames the board
    -- without walling it in -- mirrors states/battle.lua drawLeftColumn.
    love.graphics.setColor(0.10, 0.11, 0.15, 0.86)
    love.graphics.rectangle("fill", self.x, 0, self.w, Scale.HEIGHT)
    love.graphics.setColor(0.30, 0.33, 0.42)
    love.graphics.setLineWidth(1)
    love.graphics.line(self.x, 0, self.x, Scale.HEIGHT)

    love.graphics.setFont(self.headFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("Turn Order", self.x, 14, self.w, "center")

    self:drawTurnStrip()
    self:drawItemGrid()
    love.graphics.setColor(1, 1, 1)
end

-- The on-screen rect of each visible turn-strip entry, shared by draw + hover hit-testing.
-- Each entry carries its turn-order number (`num`): 1 = acting now, matching the board token
-- (ui/battle_map.lua) so the player can tie a strip row to a unit at a glance. Preview ghosts
-- don't consume a number (they're a hypothetical slot, not a live position), so the numbers
-- stay aligned with the board's live turn order.
function CombatPanel:entryLayout()
    local out = {}
    local entries = self.view.order or {}
    local turnNo = 0
    -- Bottom-pinned: the soonest entry sits at stripBottom (just above the item grid) and the
    -- strip grows upward, so the current actor is always adjacent to its items.
    for i, entry in ipairs(entries) do
        local bottom = self.stripBottom - (i - 1) * (ENTRY_H + ENTRY_GAP)
        local top = bottom - ENTRY_H
        if top < self.stripTop then break end -- ran out of room
        local num
        if not entry.preview then
            turnNo = turnNo + 1
            num = turnNo
        end
        out[#out + 1] = { entry = entry, num = num, x = self.x + 8, y = top, w = self.w - 16, h = ENTRY_H }
    end
    return out
end

function CombatPanel:drawTurnStrip()
    for _, e in ipairs(self:entryLayout()) do
        self:drawEntry(e.entry, e.y, e.num)
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

-- Rects of the active status badges on `unit`'s turn-strip entry (entry left/width ex/ew, row
-- top ey). Shared by drawEntry + statusAt so a badge's tooltip lands exactly where it's drawn.
-- Anchored right and laid out right-to-left, leaving room at the far edge for the initiative num.
function CombatPanel:statusBadgeRects(unit, ex, ew, ey)
    local statuses = unit.statuses
    if not statuses or #statuses == 0 then return {} end
    local bw, bh, gap = 16, 14, 3
    local out = {}
    local x = ex + ew - 40
    for i = #statuses, 1, -1 do
        x = x - bw
        out[#out + 1] = { st = statuses[i], x = x, y = ey + 4, w = bw, h = bh }
        x = x - gap
    end
    return out
end

function CombatPanel:drawEntry(entry, ey, num)
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

    -- Debug: the entry's initiative (0 = acting now), including the preview ghost's new value.
    if self.view.showInitiative and entry.initiative then
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.98, 0.9, 0.6, 0.95)
        love.graphics.printf(string.format("%.1f", entry.initiative), ex, ey + 3, ew - 6, "right")
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

    -- Turn-order number badge in the portrait's top-left corner, mirroring the board token
    -- (ui/battle_map.lua drawTurnNumber) so the same #N points at the same unit on both.
    if num then
        love.graphics.setColor(0, 0, 0, 0.72)
        love.graphics.rectangle("fill", px, py, 18, 16, 3, 3)
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.98, 0.95, 0.7)
        love.graphics.printf(tostring(num), px, py + 1, 18, "center")
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

    -- Active status badges on the name row, anchored right (leaving room at the far edge for the
    -- optional initiative debug number), so a stunned/rooted unit reads on the strip too.
    for _, r in ipairs(self:statusBadgeRects(unit, ex, ew, ey)) do
        local col = (r.st.def and r.st.def.color) or { 0.82, 0.82, 0.88 }
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 3, 3)
        love.graphics.setColor(col[1], col[2], col[3], 0.95)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 3, 3)
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.printf((r.st.def and r.st.def.abbr) or (r.st.name or "?"):sub(1, 1),
            r.x, r.y, r.w, "center")
    end

    -- Aimed-action preview for this unit (damage/heal on its HP, resource cost on the actor's pool),
    -- projected onto the bars so a strike/heal/cast reads on the turn order just like the tooltip.
    local pv = self.view.preview and self.view.preview[unit]
    local by = ey + 22
    for _, res in ipairs(RESOURCES) do
        local stat = unit.char.stats[res.key]
        if type(stat) == "table" and (stat.max or 0) > 0 then
            local delta, lethal = 0, false
            if pv then
                if res.key == "health" then
                    delta = (pv.heal or 0) - (pv.damage or 0)
                    lethal = pv.lethal
                elseif pv.cost and pv.cost.stat == res.key then
                    delta = -(pv.cost.amount or 0)
                end
            end
            drawResourceBar(rx, by, rw, 7, stat.current, stat.max, res.color, delta, lethal)
            by = by + 10
        end
    end
end

-- Small hourglass glyph (two triangles) for the speed badge, drawn in the given box.
function CombatPanel:drawHourglass(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    love.graphics.polygon("fill", x, y, x + w, y, x + w / 2, y + h / 2)
    love.graphics.polygon("fill", x + w / 2, y + h / 2, x, y + h, x + w, y + h)
end

-- A cost/speed corner badge: a dark pill with an icon and a number. `align` is "left"
-- (top-left cost) or "right" (top-right speed); `iconKind` is "dot" or "hourglass".
function CombatPanel:drawBadge(sx, sy, sw, corner, iconKind, amount, color, a)
    love.graphics.setFont(self.smallFont)
    local label = tostring(amount)
    local tw = self.smallFont:getWidth(label)
    local iconW, gap, padX = 9, 3, 5
    local bw = padX + iconW + gap + tw + padX
    local bh = 18
    local pad = 3
    local bx = (corner == "right") and (sx + sw - pad - bw) or (sx + pad)
    local by = sy + pad

    love.graphics.setColor(0.06, 0.07, 0.10, 0.82 * (a or 1))
    love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)

    local ix = bx + padX
    local iy = by + (bh - 10) / 2
    if iconKind == "hourglass" then
        self:drawHourglass(ix, iy, iconW, 10, color[1], color[2], color[3], a)
    else -- resource "dot": a filled diamond reads cleaner than a circle at this size
        local cx, cy, rr = ix + iconW / 2, iy + 5, 5
        love.graphics.setColor(color[1], color[2], color[3], a or 1)
        love.graphics.polygon("fill", cx, cy - rr, cx + rr, cy, cx, cy + rr, cx - rr, cy)
    end

    love.graphics.setColor(0.96, 0.96, 0.98, a or 1)
    love.graphics.print(label, ix + iconW + gap, by + 3)
end

function CombatPanel:drawItemGrid()
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.7, 0.72, 0.8)
    love.graphics.printf("Items", self.x, self.gridY - 22, self.w, "center")

    local isPartyTurn = self.view.isPartyTurn
    local items = self.view.items or {}
    local NAME_H = 16
    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        local item = items[i]
        local armed = item and item == self.view.armedItem
        -- An ability the actor can't pay for is treated like an unusable slot: grayed out, with
        -- its cost badge flipped red (below) to point at the reason. `unaffordable` gates that red
        -- cue so it only fires on a party turn (off-turn slots dim for a different reason).
        local affordable = self:canAfford(item)
        local depleted = item ~= nil and Combat.isDepleted(item)
        local usable = item and item.activeAbility ~= nil and isPartyTurn and affordable and not depleted
        local unaffordable = item and item.activeAbility ~= nil and isPartyTurn and not affordable

        -- Slot plate.
        love.graphics.setColor(0.16, 0.17, 0.22, isPartyTurn and 1 or 0.5)
        love.graphics.rectangle("fill", sx, sy, sw, sh, 5, 5)

        if item then
            local dim = (not usable) and 0.45 or 1
            local ab = item.activeAbility

            -- Icon fills the slot; the badges and name overlay its corners/bottom.
            local sprite = item.sprite
            local icx, icy = sx + sw / 2, sy + sh / 2
            if type(sprite) == "userdata" then
                love.graphics.setColor(dim, dim, dim)
                local iw, ih = sprite:getDimensions()
                local scale = math.min((sw - 8) / iw, (sh - 8) / ih)
                love.graphics.draw(sprite, icx, icy, 0, scale, scale, iw / 2, ih / 2)
            else
                -- Art missing: a rounded placeholder with the item's initial.
                local ph = sh - 10
                love.graphics.setColor(0.55 * dim, 0.55 * dim, 0.60 * dim)
                love.graphics.rectangle("fill", icx - ph / 2, sy + 5, ph, ph, 5, 5)
                love.graphics.setFont(self.headFont)
                love.graphics.setColor(dim, dim, dim)
                love.graphics.printf((item.name or "?"):sub(1, 1), icx - ph / 2, icy - 12, ph, "center")
            end

            -- Name band overlaid along the bottom, single line scaled to fit.
            love.graphics.setColor(0, 0, 0, 0.6 * dim)
            love.graphics.rectangle("fill", sx + 1, sy + sh - NAME_H, sw - 2, NAME_H - 1, 0, 0, 5, 5)
            love.graphics.setFont(self.slotFont)
            local name = item.name or "?"
            local nw = self.slotFont:getWidth(name)
            local sc = math.min(1, (sw - 8) / nw)
            local nh = self.slotFont:getHeight() * sc
            love.graphics.setColor(0.94 * dim + 0.05, 0.94 * dim + 0.05, 0.96 * dim + 0.05)
            love.graphics.print(name, sx + sw / 2 - (nw * sc) / 2,
                sy + sh - NAME_H + (NAME_H - nh) / 2, 0, sc, sc)

            -- Stack count ("xN") for a stackable consumable, in a pill just above the name band so
            -- it clears the top-corner cost/speed badges. Shown for any real stack (>1) and for a
            -- spent one (x0, tinted red) so an empty-but-kept slot reads as out of stock.
            local qty = item.quantity or 1
            if qty ~= 1 then
                love.graphics.setFont(self.smallFont)
                local label = "x" .. qty
                local tw = self.smallFont:getWidth(label)
                local bw, bh = tw + 8, 15
                local bx, by = sx + sw - 3 - bw, sy + sh - NAME_H - bh - 1
                love.graphics.setColor(0.06, 0.07, 0.10, 0.85 * dim)
                love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)
                if qty <= 0 then love.graphics.setColor(WARN_COLOR[1], WARN_COLOR[2], WARN_COLOR[3], 1)
                else love.graphics.setColor(0.96, 0.96, 0.98, dim) end
                love.graphics.print(label, bx + 4, by + 1)
            end

            -- Cost (top-left) + speed (top-right), overlaid for ability items only.
            if ab then
                if ab.cost then
                    -- Cost badge: normally tinted by resource and dimmed with the slot; when the
                    -- actor can't afford it, flip to red and draw at full alpha so it reads as the
                    -- reason the slot is grayed out.
                    local c = unaffordable and WARN_COLOR or (RES_COLOR[ab.cost.stat] or COST_FALLBACK)
                    self:drawBadge(sx, sy, sw, "left", "dot", ab.cost.amount, c, unaffordable and 1 or dim)
                end
                if ab.speed then
                    self:drawBadge(sx, sy, sw, "right", "hourglass", ab.speed, SPEED_COLOR, dim)
                end
            end
        end

        -- Border: armed strike (red) / armed support (green), hovered (gold),
        -- usable (blue), else idle.
        if armed then
            if Combat.isSupportAbility(item.activeAbility) then
                love.graphics.setColor(0.35, 0.85, 0.40) -- support armed (heal / buff)
            else
                love.graphics.setColor(0.85, 0.35, 0.35) -- offensive armed (strike / trap)
            end
        elseif usable and self.hoverIndex == i then love.graphics.setColor(0.95, 0.85, 0.55)
        elseif usable then love.graphics.setColor(0.4, 0.6, 0.85)
        else love.graphics.setColor(0.35, 0.37, 0.45) end
        love.graphics.setLineWidth(armed and 2 or 1)
        love.graphics.rectangle("line", sx, sy, sw, sh, 5, 5)
        love.graphics.setLineWidth(1)
    end

    -- Adjacency connector lines over the current unit's grid, so item-to-item bonuses (a Fire
    -- Stone's aura, Omnislash scaling off adjacent weapons, Rain of Arrows' bow requirement) read
    -- at a glance -- tinted by relationship kind to match the loadout legend.
    self:drawAdjacencyLinks()
end

-- Line tint per adjacency relationship kind (see Combat.adjacencyLinks / ui/inventory_grid.lua).
local LINK_COLOR = {
    aura        = { 0.95, 0.55, 0.28 },
    boost       = { 0.55, 0.78, 1.00 },
    requirement = { 0.70, 0.88, 0.45 },
}

function CombatPanel:drawAdjacencyLinks()
    local char = self.view.itemOwner
    if not char then return end
    love.graphics.setLineWidth(2)
    for _, link in ipairs(Combat.adjacencyLinks(char)) do
        local c = LINK_COLOR[link.kind] or { 0.8, 0.8, 0.8 }
        local ax, ay, aw, ah = self:slotRect(link.from)
        local bx, by, bw, bh = self:slotRect(link.to)
        love.graphics.setColor(c[1], c[2], c[3], 0.85)
        love.graphics.line(ax + aw / 2, ay + ah / 2, bx + bw / 2, by + bh / 2)
        love.graphics.circle("fill", ax + aw / 2, ay + ah / 2, 3)
        love.graphics.circle("fill", bx + bw / 2, by + bh / 2, 3)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Input  (mouse; keyboard/gamepad item arming is handled by the battle state)
-- ---------------------------------------------------------------------------

-- Returns the ability item under a usable, hovered slot (else nil). An ability the actor can't
-- afford is not "usable" here, so hovering it won't preview the timeline and clicking won't arm it
-- -- matching its grayed-out slot (the hover item tooltip via itemAt still explains why).
function CombatPanel:usableItemAt(px, py)
    if not self.view.isPartyTurn then return nil end
    local i = self:slotIndexAt(px, py)
    local item = i and (self.view.items or {})[i]
    if item and item.activeAbility and self:canAfford(item) and not Combat.isDepleted(item) then
        return item, i
    end
    return nil
end

-- The inventory item under the cursor (any slot, regardless of usability / whose turn it is),
-- or nil. Drives the hover item tooltip, which details passive items and off-turn slots too --
-- unlike usableItemAt, which gates on a party turn + an active ability for arm/preview.
function CombatPanel:itemAt(px, py)
    local i = self:slotIndexAt(px, py)
    return i and (self.view.items or {})[i] or nil
end

-- The status instance whose turn-strip badge is under (px, py), or nil (drives the shared
-- status tooltip). Skips preview ghosts, which don't draw badges.
function CombatPanel:statusAt(px, py)
    for _, e in ipairs(self:entryLayout()) do
        if not e.entry.preview then
            for _, r in ipairs(self:statusBadgeRects(e.entry.unit, e.x, e.w, e.y)) do
                if px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h then
                    return r.st
                end
            end
        end
    end
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
