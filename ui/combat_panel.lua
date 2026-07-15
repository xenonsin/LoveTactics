-- Right-side combat HUD: the turn-order strip (portraits + resource bars) and the current
-- character's item grid. Persistent (not a modal) and owned by states/battle.lua, which
-- routes input to it and feeds it a per-frame view via setView. Follows the project's
-- three-input standard: mouse hover/click on item slots here, while the battle state maps
-- keyboard number keys and the gamepad to the same arm/cancel actions.
--
-- Layout (per the design sketch): the turn-order strip fills the panel top-down but is
-- BOTTOM-aligned so the current turn sits just above the item grid at the very bottom.
-- A long order (summons, big encounters) overflows the strip, so it scrolls: `scroll` counts
-- entries hidden off the bottom, i.e. how far toward later turns the window has walked. It
-- re-anchors to the acting unit whenever the turn changes.
--
--   local panel = CombatPanel.new(combat, {
--       onActivateItem = function(item, index) ... end,  -- slot clicked (arm / toggle)
--       onHoverItem    = function(item_or_nil) ... end,  -- hover changed (drives preview)
--   })
--   panel:setView({ order = {units}, current = unit, isPartyTurn = bool,
--                   items = {inventory}, armedItem = item_or_nil })
--   panel:draw(); panel:mousemoved(x, y); panel:mousepressed(x, y, button)
--   panel:wheelmoved(dx, dy)  -- caller gates on panel:contains(mouseX, mouseY)

local Scale = require("scale")
local Combat = require("models.combat")
local AdjacencyLinks = require("ui.adjacency_links")
local StatusBadge = require("ui.status_badge")

local CombatPanel = {}
CombatPanel.__index = CombatPanel

local PANEL_W = 320
CombatPanel.WIDTH = PANEL_W -- so states can reserve the same right-side margin
local SLIM_H = 34      -- a non-current turn card: small portrait, name, one thin HP bar (no numbers)
local CURRENT_H = 82   -- the acting unit's card: taller, larger portrait, full numbered HP/MP/SP
local ENTRY_GAP = 6
local NUM_GUTTER = 20  -- left column holding each card's turn number, kept clear of the portrait
local CURRENT_TOP_GAP = 24 -- extra room above the acting card for its "Current Turn" caption
-- Item slots are rectangular (wider than tall) and kept compact so the turn-order
-- strip above them gets the bulk of the panel height.
local SLOT_W = 96
local SLOT_H = 58
local SLOT_GAP = 6
local COLS, ROWS = 3, 3
local SCROLL_STEP = 1 -- turn-strip entries per wheel notch (entries are tall; one reads best)
local CARD_SPEED = 12 -- exponential ease rate of a card sliding to its new slot as the order reshuffles

-- Resource bars drawn per turn-strip entry, in order (skipped when a resource's max is 0).
local RESOURCES = {
    { key = "health",  color = { 0.35, 0.80, 0.35 } },
    { key = "mana",    color = { 0.35, 0.55, 0.95 } },
    { key = "stamina", color = { 0.90, 0.75, 0.30 } },
}

-- Short tag drawn beside each turn-strip bar (tinted with the pool colour), so a bar reads without
-- relying on colour alone -- and so the value beside it isn't mistaken for a different pool.
local BAR_LABELS = { health = "HP", mana = "MP", stamina = "SP" }

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
-- `reserved` (a share of the pool committed to sustaining a summon) is carved off the far end as a
-- dimmed tail; the track still spans the pool's true maximum, so the usable fill visibly shrinks.
local function drawResourceBar(x, y, w, h, cur, max, color, delta, lethal, reserved)
    delta = delta or 0
    local ratio = (max > 0) and math.max(0, math.min(1, cur / max)) or 0
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x, y, w, h, 2, 2)
    if reserved and reserved > 0 and max > 0 then
        local resW = w * (reserved / max)
        love.graphics.setColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 0.7)
        love.graphics.rectangle("fill", x + w - resW, y, resW, h, 2, 2)
    end
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
    self.onWait = opts.onWait -- the long Wait/Focus/Defend button under the item grid

    self.headFont = love.graphics.newFont(16)
    self.nameFont = love.graphics.newFont(14)
    self.smallFont = love.graphics.newFont(12)
    self.slotFont = love.graphics.newFont(11)  -- item name inside a grid slot

    self.x = Scale.WIDTH - PANEL_W
    self.w = PANEL_W

    -- Item grid: 3x3, centred horizontally. A long Wait button sits under it at the very bottom,
    -- so the grid is lifted to make room (button height + a gap + the bottom margin).
    self.gridW = COLS * SLOT_W + (COLS - 1) * SLOT_GAP
    self.gridH = ROWS * SLOT_H + (ROWS - 1) * SLOT_GAP
    self.gridX = self.x + math.floor((PANEL_W - self.gridW) / 2)
    -- Wait/Focus/Defend button: a bar the width of the grid, pinned to the panel bottom.
    self.waitBtn = { x = self.gridX, w = self.gridW, h = 34 }
    self.waitBtn.y = Scale.HEIGHT - 16 - self.waitBtn.h
    self.waitHover = false
    self.gridY = self.waitBtn.y - 10 - self.gridH
    -- Turn strip lives above the item grid.
    self.stripTop = 44
    self.stripBottom = self.gridY - 20

    self.view = { order = {}, items = {}, isPartyTurn = false }
    self.hoverIndex = nil
    self.hoverUnit = nil
    self.scroll = 0 -- turn-strip entries scrolled off the bottom (0 = the actor is at the bottom)
    -- Turn-strip animation (fed by update): each card's eased Y so it slides to its new slot as the
    -- order reshuffles, plus the bookkeeping to fade a just-fallen unit's card out in place.
    self.cardY = {}       -- unit -> eased Y
    self.lastLayout = {}  -- unit -> { entry, y, h } last laid out, to seed a fading card
    self.dyingCards = {}  -- unit -> { entry, y, h } fading to black on death
    return self
