-- A little grid graphic of an ability's reach, for the item tooltip's Range row. Range is measured
-- in Manhattan distance (models/combat.lua), so the reachable tiles form a diamond centred on the
-- caster; a `minRange` dead-zone hollows the middle into a ring. The caster's own tile is marked in
-- the centre, the targetable band is tinted with the caller's colour (green for a friendly cast,
-- red for a hostile one -- see Combat.isSupportAbility), and out-of-band tiles stay dark so the
-- shape reads at a glance. No love.graphics at require-time.
--
--   local layout = RangeDiagram.layout(ab, maxWidth)   -- nil for a targetless ability (no reach)
--   RangeDiagram.draw(layout, x, y, color)             -- draws with top-left at (x, y)
--
-- `layout` carries its own { width, height } so the tooltip can measure the block before drawing,
-- exactly as it wraps and caches description text.

local RangeDiagram = {}

local BG = { 0.15, 0.16, 0.21 }        -- an out-of-reach tile
local GRID = { 0.28, 0.31, 0.38 }      -- hairline between tiles
local CASTER = { 0.82, 0.85, 0.92 }    -- the caster's own tile, at the centre

local MAX_CELL = 15                    -- cap so short ranges don't balloon
local MIN_CELL = 8                     -- floor so long ranges stay legible
local GAP = 1                          -- hairline gap baked into the step

-- Build the drawable layout for `ab`, fitting within `maxWidth` px. Returns nil when the ability
-- has no reach to picture (a self-only cast, range 0) so the caller can simply skip the block.
function RangeDiagram.layout(ab, maxWidth)
    local range = (ab and ab.range) or 1
    local minRange = (ab and ab.minRange) or 0
    if range < 1 then return nil end -- range 0 == self: nothing to diagram

    local n = 2 * range + 1 -- one row/col per tile across the widest span of the diamond
    local step = math.max(MIN_CELL, math.min(MAX_CELL, math.floor(maxWidth / n)))
    local size = n * step

    return {
        range = range,
        minRange = minRange,
        n = n,
        step = step,
        cell = step - GAP,
        width = size,
        height = size,
    }
end

-- Draw `layout` (from RangeDiagram.layout) with its top-left corner at (x, y). `color` tints the
-- targetable band; it defaults to a neutral grey if omitted.
function RangeDiagram.draw(layout, x, y, color)
    if not layout then return end
    color = color or { 0.7, 0.72, 0.8 }
    local range, minRange, n, step, cell = layout.range, layout.minRange, layout.n, layout.step, layout.cell

    for gy = 0, n - 1 do
        for gx = 0, n - 1 do
            local dx, dy = gx - range, gy - range
            local d = math.abs(dx) + math.abs(dy)
            local cx, cy = x + gx * step, y + gy * step

            if d == 0 then
                -- The caster's tile: a solid marker so "you are here" reads at the centre.
                love.graphics.setColor(CASTER[1], CASTER[2], CASTER[3], 0.95)
                love.graphics.rectangle("fill", cx, cy, cell, cell, 2, 2)
            elseif d <= range and d >= minRange then
                -- A tile this ability can reach: tinted fill + a brighter border.
                love.graphics.setColor(color[1], color[2], color[3], 0.55)
                love.graphics.rectangle("fill", cx, cy, cell, cell, 2, 2)
                love.graphics.setColor(color[1], color[2], color[3], 0.95)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", cx + 0.5, cy + 0.5, cell - 1, cell - 1, 2, 2)
            else
                -- Out of reach (beyond range, or inside the minRange dead-zone): a dark grid tile.
                love.graphics.setColor(BG[1], BG[2], BG[3], 0.85)
                love.graphics.rectangle("fill", cx, cy, cell, cell, 2, 2)
                love.graphics.setColor(GRID[1], GRID[2], GRID[3], 0.6)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", cx + 0.5, cy + 0.5, cell - 1, cell - 1, 2, 2)
            end
        end
    end

    love.graphics.setColor(1, 1, 1)
end

return RangeDiagram
