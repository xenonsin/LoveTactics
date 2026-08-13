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
