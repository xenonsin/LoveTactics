-- RIFTS: the walkable part is the cracks, and where they cross the rock has fallen away.
--
-- Long straight fractures through cooled stone, two or three tiles wide, meeting at chambers. Not carved
-- like a maze and not grown like a cave -- FRACTURED, which is a third thing and looks like neither.
--
-- The width is the lesson from the forest, applied before it had to be learned twice: a 1-tile crack is
-- unfightable ground, exactly as a 1-tile trail was, and a ground whose corridors are all it has must
-- make those corridors wide enough to stand in. The chambers at the junctions are where the fights go.
--
-- Lava does the rest. It is the one blocker that does NOT block a line of sight (models/terrain.lua), so
-- a rift board is the only place where the walls of the locked box and the walls inside it behave
-- differently: you are shut in with an enemy you can see across a flow and cannot reach except the long
-- way round. Flows are laid before the network is stitched back together, so a flow that severs a rift
-- is answered by a join rather than by a board in two pieces.

local Rifts = {}

Rifts.name = "Rifts"
Rifts.ownsWater = true -- the flows are lava, and they are this carve's own

function Rifts.density() return 0.34 end

local CRACKS_MIN, CRACKS_MAX = 5, 7
local FLOWS = 2

function Rifts.carve(grid)
    local m = grid.margin
    local junctions = {}

    -- EVERY FRACTURE AFTER THE FIRST STARTS ON AN EXISTING ONE, so the network is connected by
    -- construction. Starting each crack at a random point instead left stranded pieces that had to be
    -- joined afterwards by long corridors across the map -- and pruneDeadStubs then peeled those
    -- corridors back one tile per pass, which on some seeds took tens of seconds. A board that has to be
    -- repaired after the fact is usually a board that was carved wrong; stone splits from stone anyway.
    local carved = {}
    for _ = 1, grid.rng:random(CRACKS_MIN, CRACKS_MAX) do
        local x, y
        if #carved > 0 then
            local seedTile = carved[grid.rng:random(#carved)]
            x, y = seedTile[1], seedTile[2]
        else
            x = grid.rng:random(m + 4, grid.cols - m - 4)
            y = grid.rng:random(m + 4, grid.rows - m - 4)
        end
        local dx, dy
        if grid.rng:random() < 0.5 then
            dx, dy = (grid.rng:random() < 0.5 and 1 or -1), 0
        else
            dx, dy = 0, (grid.rng:random() < 0.5 and 1 or -1)
        end
        local wide = grid.rng:random(2, 3)
        junctions[#junctions + 1] = { x, y }

        for _ = 1, grid.rng:random(14, 28) do
            for w = 0, wide - 1 do
                local ox = dx ~= 0 and 0 or (w - math.floor(wide / 2))
                local oy = dx ~= 0 and (w - math.floor(wide / 2)) or 0
                local c = grid.cells[y + oy] and grid.cells[y + oy][x + ox]
                if c and x + ox > m and y + oy > m
                    and x + ox <= grid.cols - m and y + oy <= grid.rows - m then
                    c.tile = "path"
                end
            end
            carved[#carved + 1] = { x, y }
            x, y = x + dx, y + dy
            -- A fracture turns at a right angle rather than curving: it is stone giving way along a
            -- plane, not water finding a course.
            if grid.rng:random() < 0.13 then
                junctions[#junctions + 1] = { x, y }
                local t = dx
                dx = dy * (grid.rng:random() < 0.5 and 1 or -1)
                dy = t * (grid.rng:random() < 0.5 and 1 or -1)
            end
            if x <= m + 3 or y <= m + 3 or x > grid.cols - m - 3 or y > grid.rows - m - 3 then
                x = math.max(m + 3, math.min(grid.cols - m - 3, x))
                y = math.max(m + 3, math.min(grid.rows - m - 3, y))
                dx, dy = -dx, -dy
            end
        end
        junctions[#junctions + 1] = { x, y }
    end

    -- Where fractures meet or turn, the rock between them has dropped out. These are the boards.
    for _, j in ipairs(junctions) do
        if grid.rng:random() < 0.5 then
            grid:carveBlob(j[1], j[2], grid.rng:random(3, 4), "path")
        end
    end

    -- Flows down some of the rifts, then the network is stitched back into one piece.
    for _ = 1, FLOWS do
        local cells = {}
        for y = 1, grid.rows do
            for x = 1, grid.cols do
                if grid.cells[y][x].tile == "path" then cells[#cells + 1] = grid.cells[y][x] end
            end
        end
        if #cells == 0 then break end
        local cur = cells[grid.rng:random(#cells)]
        for _ = 1, grid.rng:random(6, 14) do
            local nbs = {}
            for _, n in ipairs(grid:pathNeighbors(cur.x, cur.y)) do
                if n.tile == "path" then nbs[#nbs + 1] = n end
            end
            if #nbs == 0 then break end
            cur.tile = "lava"
            cur = nbs[grid.rng:random(#nbs)]
        end
    end

    Rifts.stitch(grid)
end

-- Join every stranded piece back to the largest one, so the whole rift network is walkable.
function Rifts.stitch(grid)
    local Caverns = require("models.layouts.caverns")
    local pockets = Caverns.pockets(grid)
    table.sort(pockets, function(a, b) return #a > #b end)
    local main = pockets[1] or {}
    for i = 2, #pockets do
        local best, bd = nil, math.huge
        for _, a in ipairs(pockets[i]) do
            for _, b in ipairs(main) do
                local d = math.abs(a.x - b.x) + math.abs(a.y - b.y)
                if d < bd then bd, best = d, { a, b } end
            end
        end
        if best then grid:carveElbow(best[1].x, best[1].y, best[2].x, best[2].y) end
    end
end

return Rifts