end

-- The HP value the strip should show for `unit`: the fx controller's lagging value (so a strip HP
-- bar drains in step with the board) when one is wired, else the true current.
function CombatPanel:shownHealth(unit)
    if self.fx then return self.fx:displayHp(unit) end
    return unit.char.stats.health.current
end

-- Ease each card toward its laid-out slot and retire cards that have left the order. The acting
-- unit's (tall) card is snapped, not eased, so it stays registered inside the framed active panel;
-- the upcoming slim cards slide as the order flows. A unit that just died keeps a card fading to
-- black in place (dyingCards) until its death fade ends.
function CombatPanel:update(dt)
    local layout = self:entryLayout()
    local present = {}
    local moving = false
    for _, e in ipairs(layout) do
        if not e.entry.preview then
            local u = e.entry.unit
            present[u] = true
            self.lastLayout[u] = { entry = e.entry, y = e.y, h = e.h }
            if u == self.view.current then
                self.cardY[u] = e.y -- snapped to the framed slot
            else
                local cur = self.cardY[u] or e.y
                local ny = cur + (e.y - cur) * math.min(1, dt * CARD_SPEED)
                if math.abs(e.y - ny) > 0.5 then moving = true end
                self.cardY[u] = ny
            end
        end
    end
    for u in pairs(self.cardY) do
        if not present[u] then
            if self.fx and self.fx:deathFade(u) and self.lastLayout[u] then
                self.dyingCards[u] = self.lastLayout[u]
            end
            self.cardY[u] = nil
        end
    end
    for u in pairs(self.dyingCards) do
        if not (self.fx and self.fx:deathFade(u)) then self.dyingCards[u] = nil end
    end
    for u in pairs(self.lastLayout) do
        if not present[u] and not self.dyingCards[u] then self.lastLayout[u] = nil end
    end
    -- Cards still sliding (or a death card fading) means the reshuffle isn't done; the battle state
    -- holds the next unit's action until this clears, so a turn never resolves out from under it.
    self._cardsMoving = moving or (next(self.dyingCards) ~= nil)
end

-- Have the turn-strip cards finished reshuffling into their new slots? The battle state gates an
-- auto-resolving turn (enemy AI, a channel going off) on this so the animation always keeps up.
function CombatPanel:cardsSettled()
    return not self._cardsMoving
end

-- Feed the per-frame render data (computed by the battle state). A new actor re-anchors the
-- turn strip to the bottom, so each turn opens showing whoever is acting now.
function CombatPanel:setView(view)
    view = view or { order = {}, items = {}, isPartyTurn = false }
    if view.current ~= self.view.current then self.scroll = 0 end
    self.view = view
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

-- Why the current actor can't activate `item` right now (an unpayable cost, a spent stack, a
-- missing adjacent item), or nil when it can. Passive items report nil -- they're inert, not
-- blocked. Drives the grayed-out slot, its red badge and the refused click.
function CombatPanel:blockReason(item)
    return Combat.itemBlockReason(self.view.current, item)
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
    self:drawWaitButton()
    love.graphics.setColor(1, 1, 1)
end

-- The long Wait button under the item grid. Its label mirrors the acting unit's wait behavior
-- (item-swapped Focus / Defend, else Wait), matching the old corner button. Enabled only on a party
-- turn; brightens under the cursor. The battle state supplies onWait and reads waitHover (set in
-- mousemoved) to preview the delay slot on the timeline.
function CombatPanel:drawWaitButton()
    local b = self.waitBtn
    local enabled = self.view.isPartyTurn
    local hot = enabled and self.waitHover
    local label = "Wait"
    if self.view.current then
        local kind = Combat.waitBehavior(self.view.current).kind
        label = (kind == "focus" and "Focus") or (kind == "defend" and "Defend")
            or (kind == "overwatch" and "Overwatch") or "Wait"
    end
    if enabled then love.graphics.setColor(hot and 0.24 or 0.18, hot and 0.30 or 0.24, hot and 0.42 or 0.34)
    else love.graphics.setColor(0.14, 0.15, 0.18) end
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6, 6)
    if enabled then love.graphics.setColor(0.5, 0.65, 0.85) else love.graphics.setColor(0.3, 0.32, 0.38) end
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 6, 6)
    if enabled then love.graphics.setColor(0.9, 0.94, 1) else love.graphics.setColor(0.5, 0.52, 0.58) end
    love.graphics.setFont(self.nameFont)
    love.graphics.printf(label, b.x, b.y + b.h / 2 - 9, b.w, "center")
