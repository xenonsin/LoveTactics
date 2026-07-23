-- Toggleable combat-log panel (left side of the battle screen). A read-only view over the
-- rolling event stream the combat model records on combat.log (Combat.logEvent): moves, item
-- casts, damage, heals, status effects, traps, and the battle's start/end. Owned by
-- states/battle.lua, which flips its visibility from the "Log" button (mouse), the L key
-- (keyboard), and a gamepad shoulder (the project's three-input standard) and forwards the
-- mouse wheel to it for scrolling.
--
-- Lines read top(older) -> bottom(newer) and the view is anchored to the newest entry, so it
-- follows the action; scrolling up (self.scroll > 0) walks back through history and stays put
-- until the player scrolls back down. Each entry is coloured by its `kind`.
--
-- Hovering a line does two things at once. Locally it opens that line's detail (a damage breakdown,
-- the item swung, the status that landed). Outward, it names WHO the line is about: the entry's
-- `units` (Combat.logEvent's subjects) are published through :hoveredUnits(), which states/battle.lua
-- reads to ring those units on the board and on the initiative strip -- so "Rowan takes 7 damage" is
-- answered by a light on Rowan, wherever the player has to look to find him.

local Scale = require("scale")
local ItemTooltip = require("ui.item_tooltip")
local StatusTooltip = require("ui.status_tooltip")

local CombatLog = {}
CombatLog.__index = CombatLog

-- Per-kind text colour. Anything unmapped falls back to a neutral light grey.
local KIND_COLOR = {
    system = { 0.95, 0.85, 0.55 }, -- battle begins / victory / defeat
    action = { 0.86, 0.88, 0.94 }, -- "X attacks with / uses Y"
    move   = { 0.55, 0.72, 0.95 }, -- movement
    damage = { 0.93, 0.55, 0.48 }, -- damage dealt
    death  = { 0.98, 0.42, 0.40 }, -- a unit is defeated
    heal   = { 0.50, 0.86, 0.52 }, -- healing
    status = { 0.80, 0.64, 0.96 }, -- status applied / worn off
    trap   = { 0.96, 0.72, 0.38 }, -- trap placed / triggered / destroyed
    wait   = { 0.62, 0.65, 0.72 }, -- wait / hold position
}
local FALLBACK_COLOR = { 0.82, 0.84, 0.90 }

local PAD = 12        -- inner horizontal padding (text wrap margin)
local VPAD = 8        -- inner vertical padding (kept tight so the short strip fits ~5+ lines)
local SCROLL_STEP = 3 -- visual lines per wheel notch

function CombatLog.new(combat, opts)
    opts = opts or {}
    local self = setmetatable({}, CombatLog)
    self.combat = combat
    -- Open by default: the log lives in the free gutter under the board (it covers nothing the player
    -- needs), and a fight reads far better when the running account of it is already there rather than
    -- behind a toggle nobody found. `visible = false` in opts still opts out.
    self.visible = opts.visible ~= false
    self.scroll = 0 -- visual lines scrolled up from the newest (0 = following the tail)

    self.font = love.graphics.newFont(13)
    self.lineH = self.font:getHeight() + 3
    self.detailFont = love.graphics.newFont(12) -- body of the hover breakdown tooltip
    self.mx, self.my = nil, nil                 -- last known mouse (for the hover tooltip)

    self.x = opts.x or 16
    self.y = opts.y or 150
    self.w = opts.w or 300
    self.h = opts.h or (Scale.HEIGHT - self.y - 44) -- leave the bottom control hint clear
    return self
end

function CombatLog:toggle()
    self.visible = not self.visible
    if self.visible then self.scroll = 0 end -- reopen following the newest line
end

function CombatLog:contains(px, py)
    return self.visible and px >= self.x and px <= self.x + self.w
        and py >= self.y and py <= self.y + self.h
end

-- Flatten combat.log into a list of { text, color } VISUAL lines (each entry wrapped to the
-- inner width), oldest first. Recomputed per draw -- the log is small (capped) and this keeps
-- the widget stateless between frames apart from the scroll offset.
function CombatLog:visualLines(wrapW)
    local out = {}
    for _, e in ipairs(self.combat.log or {}) do
        local color = KIND_COLOR[e.kind] or FALLBACK_COLOR
        local _, wrapped = self.font:getWrap(e.text or "", wrapW)
        if #wrapped == 0 then wrapped = { e.text or "" } end
        for _, line in ipairs(wrapped) do
            -- Carry the source entry on every wrapped line so a hover over any part of a multi-line
            -- event (e.g. a long damage line) can find that event's `detail` breakdown.
            out[#out + 1] = { text = line, color = color, entry = e }
        end
    end
    return out
end

-- Geometry of the text area, shared by draw and the hover resolve so both agree on which line
-- sits under which pixel.
function CombatLog:contentMetrics()
    local contentTop = self.y + VPAD
    local wrapW = self.w - PAD * 2
    local visibleCount = math.max(1, math.floor((self.h - VPAD * 2) / self.lineH))
    return contentTop, wrapW, visibleCount
end

-- The log entry under the cursor right now, or nil. Resolved here rather than inside draw so the
-- battle state can ask for it while it is building this frame's overlays -- the board ring and the
-- draw of the line that raised it then land on the SAME frame instead of a frame apart.
--
-- Memoised on (cursor, log length): both callers ask in the same frame with the same cursor, and
-- rebuilding the wrap for the whole log twice per frame is work for nothing.
function CombatLog:resolveHover()
    if not self.visible or not self.mx then
        self.hovered = nil
        return nil
    end
    local n = #(self.combat.log or {})
    local memo = self._hoverMemo
    if memo and memo.mx == self.mx and memo.my == self.my and memo.n == n then
        return self.hovered
    end

    local hovered = nil
    if self:contains(self.mx, self.my) then
        local contentTop, wrapW, visibleCount = self:contentMetrics()
        local lines = self:visualLines(wrapW)
        -- Same clamp draw applies, so a hover resolved before this frame's draw lands on the same
        -- window of lines the player is about to see.
        self.scroll = math.max(0, math.min(self.scroll, math.max(0, #lines - visibleCount)))
        local endIdx = #lines - self.scroll
        local startIdx = math.max(1, endIdx - visibleCount + 1)
        local row = math.floor((self.my - contentTop) / self.lineH)
        local line = row >= 0 and lines[startIdx + row] or nil
        -- Only a line with something to say answers a hover: a breakdown, an item, a status, or the
        -- units it is about. A bare "The battle begins." stays inert, so the highlight keeps meaning
        -- "there is more here".
        local e = line and line.entry
        if e and (e.detail or e.item or e.status or e.units) then hovered = e end
    end
    self.hovered = hovered
    self._hoverMemo = { mx = self.mx, my = self.my, n = n }
    return hovered
end

-- The units the hovered line is about (Combat.logEvent's subjects), oldest-first as the model named
-- them: the doer and the done-to. Empty when nothing hoverable is under the cursor. Read by
-- states/battle.lua to light those units up on the board and the timeline.
function CombatLog:hoveredUnits()
    local e = self:resolveHover()
    return (e and e.units) or nil
end

function CombatLog:draw()
    if not self.visible then return end

    -- Panel background + subtle border (no title bar -- the strip sits under the board and the
    -- space is reserved for log lines, so every pixel of height counts).
    love.graphics.setColor(0.08, 0.09, 0.13, 0.90)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 8, 8)
    love.graphics.setColor(0.35, 0.40, 0.52, 0.85)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 8, 8)

    local contentTop, wrapW, visibleCount = self:contentMetrics()

    local lines = self:visualLines(wrapW)
    local total = #lines
    -- Clamp the scroll so it can't run past the oldest line or below the tail.
    local maxScroll = math.max(0, total - visibleCount)
    if self.scroll > maxScroll then self.scroll = maxScroll end
    if self.scroll < 0 then self.scroll = 0 end

    -- Window of lines to show: anchored to the newest, offset upward by the scroll.
    local endIdx = total - self.scroll
    local startIdx = math.max(1, endIdx - visibleCount + 1)

    -- Which entry the mouse is over, so a hoverable line can offer its detail: a damage line's
    -- breakdown, an action line's item, or a status line's effect. Resolved by resolveHover (which the
    -- battle state has usually already called this frame) so the panel and the board agree.
    local overMx, overMy = self.mx, self.my
    local hoveredEntry = self:resolveHover()

    love.graphics.setFont(self.font)
    local y = contentTop
    for i = startIdx, endIdx do
        local line = lines[i]
        if line then
            -- A line that carries something to expand -- a damage breakdown, the item that was swung,
            -- the status that landed, or the units it names -- gets a faint highlight; the highlight
            -- also tells the player which lines are worth hovering. Keyed off the ENTRY, so a long
            -- event wrapped over several lines lights up as the one event it is.
            if hoveredEntry and line.entry == hoveredEntry then
                love.graphics.setColor(1, 1, 1, 0.07)
                love.graphics.rectangle("fill", self.x + 2, y - 1, self.w - 4, self.lineH, 3, 3)
            end
            local c = line.color
            love.graphics.setColor(c[1], c[2], c[3])
            love.graphics.print(line.text, self.x + PAD, y)
            y = y + self.lineH
        end
    end

    -- "more above / below" affordance so scroll state is legible.
    love.graphics.setFont(self.font)
    if startIdx > 1 then
        love.graphics.setColor(0.6, 0.65, 0.75, 0.9)
        love.graphics.printf("^ older", self.x, contentTop - 2, self.w - PAD, "right")
    end
    if self.scroll > 0 then
        love.graphics.setColor(0.6, 0.65, 0.75, 0.9)
        love.graphics.printf("v newer", self.x, self.y + self.h - VPAD - self.lineH, self.w - PAD, "right")
    end

    -- The hover tooltip, drawn last so it sits above the log's own lines. A damage line shows its
    -- own breakdown; an action or status line borrows the shared item / status tooltips, so a name in
    -- the log reads exactly as it does on the board and in the panel.
    if hoveredEntry then
        if hoveredEntry.detail then
            self:drawDetail(hoveredEntry.detail, overMx, overMy)
        elseif hoveredEntry.item then
            ItemTooltip.draw(hoveredEntry.item, overMx, overMy, Scale.WIDTH)
        elseif hoveredEntry.status then
            StatusTooltip.draw(hoveredEntry.status, overMx, overMy, Scale.WIDTH)
        end
    end

    love.graphics.setColor(1, 1, 1)
end

-- Render a damage breakdown (Combat.damageBreakdown: a list of { label, value, strong, signed }
-- rows, plus an optional `note`) as a dark panel near the cursor. Reads like a receipt: the
-- pre-mitigation addends on top, the signed mitigation below, then a ruled-off total.
function CombatLog:drawDetail(detail, mx, my)
    local font = self.detailFont
    local lineH = font:getHeight() + 4
    local pad, w = 10, 232
    local rows = detail

    -- Height: a header line, one line per row, a note line if present, and padding.
    local hasNote = rows.note ~= nil
    local h = pad + lineH -- header
        + #rows * lineH
        + (hasNote and lineH or 0)
        + pad

    -- Anchor near the cursor, flipping/clamping so the box stays fully on-screen.
    local bx = mx + 16
    if bx + w + 4 > Scale.WIDTH then bx = mx - w - 16 end
    bx = math.max(4, math.min(bx, Scale.WIDTH - w - 4))
    local by = math.max(4, math.min(my + 14, Scale.HEIGHT - h - 4))

    love.graphics.setColor(0.07, 0.08, 0.11, 0.97)
    love.graphics.rectangle("fill", bx, by, w, h, 6, 6)
    love.graphics.setColor(0.55, 0.42, 0.40, 0.9) -- warm edge, matching the damage kind's hue
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bx, by, w, h, 6, 6)

    love.graphics.setFont(font)
    local lx, rx = bx + pad, bx + w - pad
    local ty = by + pad

    love.graphics.setColor(0.93, 0.55, 0.48, 1)
    love.graphics.print("Damage breakdown", lx, ty)
    ty = ty + lineH

    for _, r in ipairs(rows) do
        if r.strong then
            -- Rule off the total from the working above it.
            love.graphics.setColor(0.35, 0.40, 0.52, 0.8)
            love.graphics.line(lx, ty + 1, rx, ty + 1)
            ty = ty + 3
        end
        local labelColor = r.strong and { 0.98, 0.98, 1.0 } or { 0.80, 0.82, 0.88 }
        love.graphics.setColor(labelColor[1], labelColor[2], labelColor[3], 1)
        love.graphics.print(r.label, lx, ty)
        if r.value ~= nil then
            local n = r.value
            local text
            if r.signed then
                -- Explicit sign, with a true minus glyph so "−4" reads cleanly at 12px.
                text = (n < 0) and ("−" .. tostring(-n)) or ("+" .. tostring(n))
            else
                text = tostring(n)
            end
            local vw = font:getWidth(text)
            local vColor = r.strong and { 0.98, 0.72, 0.55 }
                or (r.signed and n < 0 and { 0.70, 0.80, 0.95 } or { 0.90, 0.86, 0.70 })
            love.graphics.setColor(vColor[1], vColor[2], vColor[3], 1)
            love.graphics.print(text, rx - vw, ty)
        end
        ty = ty + lineH
    end

    if hasNote then
        love.graphics.setColor(0.62, 0.65, 0.72, 1)
        love.graphics.print(rows.note, lx, ty)
    end
end

-- Track the cursor so draw() can offer a damage line's breakdown on hover. Stored (not acted on
-- here) because the tooltip is resolved during draw, against the lines actually on screen this frame.
function CombatLog:mousemoved(x, y)
    self.mx, self.my = x, y
end

-- Mouse wheel: scroll the history when the panel is open (dy > 0 = wheel up = older lines).
-- Returns true when it consumed the event so the state doesn't also act on it.
function CombatLog:wheelmoved(dx, dy)
    if not self.visible or dy == 0 then return false end
    self.scroll = self.scroll + (dy > 0 and SCROLL_STEP or -SCROLL_STEP)
    if self.scroll < 0 then self.scroll = 0 end
    return true
end

return CombatLog
