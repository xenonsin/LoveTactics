-- Right-side combat HUD: the turn-order strip (portraits + resource bars) and the current
-- character's item grid. Persistent (not a modal) and owned by states/battle.lua, which
-- routes input to it and feeds it a per-frame view via setView. Follows the project's
-- three-input standard: mouse hover/click on item slots here, while the battle state maps
-- keyboard number keys and the gamepad to the same arm/cancel actions.
--
-- Layout (per the design sketch): the turn-order strip fills the panel top-down but is
-- BOTTOM-aligned so the current turn sits just above the item grid at the very bottom.
-- The acting card is PINNED to the bottom -- it frames into the action grid below it, so it never
-- scrolls away. A long order (summons, big encounters) overflows the region ABOVE it, so that
-- region scrolls: `scroll` counts upcoming entries hidden off the bottom of it, i.e. how far
-- toward later turns the window has walked, while the current card stays put. Scroll re-anchors
-- to 0 (the nearest upcoming turns showing) whenever the turn changes.
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
local Glyphs = require("ui.glyphs")
local Colors = require("ui.colors")

local CombatPanel = {}
CombatPanel.__index = CombatPanel

local PANEL_W = 320
CombatPanel.WIDTH = PANEL_W -- so states can reserve the same right-side margin
local SLIM_H = 34      -- a non-current turn card: small portrait, name, one thin HP bar (no numbers)
local CURRENT_H = 82   -- the acting unit's card: taller, larger portrait, full numbered HP/MP/SP
local ENTRY_GAP = 4   -- gap between slim cards; kept tight so the strip fits 9 turns (current + 8) without scrolling
local NUM_GUTTER = 20  -- left column holding each card's turn number, kept clear of the portrait
local CURRENT_TOP_GAP = 24 -- extra room above the acting card for its "Current Turn" caption
-- Item slots are rectangular (wider than tall) and kept compact so the turn-order
-- strip above them gets the bulk of the panel height.
local SLOT_W = 96
local SLOT_H = 58
local SLOT_GAP = 6
local COLS, ROWS = 3, 3
-- A slot badge's pill: side padding, the glyph's width, the gap before its number, and the pill's
-- height (see drawBadgeAt). Named because badgeSize measures a badge the same way, for a caller that
-- must place one itself.
local BADGE_PAD_X, BADGE_ICON_W, BADGE_GAP, BADGE_H = 5, 9, 3, 18
local SCROLL_STEP = 1 -- turn-strip entries per wheel notch (entries are tall; one reads best)
local CARD_SPEED = 12 -- exponential ease rate of a card sliding to its new slot as the order reshuffles
local PROM_SPEED = 14 -- ease rate of a card's prominence (slim <-> tall current) as the turn passes
local SOLIDIFY_SPEED = 10 -- ease rate a just-committed preview ghost solidifies into its real card

-- Frame-rate-independent exponential approach toward `target` (stable regardless of frame time), and a
-- plain linear blend. Used for every turn-strip tween so the animation feels the same at any FPS.
local function approach(cur, target, k, dt) return cur + (target - cur) * (1 - math.exp(-k * dt)) end
local function lerp(a, b, t) return a + (b - a) * t end