end

-- Is (px, py) over the Wait button?
function CombatPanel:overWait(px, py)
    local b = self.waitBtn
    return px >= b.x and px <= b.x + b.w and py >= b.y and py <= b.y + b.h
end

-- How many entries fit between stripTop and stripBottom, and how far the strip can scroll
-- before the last entry sits at the bottom.
function CombatPanel:visibleCount()
    -- Slim-height estimate: the most cards that could show (all non-current). Drives the scroll
    -- limit and the scrollbar thumb. entryLayout does the exact, variable-height fit and clips at
    -- stripTop, so a small over-estimate here only ever leaves the top entries reachable by scroll.
    local span = self.stripBottom - self.stripTop
    return math.max(1, math.floor((span + ENTRY_GAP) / (SLIM_H + ENTRY_GAP)))
end

function CombatPanel:maxScroll()
    return math.max(0, #(self.view.order or {}) - self:visibleCount())
end

-- The on-screen rect of each visible turn-strip entry, shared by draw + hover hit-testing.
-- Each entry carries its turn-order number (`num`): 1 = acting now, matching the board token
-- (ui/battle_map.lua) so the player can tie a strip row to a unit at a glance. Preview ghosts
-- don't consume a number (they're a hypothetical slot, not a live position), so the numbers
-- stay aligned with the board's live turn order.
--
-- Only the `scroll`..`scroll + visibleCount` window is laid out, but numbering walks the whole
-- order so a scrolled-to entry keeps the #N its board token shows.
function CombatPanel:entryLayout()
    local out = {}
    local entries = self.view.order or {}
    -- The order shrinks as units die and grows with summons/preview ghosts, so re-clamp here
    -- rather than trusting the offset left by the last scroll input.
    self.scroll = math.max(0, math.min(self.scroll, self:maxScroll()))
    local turnNo = 0
    -- Bottom-pinned: the first visible entry sits at stripBottom (just above the item grid) and the
    -- strip grows upward. Heights vary -- the acting unit's card is tall (CURRENT_H), every other is
    -- slim -- so we walk real heights up from the bottom and stop once a card won't clear stripTop.
    local y = self.stripBottom
    for i, entry in ipairs(entries) do
        local num
        if not entry.preview then
            turnNo = turnNo + 1
            num = turnNo
        end
        if i > self.scroll then
            local isCurrent = (entry.unit == self.view.current) and not entry.preview
            local h = isCurrent and CURRENT_H or SLIM_H
            local top = y - h
            if top < self.stripTop then break end
            out[#out + 1] = { entry = entry, num = num, x = self.x + 8, y = top, w = self.w - 16, h = h }
            -- Leave extra room above the acting card so its "Current Turn" caption has somewhere to sit.
            y = top - (isCurrent and CURRENT_TOP_GAP or ENTRY_GAP)
        end
    end
    return out
end

function CombatPanel:drawTurnStrip()
    self:drawActivePanel() -- the frame tying the acting card to the grid, drawn behind the cards
    for _, e in ipairs(self:entryLayout()) do
        local y = e.y
        if not e.entry.preview and self.cardY[e.entry.unit] then
            y = self.cardY[e.entry.unit] -- eased slot (slides as the order reshuffles)
        end
        self:drawCard(e.entry, y, e.num, e.h)
    end
    -- A just-fallen unit's card, fading to black in place before it's gone (it has already left the
    -- live order, so it isn't in entryLayout above).
    for u, dc in pairs(self.dyingCards) do
        local fade = (self.fx and self.fx:deathFade(u)) or 0
        self:drawCard(dc.entry, dc.y, nil, dc.h)
        love.graphics.setColor(0, 0, 0, fade)
        love.graphics.rectangle("fill", self.x + 8, dc.y, self.w - 16, dc.h, 6, 6)
    end
    self:drawScrollBar()
end

-- Draw one turn-strip card at (its left is self.x + 8) row-top `y`, applying the struck unit's hit
-- rumble (a translated shake) and flash (a red overlay) so a blow reads on the timeline card exactly
-- as it does on the board sprite. Preview ghosts and un-struck cards just draw plainly.
function CombatPanel:drawCard(entry, y, num, h)
    local u = not entry.preview and entry.unit
    local dx, dy, flash = 0, 0, 0
    if u and self.fx then
        dx, dy = self.fx:cardShake(u)
        flash = self.fx:cardFlash(u)
    end
    if dx ~= 0 or dy ~= 0 then
        love.graphics.push()
        love.graphics.translate(dx, dy)
    end
    self:drawEntry(entry, y, num, h)
    if flash > 0 then
        love.graphics.setColor(1.0, 0.4, 0.35, flash * 0.45)
        love.graphics.rectangle("fill", self.x + 8, y, self.w - 16, h, 6, 6)
    end
    if dx ~= 0 or dy ~= 0 then love.graphics.pop() end
end

-- A single framed module wrapping the acting unit's (tall) card and the action grid below it, so the
-- current turn reads as "this unit and its actions" rather than a card floating over a separate grid.
-- Drawn behind both: the card plate and the grid slots land on top. When the actor is scrolled out of
-- view the frame simply starts at the Actions header, still bracketing the grid.
function CombatPanel:drawActivePanel()
    local cardTop
    for _, e in ipairs(self:entryLayout()) do
        if (e.entry.unit == self.view.current) and not e.entry.preview then cardTop = e.y break end
    end
    local x, w = self.x + 5, self.w - 10
    -- With the actor in view the frame opens above its card to hold the "Current Turn" caption;
    -- scrolled out, it just brackets the grid from the Actions header.
    local top = cardTop and (cardTop - 22) or (self.gridY - 20)
    local bottom = self.gridY + self.gridH + 8
    love.graphics.setColor(0.15, 0.17, 0.22, 0.55)
    love.graphics.rectangle("fill", x, top, w, bottom - top, 9, 9)
    love.graphics.setColor(0.95, 0.85, 0.55, 0.32)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, top, w, bottom - top, 9, 9)
    if cardTop then
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.95, 0.85, 0.55, 0.85)
        love.graphics.printf("Current Turn", x, top + 4, w, "center")
    end
