-- CAVERNS: nothing cut this place, it cooled into shape.
--
-- Random fill, four smoothing passes of the usual 5-neighbour rule, keep the largest cavern and tunnel
-- the worthwhile stragglers into it. Wide bellies, pinched necks, no straight lines anywhere.
--
-- It is the one ground where you cannot tell a corridor from a room until you are in it, which is worth
-- having on a board where something is walking a beat: a patrol can be lost track of and met again from
-- the wrong side. The bellies are arenas without being rooms -- where the walls fall when a fight starts
-- is genuinely uncertain until they fall.
--
-- The smoothing rule is what makes this fightable at all. A raw random fill is noise and scores nothing;
-- four passes of "solid if five of your neighbours are solid" is what turns noise into caves with
-- interiors, which is the same open ground a chamber has, arrived at by erosion instead of masonry.

local Caverns = {}

Caverns.name = "Caverns"

-- Measured off the rolled boards rather than derived from the fill rate: smoothing does not preserve
-- the initial proportion, it pushes it toward whichever side started ahead.
function Caverns.density() return 0.44 end

local FILL = 0.44          -- share of the interior that starts solid
local SMOOTHING = 4        -- passes of the 5-neighbour rule
local MIN_POCKET = 8       -- a cave smaller than this is filled in rather than tunnelled to

function Caverns.carve(grid)
    local m = grid.margin
    for y = 1 + m, grid.rows - m do
        for x = 1 + m, grid.cols - m do
            grid.cells[y][x].tile = (grid.rng:random() < FILL) and "thicket" or "path"
        end
    end

    for _ = 1, SMOOTHING do
        -- Written to a copy, or a pass would read tiles it had already rewritten and erode in the
        -- direction it happens to walk.
        local next_ = {}
        for y = 1, grid.rows do
            next_[y] = {}
            for x = 1, grid.cols do next_[y][x] = grid.cells[y][x].tile end
        end
        for y = 1 + m, grid.rows - m do
            for x = 1 + m, grid.cols - m do
                local solid = 0
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if (dx ~= 0 or dy ~= 0) and not grid:typeWalkable(
                            (grid.cells[y + dy] and grid.cells[y + dy][x + dx] or {}).tile or "thicket") then
                            solid = solid + 1
                        end
                    end
                end
                next_[y][x] = (solid >= 5) and "thicket" or "path"
            end
        end
        for y = 1, grid.rows do
            for x = 1, grid.cols do grid.cells[y][x].tile = next_[y][x] end
        end
    end

    -- One cave system, not a dozen. The largest pocket is the map; anything worth keeping is tunnelled
    -- into it and the rest is filled back in, so every walkable tile is reachable -- which the whole
    -- pipeline below assumes and the spec asserts.
    local pockets = Caverns.pockets(grid)
    table.sort(pockets, function(a, b) return #a > #b end)
    local main = pockets[1] or {}
    for i = 2, #pockets do
        local pocket = pockets[i]
        if #pocket < MIN_POCKET then
            for _, c in ipairs(pocket) do c.tile = "thicket" end
        else
            local best, bd = nil, math.huge
            for _, a in ipairs(pocket) do
                for _, b in ipairs(main) do
                    local d = math.abs(a.x - b.x) + math.abs(a.y - b.y)
                    if d < bd then bd, best = d, { a, b } end
                end
            end
            if best then grid:carveElbow(best[1].x, best[1].y, best[2].x, best[2].y) end
        end
    end
end

-- Connected components of walkable ground, as lists of cells.
function Caverns.pockets(grid)
    local seen, out = {}, {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            if grid:typeWalkable(c.tile) and not seen[grid:cellKey(x, y)] then
                local comp, q, qi = {}, { c }, 1
                seen[grid:cellKey(x, y)] = true
                while qi <= #q do
                    local cur = q[qi]; qi = qi + 1
                    comp[#comp + 1] = cur
                    for _, n in ipairs(grid:pathNeighbors(cur.x, cur.y)) do
                        if not seen[grid:cellKey(n.x, n.y)] then
                            seen[grid:cellKey(n.x, n.y)] = true
                            q[#q + 1] = n
                        end
                    end
                end
                out[#out + 1] = comp
            end
        end
    end
    return out
end

return Caverns
