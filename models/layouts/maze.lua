-- THE MAZE: a recursive backtracker over a lattice of nodes `spacing` apart, then a light braid to put
-- a few loops back. This is the carve every board in the game was built on, moved here unchanged so the
-- six grounds that follow can differ from it rather than from each other.
--
-- Corridors are one tile wide and the walls between them are (spacing - 1) thick, so `spacing` is the
-- whole character of the board: 2 is a warren, 4 is trails through thick wood, 5 is the desert's long
-- open tracks. It comes off the biome (data/biomes/<id>.lua).
--
-- BRAIDING DESTROYS EXACTLY THE GEOMETRY THE OFFER RULE NEEDS, which is why the rate is low and has to
-- stay low. A dead end is what a boon sits on and a cut vertex is what a guard stands on, so every braid
-- is one fewer place the board can make "the fight in the corridor to the reward" (Overworld:guardBoons).
-- Measured with `. board-report`: at the old 0.55 the board held two dead ends against four and a half
-- caches, 33% of boons were gateable at all, and 30% were actually guarded against a target of 80%. The
-- pairing pass was achieving 92% of what the geometry allowed and the geometry allowed almost nothing --
-- so the knob was misread for a whole pass as a shortage of FIGHTS. At 0.20: 3.9 dead ends, 73%
-- gateable, 57% guarded, and material income UP, because a guarded cache pays a bonus. Do not raise it
-- without re-running the report.
--
-- WHAT THIS CARVE CANNOT DO, measured rather than argued: a board of 1-wide corridors holds no OPEN
-- ground at all -- not one tile on a maze board has a full 3x3 of trail around it. That did not matter
-- while a fight was rolled on a separate 8x8 board, and it is the whole problem now that a fight is
-- taken on these very tiles. See models/layouts/glades.lua, which is this carve with the clearings a
-- battle needs opened into it.

local Maze = {}

Maze.name = "Maze"

-- Walkable share of the rectangle, for sizing only (Overworld's deriveDims). A lattice's density is
-- 1/spacing by construction, which is exactly the proxy the sizing rule used before layouts existed --
-- so every board this carve produces keeps the footprint it has always had.
function Maze.density(grid)
    return 1 / math.max(1, grid.spacing or 4)
end

function Maze.carve(grid)
    Maze.backtrack(grid)
    Maze.braid(grid, grid.braidRate)
end

-- Recursive backtracker over the spaced node grid. Each carved passage is a single-tile corridor;
-- walls between corridors are (spacing - 1) tiles thick. Returns the nodes it visited, in the order it
-- visited them, so a layout building on this one can open some of them out (see glades).
function Maze.backtrack(grid)
    local S = grid.spacing
    local dirs = { { S, 0 }, { -S, 0 }, { 0, S }, { 0, -S } }
    local visited = {}
    local sx, sy = 1 + grid.margin, 1 + grid.margin
    grid.cells[sy][sx].tile = "path"
    visited[grid:cellKey(sx, sy)] = true

    local stack = { { sx, sy } }
    local nodes = { { sx, sy } }
    while #stack > 0 do
        local cur = stack[#stack]
        local cx, cy = cur[1], cur[2]

        local cand = {}
        for _, d in ipairs(dirs) do
            local nx, ny = cx + d[1], cy + d[2]
            if grid:isNode(nx, ny) and not visited[grid:cellKey(nx, ny)] then
                cand[#cand + 1] = { nx, ny }
            end
        end

        if #cand > 0 then
            local pick = cand[grid.rng:random(#cand)]
            grid:carveCorridor(cx, cy, pick[1], pick[2])
            visited[grid:cellKey(pick[1], pick[2])] = true
            stack[#stack + 1] = { pick[1], pick[2] }
            nodes[#nodes + 1] = { pick[1], pick[2] }
        else
            stack[#stack] = nil
        end
    end
    return nodes
end

-- Add loops: for each node that is a dead-end (<=1 open passage), sometimes carve a corridor through to
-- a neighbouring node.
function Maze.braid(grid, prob)
    local S = grid.spacing
    local dirs = { { S, 0 }, { -S, 0 }, { 0, S }, { 0, -S } }
    for y = 1 + grid.margin, grid.rows - grid.margin, S do
        for x = 1 + grid.margin, grid.cols - grid.margin, S do
            local c = grid.cells[y] and grid.cells[y][x]
            if c and c.tile == "path" then
                local open, walls = 0, {}
                for _, d in ipairs(dirs) do
                    local nx, ny = x + d[1], y + d[2]
                    if grid:isNode(nx, ny) then
                        local ux = (d[1] > 0 and 1) or (d[1] < 0 and -1) or 0
                        local uy = (d[2] > 0 and 1) or (d[2] < 0 and -1) or 0
                        if grid.cells[y + uy][x + ux].tile == "path" then
                            open = open + 1
                        else
                            walls[#walls + 1] = { nx, ny }
                        end
                    end
                end
                if open <= 1 and #walls > 0 and grid.rng:random() < prob then
                    local w = walls[grid.rng:random(#walls)]
                    grid:carveCorridor(x, y, w[1], w[2])
                end
            end
        end
    end
end

return Maze
