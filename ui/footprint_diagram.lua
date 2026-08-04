-- A small drawn picture of an ability's AREA footprint -- the actual tiles a line / cone / blast
-- sweeps -- for the Forge growth sheet, where a weapon whose footprint OPENS as it is forged
-- (The First Motion's line into a cone) needs its shape SHOWN, not described in a number column.
--
-- Board-agnostic: the caster faces north and the shape is drawn around them, mirroring the geometry
-- Combat.aoeCells lays on the real board. That function stays the single source of truth for what a
-- cast actually hits; this only pictures it, so the two must be kept in step by hand -- the trade for
-- a preview that needs no live combat, arena, or unit to draw. The one shape it cannot picture is a
-- data-driven `aoe.cells` footprint (the Wolfsong Horn), whose tiles depend on the live board; the
-- caller simply omits the diagram there.
--
--   local cells = FootprintDiagram.cells(aoe)         -- { { x, y, role }, ... } around the caster (0,0)
--   FootprintDiagram.draw(aoe, x, y, box, color)      -- fit within a box-px square, top-left at (x, y)
--
-- No love.graphics at require-time, so it loads under the headless test runner.

local FootprintDiagram = {}

local BG = { 0.15, 0.16, 0.21 }     -- an un-struck tile of the backing grid
local CASTER = { 0.82, 0.85, 0.92 } -- the caster's own tile: "you are here"

-- The relative cells an `aoe` spec sweeps, caster at (0, 0) facing north. `role` is "caster" for the
-- caster's own tile and "hit" for a struck one. Mirrors the shape math in Combat.aoeCells: a
-- directional shape (line/front/cone) grows from the aimed adjacent cell along the facing; anything
-- else is a centred diamond/square of the given radius.
function FootprintDiagram.cells(aoe)
    aoe = aoe or {}
    local cells, seen = {}, {}
    local function add(x, y, role)
        local key = x .. ":" .. y
        if not seen[key] then seen[key] = true; cells[#cells + 1] = { x = x, y = y, role = role } end
    end

    local shape = aoe.shape
    if shape == "line" or shape == "front" or shape == "cone" then
        add(0, 0, "caster")
        local dx, dy = 0, -1   -- facing north
        local px, py = -dy, dx -- the perpendicular (widening) axis: (1, 0)
        local tx, ty = dx, dy  -- the aimed adjacent cell, one step along the facing
        if shape == "line" then
            local length = aoe.length or 1
            for i = 0, length - 1 do add(tx + dx * i, ty + dy * i, "hit") end
        elseif shape == "cone" then
            -- Row i spans perpendicular offsets [-i, i]: the fan widens one tile each side per step out.
            local length = aoe.length or 1
            for i = 0, length - 1 do
                local cx, cy = tx + dx * i, ty + dy * i
                for j = -i, i do add(cx + px * j, cy + py * j, "hit") end
            end
        else -- front: a width-wide line perpendicular to the facing, centred on the aimed cell
            local width = aoe.width or 1
            local half = math.floor(width / 2)
            for i = -half, half do add(tx + px * i, ty + py * i, "hit") end
        end
    else
        -- A centred blast: diamond (Manhattan) or square, radius r around the aimed tile at (0, 0).
        local r = aoe.radius or 0
        local diamond = shape == "diamond"
        for gx = -r, r do
            for gy = -r, r do
                if not diamond or (math.abs(gx) + math.abs(gy) <= r) then add(gx, gy, "hit") end
            end
        end
    end
    return cells
end

-- Bounds of a cell set as minX, minY, maxX, maxY (0,0,0,0 for an empty set).
local function bounds(cells)
    local minx, miny, maxx, maxy
    for _, c in ipairs(cells) do
        minx = (minx == nil or c.x < minx) and c.x or minx
        maxx = (maxx == nil or c.x > maxx) and c.x or maxx
        miny = (miny == nil or c.y < miny) and c.y or miny
        maxy = (maxy == nil or c.y > maxy) and c.y or maxy
    end
    return minx or 0, miny or 0, maxx or 0, maxy or 0
end

-- Draw the footprint for `aoe` centred inside a `box`-px square whose top-left is (x, y). `color`
-- tints the struck tiles (defaults to the board's AOE red). The grid auto-sizes to the shape's span.
function FootprintDiagram.draw(aoe, x, y, box, color)
    color = color or { 1.0, 0.42, 0.30 }
    local cells = FootprintDiagram.cells(aoe)
    local minx, miny, maxx, maxy = bounds(cells)
    local cols, rows = (maxx - minx + 1), (maxy - miny + 1)
    local step = math.max(3, math.floor(box / math.max(cols, rows)))
    local cell = math.max(2, step - 1)
    local ox = x + math.floor((box - cols * step) / 2)
    local oy = y + math.floor((box - rows * step) / 2)

    -- Backing grid, so an empty tile inside the span still reads as board.
    love.graphics.setColor(BG[1], BG[2], BG[3], 0.5)
    for gy = 0, rows - 1 do
        for gx = 0, cols - 1 do
            love.graphics.rectangle("fill", ox + gx * step, oy + gy * step, cell, cell, 1, 1)
        end
    end

    for _, c in ipairs(cells) do
        local cx, cy = ox + (c.x - minx) * step, oy + (c.y - miny) * step
        if c.role == "caster" then
            love.graphics.setColor(CASTER[1], CASTER[2], CASTER[3], 0.95)
        else
            love.graphics.setColor(color[1], color[2], color[3], 0.78)
        end
        love.graphics.rectangle("fill", cx, cy, cell, cell, 1, 1)
    end
    love.graphics.setColor(1, 1, 1)
end

return FootprintDiagram
