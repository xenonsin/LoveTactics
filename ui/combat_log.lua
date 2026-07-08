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

local Scale = require("scale")

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
    self.visible = false
    self.scroll = 0 -- visual lines scrolled up from the newest (0 = following the tail)

    self.font = love.graphics.newFont(13)
    self.lineH = self.font:getHeight() + 3

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
            out[#out + 1] = { text = line, color = color }
        end
    end
    return out
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

    local contentTop = self.y + VPAD
    local contentH = self.h - VPAD * 2
    local wrapW = self.w - PAD * 2
    local visibleCount = math.max(1, math.floor(contentH / self.lineH))

    local lines = self:visualLines(wrapW)
    local total = #lines
    -- Clamp the scroll so it can't run past the oldest line or below the tail.
    local maxScroll = math.max(0, total - visibleCount)
    if self.scroll > maxScroll then self.scroll = maxScroll end
    if self.scroll < 0 then self.scroll = 0 end

    -- Window of lines to show: anchored to the newest, offset upward by the scroll.
    local endIdx = total - self.scroll
    local startIdx = math.max(1, endIdx - visibleCount + 1)

    love.graphics.setFont(self.font)
    local y = contentTop
    for i = startIdx, endIdx do
        local line = lines[i]
        if line then
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

    love.graphics.setColor(1, 1, 1)
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
