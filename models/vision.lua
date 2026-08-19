-- Line of sight over an overworld grid.
--
-- WHAT THE PARTY CAN SEE IS NOT A CIRCLE, IT IS A ROOM. The fog used to lift on distance alone, so
-- standing in a chamber lit the trees around it and the corridor on the far side of them: a board that
-- reported what was behind a wall, which is the one thing walking there is supposed to buy. The rift is
-- carved as corridors through solid fill (models/layouts/), so distance-only vision was showing the
-- player most of a junction before they reached it and hiding almost nothing that mattered.
--
-- Sight is cast instead: everything the eye can draw a clear line to, out to the radius, and nothing
-- past what stops it. It is the same rule a patrol already uses to spot the party (Patrol.sees, which
-- keeps to rows and columns because a body has to be able to state why it noticed you) -- if you can
-- trace a clear line to a tile, you can see it.
--
-- Recursive shadowcasting, eight octants, so the shape it lights is symmetric: a wall casts one shadow
-- rather than a different one from each side of the same corridor. THE THING THAT STOPS THE LIGHT IS
-- ALSO LIT -- a tile is marked before it is tested for opacity, so the wall face you are standing at
-- draws and only the ground behind it goes dark. A wall you cannot see is a hole in the map.
--
-- Opacity is walkability by tile type, asked of the grid's own tileset so this can never disagree with
-- what the party may walk through: swamp shallows are wadeable and see-through, a thicket is neither.

local Vision = {}

-- The eight octants, each as the (xx, xy, yx, yy) transform that maps a scan's local (column, row) onto
-- board coordinates. One scan is written; these turn it around the compass.
local OCTANTS = {
    { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 0, -1, 1, 0 }, { -1, 0, 0, 1 },
    { -1, 0, 0, -1 }, { 0, -1, -1, 0 }, { 0, 1, -1, 0 }, { 1, 0, 0, -1 },
}

local function key(x, y) return y * 100000 + x end

-- Off the board counts as solid: the frame is a wall like any other.
local function opaque(grid, x, y)
    local c = grid:get(x, y)
    return c == nil or not grid:typeWalkable(c.tile)
end

-- One octant, one row at a time, narrowing between the slopes of whatever is still lit. A solid tile
-- splits the beam: the part of it to the tile's left is handed to a child scan that carries on ahead,
-- and this one resumes on the right of the obstruction when it finds open ground again.
local function scan(grid, lit, cx, cy, radius, row, startSlope, endSlope, xx, xy, yx, yy)
    if startSlope < endSlope then return end
    local nextStart = startSlope
    for j = row, radius do
        local dy = -j
        local dx = -j - 1
        local blocked = false
        while dx <= 0 do
            dx = dx + 1
            local x, y = cx + dx * xx + dy * xy, cy + dx * yx + dy * yy
            -- The slopes of this tile's left and right extremities, against the beam still open.
            local lSlope, rSlope = (dx - 0.5) / (dy + 0.5), (dx + 0.5) / (dy - 0.5)
            if startSlope >= rSlope then
                if endSlope > lSlope then break end
                if grid:inRange(cx, cy, x, y, radius) then lit[key(x, y)] = true end
                if blocked then
                    if opaque(grid, x, y) then
                        nextStart = rSlope
                    else
                        blocked = false
                        startSlope = nextStart
                    end
                elseif opaque(grid, x, y) and j < radius then
                    blocked = true
                    scan(grid, lit, cx, cy, radius, j + 1, startSlope, lSlope, xx, xy, yx, yy)
                    nextStart = rSlope
                end
            end
        end
        if blocked then break end
    end
end

-- Every tile visible from (cx, cy) within `radius`, as a set keyed the way the grid's BFS passes key a
-- cell. The tile you stand on is always in it.
function Vision.field(grid, cx, cy, radius)
    local lit = { [key(cx, cy)] = true }
    for _, o in ipairs(OCTANTS) do
        scan(grid, lit, cx, cy, radius, 1, 1.0, 0.0, o[1], o[2], o[3], o[4])
    end
    return lit
end

Vision.key = key

return Vision