end

-- A thin track + thumb down the strip's right edge, drawn only when the order overflows. It is
-- the affordance that says "there are later turns up there" and shows where the window sits.
function CombatPanel:drawScrollBar()
    local max = self:maxScroll()
    if max == 0 then return end
    local total = #(self.view.order or {})
    local bx, bw = self.x + self.w - 5, 3
    local by, bh = self.stripTop, self.stripBottom - self.stripTop

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", bx, by, bw, bh, 2, 2)

    -- The window covers visibleCount/total of the order; scroll 0 pins the thumb to the bottom,
    -- because the strip counts upward from "now".
    local thumbH = math.max(24, bh * (self:visibleCount() / total))
    local t = self.scroll / max
    love.graphics.setColor(0.95, 0.85, 0.55, 0.75)
    love.graphics.rectangle("fill", bx, by + (1 - t) * (bh - thumbH), bw, thumbH, 2, 2)
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
    local bw, bh, gap = 18, 14, 3
    local out = {}
    local x = ex + ew - 40
    for i = #statuses, 1, -1 do
        x = x - bw
        out[#out + 1] = { st = statuses[i], x = x, y = ey + 4, w = bw, h = bh }
        x = x - gap
    end
    return out
end

-- The portrait square (sprite, or a coloured letter box as a fallback) at (px, py), size ps.
function CombatPanel:drawPortrait(unit, px, py, ps, a)
    local sprite = unit.char.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1, a)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(ps / sw, ps / sh)
        love.graphics.draw(sprite, px + ps / 2, py + ps / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        if unit.side == "party" then love.graphics.setColor(0.35, 0.55, 0.85, a)
        else love.graphics.setColor(0.75, 0.35, 0.32, a) end
        love.graphics.rectangle("fill", px, py, ps, ps, 4, 4)
        local big = ps >= 48
        love.graphics.setFont(big and self.headFont or self.smallFont)
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.printf((unit.char.name or "?"):sub(1, 1), px, py + ps / 2 - (big and 10 or 7), ps, "center")
    end
end

-- Turn-order number in the card's left gutter -- deliberately clear of the portrait so it never
-- hides the face -- vertically centred, larger and gold on the acting card. #1 = acting now, matching
-- the board token (ui/battle_map.lua drawTurnNumber) so the same #N points at the same unit on both.
function CombatPanel:drawTurnNumber(num, cardX, cardTop, cardH, isCurrent)
    if not num then return end
    local font = isCurrent and self.headFont or self.nameFont
    love.graphics.setFont(font)
    if isCurrent then love.graphics.setColor(0.98, 0.88, 0.5)
    else love.graphics.setColor(0.82, 0.85, 0.95, 0.9) end
    love.graphics.printf(tostring(num), cardX + 1, cardTop + cardH / 2 - font:getHeight() / 2, NUM_GUTTER - 2, "center")
end

-- The acting unit's full pool stack (HP/MP/SP, each max>0), stacked from topY: a colour-tinted
-- HP/MP/SP tag, the bar, and the value ("cur / max", or "cur -> after / max" under a preview) in a
-- shared right-hand column so the three rows align. This detail is the current card's alone -- slim
-- cards show just a thin HP bar -- so the numbers only appear where an action budget is being read.
function CombatPanel:drawPoolBars(unit, rx, rw, topY)
    local pv = self.view.preview and self.view.preview[unit]
    local rows = {}
    for _, res in ipairs(RESOURCES) do
        local stat = unit.char.stats[res.key]
        if type(stat) == "table" and (stat.max or 0) > 0 then
            -- Damage/heal lands on HP; a cast's cost and a summon's reservation both come out of
            -- `current` (Combat.abilitySpend), so accumulate every spend row for this pool.
            local delta, lethal = 0, false
            if pv then
                if res.key == "health" then delta = (pv.heal or 0) - (pv.damage or 0); lethal = pv.lethal end
                for _, s in ipairs(pv.spend or {}) do
                    if s.stat == res.key then delta = delta - (s.amount or 0) end
                end
            end
            -- Draw against the EFFECTIVE ceiling (base max plus any carried resource-passive):
            -- unreservedMax folds in char.maxBonus; adding the reserved amount back recovers the full max.
            local reserved = Combat.reservedAmount(unit.char, res.key)
            local effMax = Combat.unreservedMax(unit.char, res.key) + reserved
            local curN, maxN = math.floor(stat.current + 0.5), math.floor(effMax + 0.5)
            local text = curN .. " / " .. maxN
            if delta ~= 0 then
                local after = math.max(0, math.min(effMax, stat.current + delta))
                text = curN .. " -> " .. math.floor(after + 0.5) .. " / " .. maxN
            end
            -- The HP bar fill drains from the lagging shown value; the numeric label stays the true
            -- current so it reads the real number the instant a hit lands.
            local barCur = res.key == "health" and self:shownHealth(unit) or stat.current
            rows[#rows + 1] = { res = res, cur = barCur, effMax = effMax,
                delta = delta, lethal = lethal, reserved = reserved, text = text }
        end
    end

    local barH, labelW = 9, 22
    love.graphics.setFont(self.smallFont)
    local valueColW = 2
    for _, r in ipairs(rows) do valueColW = math.max(valueColW, self.smallFont:getWidth(r.text) + 2) end
    for i, r in ipairs(rows) do
        local rowY = topY + (i - 1) * 13
        local c = r.res.color
        love.graphics.setColor(c[1] * 0.6 + 0.28, c[2] * 0.6 + 0.28, c[3] * 0.6 + 0.28, 0.95)
        love.graphics.print(BAR_LABELS[r.res.key], rx, rowY + (barH - self.smallFont:getHeight()) / 2)
        local barX = rx + labelW
        local barW = rw - labelW - valueColW - 6
        drawResourceBar(barX, rowY, barW, barH, r.cur, r.effMax, r.res.color, r.delta, r.lethal, r.reserved)
        love.graphics.setColor(0.94, 0.95, 0.98)
        love.graphics.printf(r.text, rx + rw - valueColW, rowY + (barH - self.smallFont:getHeight()) / 2,
            valueColW, "right")
    end
end

function CombatPanel:drawEntry(entry, ey, num, h)
    local unit = entry.unit
    local isPreview = entry.preview
    local isCurrent = (unit == self.view.current) and not isPreview
    local isParty = unit.side == "party"
    local ex = self.x + 8
    local ew = self.w - 16
    -- Preview ghosts render faded, so this alpha multiplier dims everything below.
    local a = isPreview and 0.55 or 1

    -- Plate + border. The acting unit's card is opaque and gold-bordered (it owns the framed module
    -- behind it); ghosts are dashed; every other card sits quiet -- dimmer fill, a faint side-tinted
    -- edge -- so the strip reads as one bright current card above a column of muted upcoming turns.
    if isPreview then love.graphics.setColor(0.42, 0.38, 0.20, 0.40)
    elseif isCurrent then love.graphics.setColor(isParty and 0.20 or 0.36, isParty and 0.27 or 0.20, isParty and 0.38 or 0.20, 1)
    else love.graphics.setColor(isParty and 0.17 or 0.29, isParty and 0.22 or 0.17, isParty and 0.31 or 0.17, 0.72) end
    love.graphics.rectangle("fill", ex, ey, ew, h, 6, 6)

    love.graphics.setLineWidth(1)
    if isPreview then
        self:dashedRect(ex, ey, ew, h)
    elseif isCurrent then
        love.graphics.setColor(0.95, 0.85, 0.55)
        love.graphics.rectangle("line", ex, ey, ew, h, 6, 6)
    else
        if isParty then love.graphics.setColor(0.4, 0.6, 0.85, 0.35) else love.graphics.setColor(0.85, 0.45, 0.4, 0.35) end
        love.graphics.rectangle("line", ex, ey, ew, h, 6, 6)
    end

    -- Debug: the entry's initiative (0 = acting now), including the preview ghost's new value.
    -- Tagged with an hourglass -- the same time-to-act glyph as the speed badge -- so the number
    -- reads as an initiative timer, not a stat.
    if self.view.showInitiative and entry.initiative then
        love.graphics.setFont(self.smallFont)
        local text = string.format("%.1f", entry.initiative)
        local tw = self.smallFont:getWidth(text)
        local iconW, gap = 7, 3
        self:drawHourglass(ex + ew - 6 - tw - gap - iconW, ey + 4, iconW, 9, 0.98, 0.9, 0.6, 0.95)
        love.graphics.setColor(0.98, 0.9, 0.6, 0.95)
        love.graphics.printf(text, ex, ey + 3, ew - 6, "right")
    end

    -- Preview ghost: a hypothetical future slot, so it shows where the actor would land, not stats.
    if isPreview then
        local ps = h - 6
        self:drawPortrait(unit, ex + NUM_GUTTER, ey + 3, ps, a)
        local rx = ex + NUM_GUTTER + ps + 8
        love.graphics.setFont(self.nameFont)
        love.graphics.setColor(0.95, 0.85, 0.55, 0.95)
        love.graphics.print(unit.char.name or "?", rx, ey + 3)
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.9, 0.82, 0.6, 0.9)
        love.graphics.print(entry.previewLabel or "would act here", rx, ey + 18)
        return
    end

    -- The acting unit: a large portrait, the name in the heading font, and the full numbered pools.
    if isCurrent then
        local ps = h - 12
        self:drawTurnNumber(num, ex, ey, h, true)
        self:drawPortrait(unit, ex + NUM_GUTTER, ey + 6, ps, a)
        local rx = ex + NUM_GUTTER + ps + 10
        local rw = ex + ew - rx - 10
        love.graphics.setFont(self.headFont)
        love.graphics.setColor(0.97, 0.94, 0.72)
        love.graphics.print(unit.char.name or "?", rx, ey + 8)
        for _, r in ipairs(self:statusBadgeRects(unit, ex, ew, ey)) do
            StatusBadge.draw(r.st, r.x, r.y, r.w, r.h)
        end
        self:drawPoolBars(unit, rx, rw, ey + 34)
        return
    end

    -- A slim upcoming-turn card: small portrait, name, and one thin HP bar -- no numbers. The bar
    -- still carries the aimed-hit preview slice (an enemy about to be struck reads here), it just
    -- drops the readout; full pools are one hover (the tooltip) away.
    local ps = h - 6
    self:drawTurnNumber(num, ex, ey, h, false)
    self:drawPortrait(unit, ex + NUM_GUTTER, ey + 3, ps, a)
    local rx = ex + NUM_GUTTER + ps + 8
    local rw = ex + ew - rx - 8
    love.graphics.setFont(self.nameFont)
    love.graphics.setColor(0.9, 0.9, 0.94)
    love.graphics.print(unit.char.name or "?", rx, ey + 4)
    for _, r in ipairs(self:statusBadgeRects(unit, ex, ew, ey)) do
        StatusBadge.draw(r.st, r.x, r.y, r.w, r.h)
    end
    local hp = unit.char.stats.health
    if type(hp) == "table" and (hp.max or 0) > 0 then
        local pv = self.view.preview and self.view.preview[unit]
        local delta = pv and ((pv.heal or 0) - (pv.damage or 0)) or 0
        local reserved = Combat.reservedAmount(unit.char, "health")
        local effMax = Combat.unreservedMax(unit.char, "health") + reserved
        drawResourceBar(rx, ey + 22, rw, 6, self:shownHealth(unit), effMax, RESOURCES[1].color, delta, pv and pv.lethal, reserved)
    end