-- Resource bars drawn per turn-strip entry, in order (skipped when a resource's max is 0). Health
-- has no fixed colour: it's filled with the unit's SIDE colour (blue ally / red foe), so a card's
-- HP bar says whose unit it is the same way the board token's does. Resolved per unit by barColor.
local RESOURCES = {
    { key = "health" },
    { key = "mana",    color = Colors.MANA },
    { key = "stamina", color = Colors.STAMINA },
}

-- The fill colour for `unit`'s `key` pool -- the side colour for health, the pool's own otherwise.
local function barColor(res, unit)
    return res.color or Colors.side(unit.side)
end

-- Short tag drawn beside each turn-strip bar (tinted with the pool colour), so a bar reads without
-- relying on colour alone -- and so the value beside it isn't mistaken for a different pool.
local BAR_LABELS = { health = "HP", mana = "MP", stamina = "SP" }

-- Cost badge tint per resource stat (falls back to a neutral grey for anything else). Health is
-- PARTY blue rather than a colour of its own: a cost badge only ever prices the player's own actor,
-- whose HP bar is blue, so "this spends your health" reads in the colour that health already has.
local RES_COLOR = { health = Colors.PARTY, mana = Colors.MANA, stamina = Colors.STAMINA }
local COST_FALLBACK = { 0.75, 0.75, 0.80 }
local SPEED_COLOR = { 0.95, 0.85, 0.55 } -- gold, matching the timeline/initiative accent
local WARN_COLOR = { 0.95, 0.40, 0.38 }  -- red cost badge on an ability the actor can't afford

-- How far the ray at angle `a` travels from a rectangle's centre before it meets the rectangle's
-- edge, given the half-extents. What makes the cooldown wedge below fill its slot corner-to-corner
-- without spilling: every vertex lands ON the boundary, so no clipping is needed. (A scissor can't do
-- this job here -- love.graphics.setScissor takes real window pixels, while everything in this file is
-- authored in the 1280x720 logical space, see scale.lua.)
local function edgeRadius(a, hw, hh)
    local c, s = math.abs(math.cos(a)), math.abs(math.sin(a))
    return math.min(c > 1e-6 and hw / c or math.huge, s > 1e-6 and hh / s or math.huge)
end

-- The recovery clock over a slot whose reflex is still recovering: a dark wedge covering the share of
-- the recovery still to run, sweeping clockwise from 12 o'clock and shrinking away as the reflex comes
-- back. Just the wedge: the ticks left ride in an hourglass badge its caller centres on it (see
-- drawItemGrid), so this stays a shape and the count stays a badge like every other number in a slot.
--
-- Drawn as a triangle fan over the slot RECTANGLE rather than one pie polygon, for two reasons: a
-- sector closes on itself at a full turn (the frame a fresh cooldown starts on) and love.math.triangulate
-- rejects that, and a fan lets each vertex ride the rectangle's edge. The rect's four corner angles are
-- folded into the sample list so a fan segment never cuts across one and leaves a corner uncovered.
local COOLDOWN_TINT = { 0.05, 0.06, 0.09, 0.66 }
local COOLDOWN_STEPS = 24 -- samples per full turn; the corners are added on top of these
local function drawCooldownSweep(x, y, w, h, frac)
    frac = math.max(0, math.min(1, frac))
    local cx, cy, hw, hh = x + w / 2, y + h / 2, w / 2, h / 2
    local a0 = -math.pi / 2                  -- 12 o'clock
    local a1 = a0 + 2 * math.pi * frac       -- clockwise: +y is down, so the sweep runs the right way

    local angles = {}
    for i = 0, COOLDOWN_STEPS do
        local a = a0 + (a1 - a0) * (i / COOLDOWN_STEPS)
        angles[#angles + 1] = a
    end
    for _, corner in ipairs({ math.atan2(hh, hw), math.atan2(hh, -hw),
                              math.atan2(-hh, -hw), math.atan2(-hh, hw) }) do
        -- atan2 answers in (-pi, pi]; lift the corner into the sweep's own range before testing it.
        while corner < a0 do corner = corner + 2 * math.pi end
        if corner < a1 then angles[#angles + 1] = corner end
    end
    table.sort(angles)

    love.graphics.setColor(COOLDOWN_TINT)
    for i = 2, #angles do
        local pa, na = angles[i - 1], angles[i]
        local pr, nr = edgeRadius(pa, hw, hh), edgeRadius(na, hw, hh)
        love.graphics.polygon("fill", cx, cy,
            cx + math.cos(pa) * pr, cy + math.sin(pa) * pr,
            cx + math.cos(na) * nr, cy + math.sin(na) * nr)
    end
end

-- Draw a resource bar with an optional preview `delta` (an aimed action's projected change): the
-- "after" fill in the pool colour, then the lost slice in red (delta < 0, brighter when lethal) or
-- the gained slice in green (delta > 0) beside it. Mirrors ui/tile_tooltip.lua's bar so the banner
-- preview reads the same as the tooltip. No delta = a plain fill.
-- `reserved` (a share of the pool committed to sustaining a summon) is carved off the far end as a
-- dimmed tail; the track still spans the pool's true maximum, so the usable fill visibly shrinks.
-- `alpha` (default 1) fades the whole bar, so a turn-strip card can cross-fade its slim HP bar out as
-- the full pool stack fades in while it grows into the frame.
local function drawResourceBar(x, y, w, h, cur, max, color, delta, lethal, reserved, alpha)
    delta = delta or 0
    alpha = alpha or 1
    local ratio = (max > 0) and math.max(0, math.min(1, cur / max)) or 0
    love.graphics.setColor(0, 0, 0, 0.5 * alpha)
    love.graphics.rectangle("fill", x, y, w, h, 2, 2)
    if reserved and reserved > 0 and max > 0 then
        local resW = w * (reserved / max)
        love.graphics.setColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 0.7 * alpha)
        love.graphics.rectangle("fill", x + w - resW, y, resW, h, 2, 2)
    end
    if delta ~= 0 and max > 0 then
        local afterRatio = math.max(0, math.min(1, (cur + delta) / max))
        if delta < 0 then
            love.graphics.setColor(color[1], color[2], color[3], 0.95 * alpha)
            love.graphics.rectangle("fill", x, y, w * afterRatio, h, 2, 2)
            -- The slice about to be lost is amber, not red: on an enemy's red HP bar a red slice
            -- would be invisible. Reads against every pool colour.
            local loseCol = lethal and Colors.LETHAL or Colors.PENDING
            love.graphics.setColor(loseCol[1], loseCol[2], loseCol[3], 0.95 * alpha)
            love.graphics.rectangle("fill", x + w * afterRatio, y, w * (ratio - afterRatio), h, 2, 2)
        else
            love.graphics.setColor(color[1], color[2], color[3], 0.95 * alpha)
            love.graphics.rectangle("fill", x, y, w * ratio, h, 2, 2)
            local gain = Colors.HEALING
            love.graphics.setColor(gain[1], gain[2], gain[3], 0.9 * alpha)
            love.graphics.rectangle("fill", x + w * ratio, y, w * (afterRatio - ratio), h, 2, 2)
        end
    else
        love.graphics.setColor(color[1], color[2], color[3], 0.95 * alpha)
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
    self.cardProm = {}    -- unit -> eased prominence 0..1 (1 = the tall framed current card)
    self.lastLayout = {}  -- unit -> { entry, y, h } last laid out, to seed a fading card
    self.dyingCards = {}  -- unit -> { entry, y, h } fading to black on death
    -- On a turn advance the outgoing actor's card MORPHS in place at its preview ghost's slot -- content
    -- fading up from the ghost -- rather than sweeping the tall card through the list. wasCurrent tracks
    -- who held the frame so the hand-off fires exactly once.
    self.solidify = {}    -- unit -> { t = 1..0, dashed = bool }, a card morphing in from its ghost
    self.lastGhostY = {}  -- unit -> last on-screen Y of its preview ghost (sticky until it acts), so the
                          -- morph solidifies at that exact (old-layout) slot rather than its new rank
    self.wasCurrent = nil -- the unit that held the framed slot last frame
    -- A turn advance plays out in two STAGED phases so it reads clearly instead of all at once:
    --   "out" -- the outgoing actor's preview solidifies into its real queue card while its big frame
    --            card fades out (frameFade); the incoming actor and the rest of the queue are frozen.
    --   "in"  -- once that finishes, the incoming actor drops into the frame and the queue reflows.
    -- (Hit reactions finish earlier still: the battle state holds the advance until fx settles.)
    self.phase = "idle"    -- "idle" | "out" | "in"
    self.snapOut = nil     -- a ghost-less outgoing to drop straight at its rank (no sweep from the frame)
    self.outgoingUnit = nil -- the actor leaving the frame during "out"
    self.frameFade = nil   -- { unit, t = 1..0 } the outgoing's big card fading out of the frame
    self.frameY = nil      -- current frame-slot top (where the big card sits), cached each update
    return self
end

-- The HP value the strip should show for `unit`: the fx controller's lagging value (so a strip HP
-- bar drains in step with the board) when one is wired, else the true current.
function CombatPanel:shownHealth(unit)
    if self.fx then return self.fx:displayHp(unit) end
    return unit.char.stats.health.current
end

-- The current-turn (tall) card is a FIXED anchor -- it never slides or grows; whoever is acting simply
-- occupies it. The motion is all in the queue: the outgoing actor's preview ghost MORPHS in place into
-- its real card (solidify), and the other upcoming cards slide to their new ranks. A unit that just died
-- keeps a card fading to black (dyingCards) until its death fade ends. The battle state holds the next
-- auto-turn until this settles (cardsSettled).
function CombatPanel:update(dt)
    local current = self.view.current

    -- Cache each preview ghost's on-screen Y (sticky until the unit next acts, so it survives the hold
    -- beat). A hand-off solidifies the outgoing card at THIS slot -- an empty preview slot in the frozen
    -- old layout -- so it never collides with a held card, and only a unit that had a preview morphs.
    for _, e in ipairs(self:entryLayout()) do
        if e.entry.preview then self.lastGhostY[e.entry.unit] = e.y end
    end

    -- Turn advanced: begin the STAGED hand-off (see the phase notes in new()). If the outgoing actor had
    -- a preview, phase "out" solidifies its real card at that ghost slot while its big frame card fades
    -- out and everything else is frozen; otherwise we skip straight to the "in" drop.
    if current ~= self.wasCurrent then
        local out = self.wasCurrent
        if out then
            self.outgoingUnit = out
            self.cardProm[out] = 0
            self.frameFade = { unit = out, t = 1 }
            local gy = self.lastGhostY[out]
            self.solidify[out] = { t = 1, dashed = gy ~= nil }
            -- With a ghost: phase "out" solidifies at that slot with the queue frozen. Without one (an
            -- enemy attacking from where it stood): skip to "in", but SNAP the outgoing straight to its
            -- new rank so its card never eases up out of the frame -- the big card only ever fades there.
            if gy then self.phase = "out"; self.cardY[out] = gy; self.snapOut = nil
            else self.phase = "in"; self.snapOut = out end
            self.lastGhostY[out] = nil
        else
            self.phase, self.outgoingUnit, self.frameFade, self.snapOut = "idle", nil, nil, nil
        end
        if current then self.lastGhostY[current] = nil end -- fresh turn: drop any stale ghost slot
        self.wasCurrent = current
    end

    local layout = self:entryLayout()
    self.frameY = nil
    for _, e in ipairs(layout) do
        if not e.entry.preview and e.entry.unit == current then self.frameY = e.y break end
    end

    -- Prominence: non-current cards decay to slim. The incoming current is held slim through "out",
    -- grows through "in", and sits full at "idle" -- so the big card only inflates as it drops in.
    for u, p in pairs(self.cardProm) do
        if u ~= current then
            local np = approach(p, 0, PROM_SPEED, dt)
            self.cardProm[u] = (np < 0.01) and nil or np
        end
    end
    if current then
        if self.phase == "out" then self.cardProm[current] = 0
        elseif self.phase == "in" then self.cardProm[current] = approach(self.cardProm[current] or 0, 1, PROM_SPEED, dt)
        else self.cardProm[current] = 1 end
    end

    local present = {}
    local moving = false
    for _, e in ipairs(layout) do
        if not e.entry.preview then
            local u = e.entry.unit
            present[u] = true
            self.lastLayout[u] = { entry = e.entry, y = e.y, h = e.h }
            if self.cardY[u] == nil then self.cardY[u] = e.y end
            if u == self.snapOut then
                self.cardY[u] = e.y -- land straight at its rank (no sweep from the frame); fades in there
                self.snapOut = nil
            elseif self.phase ~= "out" then
                -- "in"/"idle": ease toward the new layout. During "out" everything is frozen -- only the
                -- outgoing card's in-place morph (solidify + frame fade) plays, so it reads on its own.
                local ny = approach(self.cardY[u], e.y, CARD_SPEED, dt)
                if math.abs(e.y - ny) > 0.5 then moving = true end
                self.cardY[u] = ny
            end
        end
    end

    if self.frameFade then
        self.frameFade.t = approach(self.frameFade.t, 0, SOLIDIFY_SPEED, dt)
        if self.frameFade.t < 0.02 then self.frameFade = nil end
    end
    for u, sd in pairs(self.solidify) do
        sd.t = approach(sd.t, 0, SOLIDIFY_SPEED, dt)
        if sd.t < 0.02 then self.solidify[u] = nil else moving = true end
    end
    for u, p in pairs(self.cardProm) do if u ~= current and p > 0.02 then moving = true end end

    -- Advance the phase: "out" holds until the morph + frame fade finish, then "in" drops the incoming
    -- card and reflows the queue, then back to "idle" once everything has settled.
    if self.phase == "out" then
        moving = true
        if not self.frameFade and next(self.solidify) == nil then self.phase = "in" end
    elseif self.phase == "in" then
        if current and (self.cardProm[current] or 0) < 0.995 then moving = true end
        if not moving then self.phase = "idle" end
    end

    -- A unit that just left the order: hold its card as a dying card while the fx controller either is
    -- fading it out (deathFade) or has not yet PLAYED the blow that felled it (awaiting -- a counter,
    -- resolved in the model but still a beat away on screen). Without the latter the card would blink
    -- out the instant the model killed it and never fade at all.
    for u in pairs(self.cardY) do
        if not present[u] then
            if self.fx and (self.fx:deathFade(u) or self.fx:awaiting(u)) and self.lastLayout[u] then
                self.dyingCards[u] = self.lastLayout[u]
            end
            self.cardY[u] = nil
        end
    end
    for u in pairs(self.dyingCards) do
        if not (self.fx and (self.fx:deathFade(u) or self.fx:awaiting(u))) then
            self.dyingCards[u] = nil
        end
    end
    for u in pairs(self.lastLayout) do
        if not present[u] and not self.dyingCards[u] then self.lastLayout[u] = nil end
    end
    -- Cards still sliding/growing (or a death card fading) means the reshuffle isn't done.
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

-- The turn-order card `unit` currently occupies, as x, y, w, h -- or nil when it has no card on
-- screen (dead, or scrolled out of the strip). Reads the same entryLayout the strip draws from, and
-- honours the eased slot a sliding card is animating through, so a caller pointing at a card points
-- at where it actually IS mid-slide rather than where it will settle.
--
-- Exists for the tutorial's coaching bubble (states/battle.lua's `turn` anchor): a lesson about the
-- initiative timeline has to be able to point AT the timeline, and specifically at the one card that
-- just moved. Preview ghosts are skipped -- they are hypotheticals, not anybody's turn.
function CombatPanel:cardRect(unit)
    for _, e in ipairs(self:entryLayout()) do
        if not e.entry.preview and e.entry.unit == unit then
            return e.x, self.cardY[e.entry.unit] or e.y, e.w, e.h
        end
    end
    return nil
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

