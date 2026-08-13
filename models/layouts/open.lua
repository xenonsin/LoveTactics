-- OPEN: a plain with ridges, and one walled ruin.
--
-- data/biomes/desert.lua already says what this ground is and a maze cannot say it: "there is nowhere to
-- be that is not seen". So the desert stops being the loosest maze in the game and becomes the only
-- board that is mostly walkable -- long thin rock ridges that make LANES rather than corridors, and
-- sightlines that run the width of the map.
--
-- It inverts every other ground's problem. Everywhere else the question is whether there is room to
-- fight; here there always is, and what varies is whether you get to CHOOSE where. Fight beside a ridge
-- and you have a flank to hold; get caught mid-plain and you have none, which is the desert's whole
-- tactical claim made geographic.
--
-- THE RUIN IS NOT DECORATION. Keys and gates only mean anything if the objective's approach can be
-- sealed, and an open plain has no cut vertices at all -- placeObjectiveAndGates insists on a strict
-- dead end for exactly that reason, because a degree-2 tile has a second route the gate never covers.
-- So the carve leaves one enclosed compound with a single mouth. It is the lockable structure the gate
-- chain needs, and it is a place rather than a technical patch: the thing at the end of the road is a
-- ruin you can see from outside and walk up to.

local Open = {}

Open.name = "Open"

function Open.density() return 0.62 end

local RIDGES_MIN, RIDGES_MAX = 9, 14
local RUIN_W, RUIN_H = 11, 9

function Open.carve(grid)
    local m = grid.margin
    for y = 1 + m, grid.rows - m do
        for x = 1 + m, grid.cols - m do
            grid.cells[y][x].tile = "path"
        end
    end

    -- Ridges: long, thin, mostly straight, with a wander so they read as landform rather than as walls.
    -- Thin on purpose -- a ridge you can walk around in three steps is a flank, where a thick one is a
    -- corridor, and corridors are what this ground exists not to have.
    for _ = 1, grid.rng:random(RIDGES_MIN, RIDGES_MAX) do
        local x = grid.rng:random(2 + m, grid.cols - m - 1)
        local y = grid.rng:random(2 + m, grid.rows - m - 1)
        local horiz = grid.rng:random() < 0.62
        local len = grid.rng:random(8, horiz and 22 or 13)
        for _ = 1, len do
            local c = grid.cells[y] and grid.cells[y][x]
            if not c then break end
            c.tile = "rock"
            if grid.rng:random() < 0.35 then
                local n = grid.cells[y + (grid.rng:random() < 0.5 and 1 or -1)]
                if n and n[x] then n[x].tile = "rock" end
            end
            if horiz then
                x = x + 1
                if grid.rng:random() < 0.22 then y = y + (grid.rng:random() < 0.5 and 1 or -1) end
            else
                y = y + 1
                if grid.rng:random() < 0.22 then x = x + (grid.rng:random() < 0.5 and 1 or -1) end
            end
            if x <= m + 1 or y <= m + 1 or x > grid.cols - m - 1 or y > grid.rows - m - 1 then break end
        end
    end

    -- The ruin, in a corner so the road to it is a real road. Walled all round but one mouth.
    local rx = (grid.rng:random() < 0.5) and (m + 2) or (grid.cols - m - RUIN_W - 1)
    local ry = (grid.rng:random() < 0.5) and (m + 2) or (grid.rows - m - RUIN_H - 1)
    for j = ry, ry + RUIN_H - 1 do
        for i = rx, rx + RUIN_W - 1 do
            local c = grid.cells[j] and grid.cells[j][i]
            if c then
                local edge = (i == rx or i == rx + RUIN_W - 1 or j == ry or j == ry + RUIN_H - 1)
                c.tile = edge and "rock" or "path"
            end
        end
    end
    -- One mouth, on the side facing the middle of the map, so the compound is approached rather than
    -- stumbled into from behind.
    local midY = math.floor(grid.rows / 2)
    local doorY = (ry < midY) and (ry + RUIN_H - 1) or ry
    local doorX = rx + grid.rng:random(2, RUIN_W - 3)
    local door = grid.cells[doorY] and grid.cells[doorY][doorX]
    if door then door.tile = "path" end
end

return Open