end

-- Small hourglass glyph (two triangles) for the speed badge, drawn in the given box.
function CombatPanel:drawHourglass(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    love.graphics.polygon("fill", x, y, x + w, y, x + w / 2, y + h / 2)
    love.graphics.polygon("fill", x + w / 2, y + h / 2, x, y + h, x + w, y + h)
end

-- Small padlock (shackle arc over a body) for the reserve badge: the resource this ability locks
-- away, told apart from the plain cost dot because it never comes back on its own.
function CombatPanel:drawLock(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    local cx, bodyTop = x + w / 2, y + h * 0.42
    love.graphics.setLineWidth(1.5)
    love.graphics.arc("line", "open", cx, bodyTop, w * 0.28, math.pi, 2 * math.pi)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("fill", x + w * 0.1, bodyTop, w * 0.8, h - h * 0.42, 1, 1)
end

-- A summoning circle with something bound inside it: the glyph for an ability whose creature is
-- still on the field, and so cannot be cast again until it falls. A ring around a core dot -- at
-- this size (9x10) a literal figure-in-a-circle silts up into a blob, while two concentric shapes
-- with clear space between them stay legible.
function CombatPanel:drawSummonRing(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    local cx, cy = x + w / 2, y + h / 2
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx, cy, math.min(w, h) * 0.46)
    love.graphics.setLineWidth(1)
    love.graphics.circle("fill", cx, cy, math.min(w, h) * 0.16)
end

-- Two stubs with a gap between them: a "broken link" glyph marking an adjacency requirement the
-- grid doesn't satisfy (a met one is drawn as a solid connector line over the grid instead).
function CombatPanel:drawBrokenLink(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y + h, x + w * 0.30, y + h * 0.58)
    love.graphics.line(x + w * 0.70, y + h * 0.42, x + w, y)
    love.graphics.setLineWidth(1)
end

-- A cost/speed corner badge: a dark pill with an icon and a label. `corner` is "left"
-- (top-left costs) or "right" (top-right speed); `iconKind` is "dot", "hourglass", "lock", "link"
-- or "ring". `row` stacks a badge under the previous one in the same corner (0 = top, the default).
function CombatPanel:drawBadge(sx, sy, sw, corner, iconKind, amount, color, a, row)
    love.graphics.setFont(self.smallFont)
    local label = tostring(amount)
    local tw = self.smallFont:getWidth(label)
    local iconW, gap, padX = 9, 3, 5
    local bw = padX + iconW + gap + tw + padX
    local bh = 18
    local pad = 3
    local bx = (corner == "right") and (sx + sw - pad - bw) or (sx + pad)
    local by = sy + pad + (row or 0) * (bh + 2)

    love.graphics.setColor(0.06, 0.07, 0.10, 0.82 * (a or 1))
    love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)

    local ix = bx + padX
    local iy = by + (bh - 10) / 2
    if iconKind == "hourglass" then
        self:drawHourglass(ix, iy, iconW, 10, color[1], color[2], color[3], a)
    elseif iconKind == "lock" then
        self:drawLock(ix, iy, iconW, 10, color[1], color[2], color[3], a)
    elseif iconKind == "link" then
        self:drawBrokenLink(ix, iy, iconW, 10, color[1], color[2], color[3], a)
    elseif iconKind == "ring" then
        self:drawSummonRing(ix, iy, iconW, 10, color[1], color[2], color[3], a)
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
    love.graphics.printf("Actions", self.x, self.gridY - 16, self.w, "center")

    local isPartyTurn = self.view.isPartyTurn
    local items = self.view.items or {}
    local NAME_H = 16

    -- Slot plates, then the adjacency connectors across them (a Fire Stone's aura, Omnislash
    -- scaling off adjacent weapons, Rain of Arrows' bow requirement), tinted by relationship kind
    -- to match the loadout legend. Both go down before the item contents, so a wire reads over the
    -- plate but never covers an icon, a badge or a name.
    love.graphics.setColor(0.16, 0.17, 0.22, isPartyTurn and 1 or 0.5)
    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        love.graphics.rectangle("fill", sx, sy, sw, sh, 5, 5)
    end
    self:drawAdjacencyLinks()

    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        local item = items[i]
        local armed = item and item == self.view.armedItem
        -- An ability the actor can't activate -- can't pay for, spent stack, missing the neighbor it
        -- requires -- is grayed out, and the badge naming the reason (below) is drawn red at full
        -- alpha to point at it. Only on a party turn: off-turn slots dim for a different reason, and
        -- the hover tooltip spells the reason out either way.
        local blocked = isPartyTurn and self:blockReason(item) or nil
        -- A Blink (moveBehavior) item is activatable too, even though it has no ability: clicking it
        -- toggles teleport movement rather than arming a cast.
        local isBlink = item and item.moveBehavior ~= nil
        local usable = item and (item.activeAbility ~= nil or isBlink) and isPartyTurn and not blocked

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

            -- What the cast takes (top-left, stacked downward) + speed (top-right), for ability
            -- items only. A badge whose demand is the one blocking the cast flips to red at full
            -- alpha, so it reads as the reason the slot is grayed out.
            if ab then
                local row = 0
                if ab.cost then
                    local short = blocked and blocked.kind == "cost"
                    local c = short and WARN_COLOR or (RES_COLOR[ab.cost.stat] or COST_FALLBACK)
                    self:drawBadge(sx, sy, sw, "left", "dot", ab.cost.amount, c, short and 1 or dim, row)
                    row = row + 1
                end
                -- A reservation is a cost too -- paid on the cast, then locked away for as long as
                -- what it summons lives -- so it earns its own badge under the cost, a padlock
                -- instead of the resource dot. Priced against the actor (a share of ITS maximum),
                -- falling back to the raw percentage when there's nobody to price it for.
                if ab.reserve then
                    local short = blocked and blocked.kind == "reserve"
                    local c = short and WARN_COLOR or (RES_COLOR[ab.reserve.stat] or COST_FALLBACK)
                    local res = self.view.current and Combat.abilityReserve(self.view.current, ab)
                    local label = res and res.amount
                        or (math.floor((ab.reserve.percent or 0) * 100 + 0.5) .. "%")
                    self:drawBadge(sx, sy, sw, "left", "lock", label, c, short and 1 or dim, row)
                    row = row + 1
                end
                if ab.speed then
                    self:drawBadge(sx, sy, sw, "right", "hourglass", ab.speed, SPEED_COLOR, dim)
                end
                -- An unmet adjacency requirement (Rain of Arrows with no bow beside it) names the
                -- missing neighbor in a red broken-link badge, tucked under the cost badges.
                if blocked and blocked.kind == "adjacency" then
                    local req = ab.requiresAdjacent
                    self:drawBadge(sx, sy, sw, "left", "link", req.tag or req.type or "item",
                        WARN_COLOR, 1, row)
                end
                -- The creature this ability called is still standing, so it cannot be cast again:
                -- a red summoning-ring badge under the cost badges says the ability is ACTIVE rather
                -- than unaffordable. A timed summon counts down in the badge instead (bare ticks, the
                -- same way every other duration in the game is quoted). The hover tooltip names it.
                if blocked and blocked.kind == "active" then
                    local left = blocked.summon.summonRemaining
                    local label = left and math.max(0, math.ceil(left)) or "Active"
                    self:drawBadge(sx, sy, sw, "left", "ring", label, WARN_COLOR, 1, row)
                end
            end
        end

        -- Border: armed strike (red) / armed support (green), a toggled-on Blink (violet), hovered
        -- (gold), usable (blue), else idle.
        local blinkOn = isBlink and self.view.current and self.view.current.blinkArmed
        if armed then
            if Combat.isSupportAbility(item.activeAbility) then
                love.graphics.setColor(0.35, 0.85, 0.40) -- support armed (heal / buff)
            else
                love.graphics.setColor(0.85, 0.35, 0.35) -- offensive armed (strike / trap)
            end
        elseif blinkOn then love.graphics.setColor(0.60, 0.45, 0.95) -- Blink toggled on (violet)
        elseif usable and self.hoverIndex == i then love.graphics.setColor(0.95, 0.85, 0.55)
        elseif usable then love.graphics.setColor(0.4, 0.6, 0.85)
        else love.graphics.setColor(0.35, 0.37, 0.45) end
        love.graphics.setLineWidth(armed and 2 or 1)
        love.graphics.rectangle("line", sx, sy, sw, sh, 5, 5)
        love.graphics.setLineWidth(1)
    end
end

-- The current unit's item-to-item relationships, as wires running behind its cards. Off turn the
-- whole grid dims, so the wires dim with it.
function CombatPanel:drawAdjacencyLinks()
    AdjacencyLinks.draw(self.view.itemOwner, function(i) return self:slotRect(i) end,
        { width = 3, alpha = self.view.isPartyTurn and 1 or 0.4 })
end

-- ---------------------------------------------------------------------------
-- Input  (mouse; keyboard/gamepad item arming is handled by the battle state)
-- ---------------------------------------------------------------------------

-- Returns the ability item under a usable, hovered slot (else nil). An ability the actor can't
-- activate right now is not "usable" here, so hovering it won't preview the timeline and clicking
-- won't arm it -- matching its grayed-out slot (the hover item tooltip via itemAt still explains why).
function CombatPanel:usableItemAt(px, py)
    if not self.view.isPartyTurn then return nil end
    local i = self:slotIndexAt(px, py)
    local item = i and (self.view.items or {})[i]
    -- A Blink (moveBehavior) item is clickable too: activating it toggles teleport movement. It has
    -- no ability cost, so blockReason never gates it.
    if item and (item.activeAbility or item.moveBehavior) and not self:blockReason(item) then
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
        self.waitHover = false
        return false
    end
    local item, i = self:usableItemAt(x, y)
    self:setHover(item, i, self:unitAt(x, y))
    self.waitHover = self.view.isPartyTurn and self:overWait(x, y) or false
    return true
end

-- Returns true when the click was inside the panel (consumed).
function CombatPanel:mousepressed(x, y, button)
    if button ~= 1 or not self:contains(x, y) then return false end
    if self.view.isPartyTurn and self:overWait(x, y) then
        if self.onWait then self.onWait() end
        return true
    end
    local item, i = self:usableItemAt(x, y)
    if item and self.onActivateItem then self.onActivateItem(item, i) end
    return true
end

-- Walk the turn strip by `n` entries (positive = toward later turns), clamped.
function CombatPanel:scrollBy(n)
    self.scroll = math.max(0, math.min(self.scroll + n, self:maxScroll()))
end

-- One screenful toward later turns, wrapping back to the acting unit at the far end. The gamepad
-- has a single spare button for the strip (the d-pad drives the board cursor), so it cycles
-- instead of paging both ways.
function CombatPanel:cyclePage()
    local max = self:maxScroll()
    if max == 0 then return end
    self.scroll = (self.scroll >= max) and 0 or math.min(self.scroll + self:visibleCount(), max)
end

-- Mouse wheel: walk the turn strip (dy > 0 = wheel up = later turns, since the strip is pinned
-- to "now" at the bottom and grows upward). The caller gates this on the cursor being over the
-- panel. Returns true when it consumed the event.
function CombatPanel:wheelmoved(_, dy)
    if dy == 0 or self:maxScroll() == 0 then return false end
    self:scrollBy(dy > 0 and SCROLL_STEP or -SCROLL_STEP)
    return true
end

return CombatPanel
