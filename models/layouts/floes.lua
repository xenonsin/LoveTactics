-- FLOES: open flats, quartered by meltwater, with bridges for doors.
--
-- Open like the desert and structured like nothing else. Three or four channels cut the flats into
-- lobes and each channel is crossed in only one or two places, so the board is a handful of big rooms
-- whose doors happen to be water crossings. Long open walking, and a small number of decisions that
-- matter enormously.
--
-- IT IS THE GROUND WHERE THE UNIFICATION PAYS MOST VISIBLY. A crossing used to be a PROFILE -- the
-- arena rolled a channel across the middle with one ford because the overworld tile you stood on had
-- water near it. Now the channel is the actual river, running where it runs, with the ford where the
-- ford is. `band = "cross"` made of real water.
--
-- Declares ownsWater, so the shared river pass is scoped off it: that pass assumes a lattice to run
-- between, and thinBridges would demote a wide crossing back to plain trail (docs/overworld.md, C2).
-- The one-tile ford is guaranteed here instead, where the water is drawn.

local Floes = {}

Floes.name = "Floes"
Floes.ownsWater = true

function Floes.density() return 0.58 end

local LEADS_MIN, LEADS_MAX = 3, 4
local DRIFTS = 14

function Floes.carve(grid)
    local m = grid.margin
    for y = 1 + m, grid.rows - m do
        for x = 1 + m, grid.cols - m do
            grid.cells[y][x].tile = "path"
        end
    end

    -- Drifts: scattered solid, so the flats are not a featureless sheet. Small and rounded -- a drift is
    -- something to put your back against, not something to route around.
    for _ = 1, DRIFTS do
        local x = grid.rng:random(2 + m, grid.cols - m - 1)
        local y = grid.rng:random(2 + m, grid.rows - m - 1)
        for _ = 1, grid.rng:random(3, 7) do
            local c = grid.cells[y] and grid.cells[y][x]
            if c then c.tile = "rock" end
            x = x + grid.rng:random(-1, 1)
            y = y + grid.rng:random(-1, 1)
            if x <= m + 1 or y <= m + 1 or x > grid.cols - m - 1 or y > grid.rows - m - 1 then break end
        end
    end

    for _ = 1, grid.rng:random(LEADS_MIN, LEADS_MAX) do
        Floes.lead(grid)
    end

    Floes.ford(grid)
end

-- EVERY LOBE KEEPS A WAY OUT.
--
-- Each lead picks its own crossings, which is enough while leads are the only thing on the board -- and
-- is not enough once they cross each other. A second lead laid over another's ford seals it; two leads
-- meeting in a corner cut it off entirely. Measured on the first tundra boards ever rolled: 454 of 752
-- walkable tiles unreachable from the start, on a board that passed every other check, because nothing
-- downstream asks whether the water it was handed left the map in one piece.
--
-- So the crossings are repaired after all the water is down rather than promised while it is going in.
-- A river tile touching two separate pieces of land becomes a ford, which is both the cheapest repair
-- and the right-looking one: the crossing appears where the channel is narrow enough to have one.
--
-- This is where `band = "cross"` went (docs/overworld.md, U6). The arena used to promise a rolled
-- crossing exactly one free ford so the board could never be cut in half; the promise now lives where
-- the water is drawn, and means the same thing about real water.
function Floes.ford(grid)
    local Caverns = require("models.layouts.caverns")
    for _ = 1, 8 do
        local pockets = Caverns.pockets(grid)
        if #pockets <= 1 then return end

        -- Label every walkable tile with the piece of land it belongs to.
        local piece = {}
        for i, pocket in ipairs(pockets) do
            for _, c in ipairs(pocket) do piece[grid:cellKey(c.x, c.y)] = i end
        end

        -- A river tile with land of two different pieces on either side is exactly a place a ford
        -- belongs. EVERY such tile in the pass, not the first: a board cut into six lobes needs five
        -- crossings, and opening one per pass would need as many passes as there are pieces. Walked in a
        -- fixed order so a seed reproduces its crossings.
        local opened = false
        for y = 1, grid.rows do
            for x = 1, grid.cols do
                if grid.cells[y][x].tile == "river" then
                    local seen = {}
                    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                        local p = piece[grid:cellKey(x + d[1], y + d[2])]
                        if p then seen[p] = true end
                    end
                    local n = 0
                    for _ in pairs(seen) do n = n + 1 end
                    if n >= 2 then
                        grid.cells[y][x].tile = "bridge"
                        opened = true
                    end
                end
            end
        end

        -- Nothing narrow enough to ford: cut a channel through to the largest piece instead. A board in
        -- two halves is not a board, and this is the backstop that guarantees it never ships as one.
        if not opened then
            table.sort(pockets, function(a, b) return #a > #b end)
            local a, b = pockets[2][1], pockets[1][1]
            local bd = math.huge
            for _, p in ipairs(pockets[2]) do
                for _, q in ipairs(pockets[1]) do
                    local d = math.abs(p.x - q.x) + math.abs(p.y - q.y)
                    if d < bd then bd, a, b = d, p, q end
                end
            end
            grid:carveElbow(a.x, a.y, b.x, b.y)
        end
    end
end

-- One meltwater channel, edge to edge, crossed once or twice.
function Floes.lead(grid)
    local m = grid.margin
    local horiz = grid.rng:random() < 0.5
    local span = horiz and grid.cols or grid.rows
    local limit = (horiz and grid.rows or grid.cols) - m - 1
    local c = grid.rng:random(m + 3, math.max(m + 3, limit - 2))

    -- Where the fords go, chosen up front so a channel always has at least one and the lobes it makes
    -- are never sealed off. Everything below is connectivity-critical: a lead with no crossing would
    -- cut the board in half and the objective might be on the wrong side of it.
    local fords = {}
    for _ = 1, (grid.rng:random() < 0.55 and 1 or 2) do
        fords[#fords + 1] = grid.rng:random(m + 3, span - m - 3)
    end

    for main = 1 + m, span - m do
        local x = horiz and main or c
        local y = horiz and c or main
        local isFord = false
        for _, f in ipairs(fords) do if f == main then isFord = true break end end
        local cell = grid.cells[y] and grid.cells[y][x]
        if cell then cell.tile = isFord and "bridge" or "river" end

        if not isFord and grid.rng:random() < 0.26 then
            local nc = c + (grid.rng:random() < 0.5 and 1 or -1)
            if nc >= m + 3 and nc <= limit - 2 then
                -- Lay the corner as well, or the channel is only diagonally connected and the flats walk
                -- straight through the gap -- which would make the lobes, and the fords, meaningless.
                local cx = horiz and main or nc
                local cy = horiz and nc or main
                local corner = grid.cells[cy] and grid.cells[cy][cx]
                if corner then corner.tile = "river" end
                c = nc
            end
        end
    end
end

return Floes