-- Is the acting card pinned at the bottom right now? It is whenever the current unit heads the
-- order (refreshView anchors its real entry at index 1). When there's no current -- battle over,
-- a lull -- nothing is pinned and every entry scrolls as a uniform slim card.
function CombatPanel:hasPinnedCurrent()
    local first = (self.view.order or {})[1]
    return self.view.current ~= nil and first ~= nil and not first.preview
        and first.unit == self.view.current
end

-- Bottom edge of the scrollable (upcoming) region: just above the pinned current card (leaving its
-- caption gap), or the strip bottom when nothing is pinned. The current card is fixed here.
function CombatPanel:upcomingBottom()
    if self:hasPinnedCurrent() then
        return self.stripBottom - CURRENT_H - CURRENT_TOP_GAP
    end
    return self.stripBottom
end

-- How many upcoming (slim) cards fit in the region above the pinned current card, and how far that
-- region can scroll before the last upcoming entry sits at the bottom. Upcoming cards are a uniform
-- slim height, so this fit is exact (the tall current card is pinned out of the scroll region).
function CombatPanel:visibleCount()
    local span = self:upcomingBottom() - self.stripTop
    return math.max(1, math.floor((span + ENTRY_GAP) / (SLIM_H + ENTRY_GAP)))
end

function CombatPanel:maxScroll()
    local upcoming = #(self.view.order or {}) - (self:hasPinnedCurrent() and 1 or 0)
    return math.max(0, upcoming - self:visibleCount())
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
    local y = self.stripBottom
    local startIndex = 1
    -- The acting card is PINNED at the bottom (just above the item grid it frames into), reserving
    -- CURRENT_H there regardless of scroll -- it never scrolls away. It's anchored at index 1 by the
    -- battle state's timeline build. Everything else stacks above it as the scrollable region.
    if self:hasPinnedCurrent() then
        turnNo = 1
        local top = y - CURRENT_H
        out[#out + 1] = { entry = entries[1], num = 1, x = self.x + 8, y = top, w = self.w - 16, h = CURRENT_H }
        -- Leave extra room above the acting card so its "Current Turn" caption has somewhere to sit.
        y = top - CURRENT_TOP_GAP
        startIndex = 2
    end
    -- Upcoming entries (uniform slim cards) hang off the current card, stacking upward directly on
    -- top of it so the whole timeline anchors from the bottom (the Current Turn box). `scroll` hides
    -- the nearest ones off the bottom of the region, so the window walks up toward later turns while
    -- the current card stays put; we stop once a card won't clear stripTop (whole cards only -- a
    -- card that wouldn't fit is dropped, never drawn cut off). Numbering walks every entry (skipped
    -- or not) so a scrolled-to entry keeps the #N its board token shows.
    local upcoming = 0
    for i = startIndex, #entries do
        local entry = entries[i]
        local num
        if not entry.preview then
            turnNo = turnNo + 1
            num = turnNo
        end
        upcoming = upcoming + 1
        if upcoming > self.scroll then
            local top = y - SLIM_H
            if top < self.stripTop then break end
            out[#out + 1] = { entry = entry, num = num, x = self.x + 8, y = top, w = self.w - 16, h = SLIM_H }
            y = top - ENTRY_GAP
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
    -- During the "out" phase the outgoing actor's big card stays in the frame, fading out, while its
    -- real queue card solidifies above -- so the frame never blinks empty as the turn hands off.
    if self.frameFade and self.frameY then
        self:drawCard({ unit = self.frameFade.unit, forceProm = 1 }, self.frameY, nil, CURRENT_H, self.frameFade.t)
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
function CombatPanel:drawCard(entry, y, num, h, alpha)
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
    self:drawEntry(entry, y, num, h, alpha)
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
        -- The framed slot is fixed (the layout reserves CURRENT_H for it), so the frame stays put and
        -- the incoming card slides + grows into it -- no frame pop, and nothing to overrun above.
        if (e.entry.unit == self.view.current) and not e.entry.preview then cardTop = e.y break end
    end
    local x, w = self.x + 5, self.w - 10
    -- With the actor in view the frame opens above its card to hold the "Current Turn" caption;
    -- scrolled out, it just brackets the grid from the Actions header.
    local top = cardTop and (cardTop - 22) or (self.gridY - 20)
    -- Reach past the item grid to enclose the Wait button too, so the whole "this unit and its
    -- actions" module -- portrait, grid, and the Wait/Focus/Defend bar -- reads as one framed turn.
    local bottom = self.waitBtn.y + self.waitBtn.h + 8
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
    -- The track spans only the scrollable region (above the pinned current card), since that card
    -- never moves -- so the bar sits over exactly what it scrolls.
    local total = #(self.view.order or {}) - (self:hasPinnedCurrent() and 1 or 0)
    local bx, bw = self.x + self.w - 5, 3
    local by, bh = self.stripTop, self:upcomingBottom() - self.stripTop

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", bx, by, bw, bh, 2, 2)

    -- The window covers visibleCount/total of the upcoming entries; scroll 0 pins the thumb to the
    -- bottom, because the strip counts upward from "now".
    local thumbH = math.max(24, bh * (self:visibleCount() / total))
    local t = self.scroll / max
    love.graphics.setColor(0.95, 0.85, 0.55, 0.75)
    love.graphics.rectangle("fill", bx, by + (1 - t) * (bh - thumbH), bw, thumbH, 2, 2)
end

-- A gold dashed rectangle border, used to mark preview (ghost) entries as hypothetical and to
-- dissolve out as a just-committed ghost solidifies into its real card (`alpha` fades it).
function CombatPanel:dashedRect(x, y, w, h, alpha)
    love.graphics.setColor(0.95, 0.85, 0.55, alpha or 0.9)
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
        local c = Colors.side(unit.side)
        love.graphics.setColor(c[1] * 0.8, c[2] * 0.8, c[3] * 0.8, a)
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
function CombatPanel:drawTurnNumber(num, cardX, cardTop, cardH, p)
    if not num then return end
    local font = (p > 0.5) and self.headFont or self.nameFont
    love.graphics.setFont(font)
    love.graphics.setColor(lerp(0.82, 0.98, p), lerp(0.85, 0.88, p), lerp(0.95, 0.5, p), lerp(0.9, 1, p))
    love.graphics.printf(tostring(num), cardX + 1, cardTop + cardH / 2 - font:getHeight() / 2, NUM_GUTTER - 2, "center")
end

-- Debug read-out: the entry's initiative (0 = acting now), including a preview ghost's projected value.
-- Tagged with an hourglass -- the same time-to-act glyph as the speed badge -- so the number reads as an
-- initiative timer, not a stat. Shown only while the F6 toggle is on.
function CombatPanel:drawInitiative(entry, ex, ew, ey)
    if not (self.view.showInitiative and entry.initiative) then return end
    love.graphics.setFont(self.smallFont)
    local text = string.format("%.1f", entry.initiative)
    local tw = self.smallFont:getWidth(text)
    local iconW, gap = 7, 3
    self:drawHourglass(ex + ew - 6 - tw - gap - iconW, ey + 4, iconW, 9, 0.98, 0.9, 0.6, 0.95)
    love.graphics.setColor(0.98, 0.9, 0.6, 0.95)
    love.graphics.printf(text, ex, ey + 3, ew - 6, "right")
end

-- The acting unit's full pool stack (HP/MP/SP, each max>0), stacked from topY: a colour-tinted
-- HP/MP/SP tag, the bar, and the value ("cur / max", or "cur -> after / max" under a preview) in a
-- shared right-hand column so the three rows align. This detail is the current card's alone -- slim
-- cards show just a thin HP bar -- so the numbers only appear where an action budget is being read.
function CombatPanel:drawPoolBars(unit, rx, rw, topY, alpha)
    alpha = alpha or 1
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

    -- Each row is marked with its pool's glyph (heart / gem / drop) just after the HP/MP/SP tag, the
    -- same shape the cost badges price a cast in -- so a spend badge and the bar it drains from carry
    -- one mark between them. Both are tinted alike, and the label stays: the letters open the row,
    -- the glyph closes it against the bar it fills. It sits in a fixed column, not tight against the
    -- text, so the three marks line up with each other down the stack.
    local barH, glyphW, glyphGap, labelW = 9, 7, 5, 22
    love.graphics.setFont(self.smallFont)
    local valueColW = 2
    for _, r in ipairs(rows) do valueColW = math.max(valueColW, self.smallFont:getWidth(r.text) + 2) end
    for i, r in ipairs(rows) do
        local rowY = topY + (i - 1) * 13
        local c = barColor(r.res, unit)
        -- The tag/glyph tint: the bar's colour lifted toward white so it stays legible at 9px.
        local tr, tg, tb = c[1] * 0.6 + 0.28, c[2] * 0.6 + 0.28, c[3] * 0.6 + 0.28
        love.graphics.setColor(tr, tg, tb, 0.95 * alpha)
        love.graphics.print(BAR_LABELS[r.res.key], rx, rowY + (barH - self.smallFont:getHeight()) / 2)
        local glyph = Glyphs.RESOURCE[r.res.key]
        if glyph then glyph(rx + labelW, rowY, glyphW, barH, tr, tg, tb, 0.95 * alpha) end
        local barX = rx + labelW + glyphW + glyphGap
        local barW = rw - (barX - rx) - valueColW - 6
        drawResourceBar(barX, rowY, barW, barH, r.cur, r.effMax, c, r.delta, r.lethal, r.reserved, alpha)
        love.graphics.setColor(0.94, 0.95, 0.98, alpha)
        love.graphics.printf(r.text, rx + rw - valueColW, rowY + (barH - self.smallFont:getHeight()) / 2,
            valueColW, "right")
    end
end

function CombatPanel:drawEntry(entry, ey, num, h, alpha)
    local unit = entry.unit
    local ex = self.x + 8
    local ew = self.w - 16

    -- Preview ghost: a faded, dashed hypothetical slot showing where the actor would land, not stats.
    if entry.preview then
        love.graphics.setColor(0.42, 0.38, 0.20, 0.40)
        love.graphics.rectangle("fill", ex, ey, ew, h, 6, 6)
        love.graphics.setLineWidth(1)
        self:dashedRect(ex, ey, ew, h)
        self:drawInitiative(entry, ex, ew, ey)
        local ps = h - 6
        self:drawPortrait(unit, ex + NUM_GUTTER, ey + 3, ps, 0.55)
        local rx = ex + NUM_GUTTER + ps + 8
        love.graphics.setFont(self.nameFont)
        love.graphics.setColor(0.95, 0.85, 0.55, 0.95)
        love.graphics.print(unit.char.name or "?", rx, ey + 3)
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.9, 0.82, 0.6, 0.9)
        love.graphics.print(entry.previewLabel or "would act here", rx, ey + 18)
        return
    end

    -- A real card. p = 0 is the slim upcoming look, p = 1 the tall framed current card. `forceProm`
    -- (the fading frame card in an "out" hand-off) pins it full-height regardless of cardProm.
    local isCurrent = (unit == self.view.current)
    local isParty = unit.side == "party"
    local p = entry.forceProm or self.cardProm[unit] or (isCurrent and 1 or 0)
    -- Top-anchored: the card hangs from its slot top (ey) and its height grows with p, so a card
    -- dropping into the frame slides its top down and fills the slot as it arrives.
    local dh = SLIM_H + (h - SLIM_H) * p
    local dy = ey
    -- A card that just handed off its turn MORPHS in from its preview ghost: its content fades up
    -- (ca 0.35 -> 1) as `solidify` runs down, so the faded ghost visibly becomes the real card. An
    -- explicit `alpha` (the outgoing's fading frame card) overrides that.
    local sd = self.solidify[unit]
    local st = sd and sd.t or 0
    local ca = alpha or ((st > 0) and lerp(1, 0.35, st) or 1)

    -- Plate fill + border lerp from the muted, side-tinted slim card to the opaque gold current card.
    local fr, fg, fb
    if isParty then fr, fg, fb = lerp(0.17, 0.20, p), lerp(0.22, 0.27, p), lerp(0.31, 0.38, p)
    else fr, fg, fb = lerp(0.29, 0.36, p), lerp(0.17, 0.20, p), lerp(0.17, 0.20, p) end
    love.graphics.setColor(fr, fg, fb, lerp(0.72, 1, p) * ca)
    love.graphics.rectangle("fill", ex, dy, ew, dh, 6, 6)
    local sc = Colors.side(unit.side)
    local br, bg, bb, ba = sc[1] * 0.9, sc[2] * 0.9, sc[3] * 0.9, 0.35
    love.graphics.setLineWidth(1)
    love.graphics.setColor(lerp(br, 0.95, p), lerp(bg, 0.85, p), lerp(bb, 0.55, p), lerp(ba, 1, p) * ca)
    love.graphics.rectangle("line", ex, dy, ew, dh, 6, 6)

    self:drawInitiative(entry, ex, ew, dy)

    -- A unit winding up a channel (never the current card -- that's the caster surfacing to detonate,
    -- framed with full pools already): its real card holds the resolve slot for the whole wind-up, so
    -- it names the pending SPELL and cues "channel resolves here" instead of stats, matching the ghost
    -- the aim preview showed. It stays slim, so no prominence blend applies.
    if unit.channel and not isCurrent then
        local ps = dh - 6
        self:drawTurnNumber(num, ex, dy, dh, 0)
        self:drawPortrait(unit, ex + NUM_GUTTER, dy + 3, ps, 1)
        local rx = ex + NUM_GUTTER + ps + 8
        love.graphics.setFont(self.nameFont)
        love.graphics.setColor(0.80, 0.66, 0.98) -- arcane violet, matching the Channeling badge tint
        love.graphics.print(unit.channel.item.name or "Channeling", rx, dy + 3)
        love.graphics.setFont(self.smallFont)
        local iconW = 7
        self:drawHourglass(rx, dy + 21, iconW, 9, 0.80, 0.66, 0.98, 0.9)
        love.graphics.setColor(0.80, 0.66, 0.98, 0.9)
        love.graphics.print("channel resolves here", rx + iconW + 4, dy + 20)
        for _, r in ipairs(self:statusBadgeRects(unit, ex, ew, dy)) do
            StatusBadge.draw(r.st, r.x, r.y, r.w, r.h)
        end
        return
    end

    -- Portrait + name sized by prominence; content alpha (ca) fades a just-handed-off card up.
    local ps = dh - lerp(6, 12, p)
    self:drawPortrait(unit, ex + NUM_GUTTER, dy + lerp(3, 6, p), ps, ca)
    self:drawTurnNumber(num, ex, dy, dh, p)

    local rx = ex + NUM_GUTTER + ps + lerp(8, 10, p)
    local rw = ex + ew - rx - lerp(8, 10, p)
    -- Name: the small card's font scaled up toward the head font on the current card; colour warms to gold.
    local nsc = lerp(1, self.headFont:getHeight() / self.nameFont:getHeight(), p)
    love.graphics.setFont(self.nameFont)
    love.graphics.setColor(lerp(0.9, 0.97, p), lerp(0.9, 0.94, p), lerp(0.94, 0.72, p), ca)
    love.graphics.print(unit.char.name or "?", rx, dy + lerp(4, 8, p), 0, nsc, nsc)

    for _, r in ipairs(self:statusBadgeRects(unit, ex, ew, dy)) do
        StatusBadge.draw(r.st, r.x, r.y, r.w, r.h)
    end

    -- Resource read-out: the current card shows the full numbered HP/MP/SP stack; a slim card shows just
    -- the thin HP bar. (ca fades either while a handed-off card morphs in.)
    local hp = unit.char.stats.health
    if (1 - p) > 0.02 and type(hp) == "table" and (hp.max or 0) > 0 then
        local pv = self.view.preview and self.view.preview[unit]
        local delta = pv and ((pv.heal or 0) - (pv.damage or 0)) or 0
        local reserved = Combat.reservedAmount(unit.char, "health")
        local effMax = Combat.unreservedMax(unit.char, "health") + reserved
        drawResourceBar(rx, dy + 22, rw, 6, self:shownHealth(unit), effMax, Colors.side(unit.side),
            delta, pv and pv.lethal, reserved, (1 - p) * ca)
    end
    if p > 0.02 then
        self:drawPoolBars(unit, rx, rw, dy + 34, p * ca)
    end

    -- The ghost's dashed border dissolves out as the card solidifies, so a card that had a preview
    -- visibly turns from ghost into real. Only for the real queue card (not the fading frame card,
    -- `alpha`) and only for a card that actually had a ghost (dashed = true).
    if sd and sd.dashed and sd.t > 0.02 and not alpha then
        self:dashedRect(ex, dy, ew, dh, 0.9 * sd.t)
    end
end

-- Small hourglass glyph (two triangles) for the speed badge, drawn in the given box. Kept as a method
-- for its callers' sake; the glyph itself lives in ui/glyphs.lua, since the item tooltip quotes a
-- recovery with the same mark.
function CombatPanel:drawHourglass(x, y, w, h, r, g, b, a)
    Glyphs.hourglass(x, y, w, h, r, g, b, a)
end

-- Small padlock (shackle arc over a body) for the reserve badge: the resource this ability locks
-- away, told apart from the cost glyphs because it never comes back on its own.
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

-- The resource glyphs live in ui/glyphs.lua: the pool bars below and ui/tile_tooltip.lua mark their
-- HP/MP/SP rows with the same three shapes, so a pool reads the same wherever it's quoted. A cost
-- badge names its resource as its icon kind, so an unknown stat (a mod's own pool) still gets a mark
-- -- the gem, the generic "some resource" shape.
local RES_GLYPH = Glyphs.RESOURCE

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
-- (top-left costs) or "right" (top-right speed); `iconKind` is "hourglass", "lock", "link", "ring",
-- or a resource name ("mana"/"stamina"/"health") for a cost badge, which draws that pool's glyph.
-- `row` stacks a badge under the previous one in the same corner (0 = top, the default).
function CombatPanel:drawBadge(sx, sy, sw, corner, iconKind, amount, color, a, row)
    local bw, bh = self:badgeSize(amount)
    local pad = 3
    local bx = (corner == "right") and (sx + sw - pad - bw) or (sx + pad)
    self:drawBadgeAt(bx, sy + pad + (row or 0) * (bh + 2), iconKind, amount, color, a)
end

-- The box `amount`'s badge will fill, so a caller that is NOT putting one in a corner -- the recovery
-- clock, which centres its badge on the icon -- can place it before drawing it.
function CombatPanel:badgeSize(amount)
    return BADGE_PAD_X * 2 + BADGE_ICON_W + BADGE_GAP + self.smallFont:getWidth(tostring(amount)), BADGE_H
end

-- The badge proper, at an explicit position: what both the corner badges above and the centred
-- recovery clock draw through, so every pill in the grid is built the same way.
function CombatPanel:drawBadgeAt(bx, by, iconKind, amount, color, a)
    love.graphics.setFont(self.smallFont)
    local label = tostring(amount)
    local iconW, gap, padX = BADGE_ICON_W, BADGE_GAP, BADGE_PAD_X
    local bw, bh = self:badgeSize(amount)

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
    else -- a cost: `iconKind` is the resource it's paid in, and each pool has its own shape
        local glyph = RES_GLYPH[iconKind] or Glyphs.manaGem
        glyph(ix, iy, iconW, 10, color[1], color[2], color[3], a)
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
        -- A triggered reflex (a Riposte Blade's parry) that has fired and is still recovering. Not a
        -- blockReason: nothing here is being cast, so there is no arm to refuse -- the slot simply
        -- cannot answer yet, and says so with the recovery clock below.
        local cooling = item and self.view.current and Combat.itemCooldown(self.view.current, item)

        if item then
            -- Grayer than an ordinary idle slot: a recovering reflex is inert in a way a merely
            -- passive one isn't, so it must not read as ready at a glance.
            local dim = cooling and 0.3 or ((not usable) and 0.45 or 1)
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

            -- The recovery clock over the icon (never over the name band, which stays readable): the
            -- wedge, then the ticks left in an hourglass badge centred on it. Centred rather than
            -- tucked in a corner because the clock is the whole story of a recovering slot -- it is
            -- what the eye should land on, not a footnote to the art behind it. Red, like every other
            -- badge that says "not yet".
            if cooling then
                local cwx, cwy = sx + 1, sy + 1
                local cww, cwh = sw - 2, sh - NAME_H - 1
                drawCooldownSweep(cwx, cwy, cww, cwh, cooling.remaining / cooling.total)
                local left = math.max(0, math.ceil(cooling.remaining))
                local bw, bh = self:badgeSize(left)
                self:drawBadgeAt(cwx + (cww - bw) / 2, cwy + (cwh - bh) / 2,
                    "hourglass", left, WARN_COLOR, 1)
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
                    self:drawBadge(sx, sy, sw, "left", ab.cost.stat, ab.cost.amount, c, short and 1 or dim, row)
                    row = row + 1
                end
                -- A reservation is a cost too -- paid on the cast, then locked away for as long as
                -- what it summons lives -- so it earns its own badge under the cost, a padlock
                -- instead of the resource's own glyph. Priced against the actor (a share of ITS maximum),
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

-- Returns the ability item under the hovered slot on a party turn, whether or not it can fire right
-- now (else nil). This is what a CLICK acts on: a blocked ability still has to be reachable, so the
-- state can refuse it out loud (Rain of Arrows with no bow beside it says why) instead of the click
-- vanishing into a slot that looks pressable. Deciding IF it may fire is the state's job, not the
-- panel's -- Combat.itemBlockReason is the one gate, and it lives there.
-- A Blink (moveBehavior) item qualifies too: activating it toggles teleport movement.
function CombatPanel:actionItemAt(px, py)
    if not self.view.isPartyTurn then return nil end
    local i = self:slotIndexAt(px, py)
    local item = i and (self.view.items or {})[i]
    if item and (item.activeAbility or item.moveBehavior) then return item, i end
    return nil
end

-- Returns the ability item under a slot that can actually be activated right now (else nil). The
-- narrower read, for HOVER: an ability that can't fire must not preview its timeline, matching its
-- grayed-out slot (the hover tooltip via itemAt still explains why). Clicks use actionItemAt above.
function CombatPanel:usableItemAt(px, py)
    local item, i = self:actionItemAt(px, py)
    -- Blink has no ability cost, so blockReason never gates it.
    if item and not self:blockReason(item) then return item, i end
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
            local y = self.cardY[e.entry.unit] or e.y -- the eased slot the card is actually drawn at
            for _, r in ipairs(self:statusBadgeRects(e.entry.unit, e.x, e.w, y)) do
                if px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h then
                    return r.st
                end
            end
        end
    end
    return nil
end

-- The unit whose turn-strip entry is under the cursor (else nil). Hit-tests the eased slot the card is
-- drawn at, not the target layout, so hover tracks a card mid-slide.
function CombatPanel:unitAt(px, py)
    for _, e in ipairs(self:entryLayout()) do
        local y = (not e.entry.preview and self.cardY[e.entry.unit]) or e.y
        if px >= e.x and px <= e.x + e.w and py >= y and py <= y + e.h then
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
    -- Route the click on ANY ability slot, usable or not: the state arms it, or refuses it with a
    -- reason the player can read. A silently swallowed click on a slot that looks pressable is the
    -- bug this avoids.
    local item, i = self:actionItemAt(x, y)
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
