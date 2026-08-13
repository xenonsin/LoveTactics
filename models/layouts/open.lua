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
--
-- A RIDGE IS A FLANK, NOT A WALL, and neither of the two things above was holding that line. Ridges are
-- laid as independent wandering lines, so nothing stopped three of them from meeting and closing a loop;
-- and the mouth was cut into the compound without ever asking what stood outside it. Both faults are
-- invisible in a mean and obvious in a picture, which is what `. board-render desert` is for -- sixty per
-- cent of desert boards came out in two or more pieces, the worst of them stranding 469 of 500-odd
-- walkable tiles behind rock, with the party spawned in the seven-tile pocket that was left. The
-- generator never noticed: computeStart takes the walkable tile nearest the centre without asking which
-- piece of the board it belongs to, and every pass after it works off a BFS from there, so a board in
-- pieces reads as a very small board rather than as a broken one.
--
-- So the carve owns its own connectivity, as the fractured and cellular grounds already do
-- (models/layouts/rifts.lua's stitch, models/layouts/caverns.lua's pockets): the mouth is guaranteed
-- ground outside it, and any piece the ridges cut off is either joined back through a gap in the ridge
-- or, if it is only a scrap, filled in as more ridge. Nothing downstream repairs this -- weathering and
-- the prune are both careful never to strand a tile, which is worth exactly nothing if the carve handed
-- them a board already in two.

local Caverns = require("models.layouts.caverns") -- pockets(): the connected-components walk, shared

local Open = {}

Open.name = "Open"

function Open.density() return 0.62 end

local RIDGES_MIN, RIDGES_MAX = 9, 14
local RUIN_W, RUIN_H = 11, 9
-- A cut-off piece smaller than this is filled in rather than joined. Punching a corridor out to a single
-- walled-in tile of sand would put a 1-wide dead end on the one board whose whole claim is that it has
-- no corridors; a scrap of plain inside a ridge is just more ridge.
local MIN_POCKET = 6

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

    local ruin = Open.raiseRuin(grid)
    Open.stitch(grid, ruin)
end

-- The ruin, in a corner so the road to it is a real road. Walled all round but one mouth. Returns its
-- rectangle, which is what the repair pass below must never cut through.
function Open.raiseRuin(grid)
    local m = grid.margin
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

    -- A MOUTH IS ONLY A MOUTH IF THERE IS GROUND OUTSIDE IT. The ridges are laid before the compound and
    -- knew nothing about it, so on a quarter of boards one of them came to rest across the approach and
    -- the door opened onto rock -- sixty-three tiles of walled interior plus the doorway, sealed, and
    -- unmistakable in the pocket census as a recurring pocket of exactly 64. So the approach is walked
    -- outward from the mouth until it reaches ground the plain already holds, clearing whatever the
    -- ridges left standing in it. Short by construction: the door faces the middle of the map, so this
    -- walks inward and stops at the first walkable tile, which on a plain is almost always the next one.
    local out = (doorY == ry) and -1 or 1
    local y = doorY + out
    while grid.cells[y] and y > m and y <= grid.rows - m do
        local c = grid.cells[y][doorX]
        if grid:typeWalkable(c.tile) then break end
        c.tile = "path"
        y = y + out
    end

    return { x0 = rx, y0 = ry, x1 = rx + RUIN_W - 1, y1 = ry + RUIN_H - 1 }
end

-- Join every piece the ridges cut off back to the largest one, so the plain is one plain. The gap it
-- opens is a gap in a RIDGE, which is the shape this ground already means: a ridge you can walk around
-- is a flank, and one you cannot is a corridor the desert was built not to have.
function Open.stitch(grid, ruin)
    local pockets = Caverns.pockets(grid)
    if #pockets < 2 then return end
    table.sort(pockets, function(a, b) return #a > #b end)
    local main = pockets[1]

    -- Would the elbow from a to b breach the compound? The gate chain needs the ruin to have exactly one
    -- mouth, so a second gap punched anywhere in its wall would undo the only reason it stands there --
    -- and since the interior is part of the main piece (the approach above sees to that), the nearest
    -- ground to a pocket beside the ruin is otherwise the ground on the wrong side of its wall.
    local function overlaps(lo, hi, r0, r1) return hi >= r0 and lo <= r1 end
    local function clearsRuin(a, b)
        if not ruin then return true end
        -- carveElbow runs along x at a.y, then along y at b.x.
        if a.y >= ruin.y0 and a.y <= ruin.y1
            and overlaps(math.min(a.x, b.x), math.max(a.x, b.x), ruin.x0, ruin.x1) then return false end
        if b.x >= ruin.x0 and b.x <= ruin.x1
            and overlaps(math.min(a.y, b.y), math.max(a.y, b.y), ruin.y0, ruin.y1) then return false end
        return true
    end

    for i = 2, #pockets do
        local pocket = pockets[i]
        if #pocket < MIN_POCKET then
            for _, c in ipairs(pocket) do c.tile = "rock" end
        else
            local best, bd
            for _, a in ipairs(pocket) do
                -- Two disjoint pieces can be no closer than a single tile of rock apart, so a pair at 2
                -- is the best there is and the rest of the scan cannot improve on it.
                if bd and bd <= 2 then break end
                for _, b in ipairs(main) do
                    local d = math.abs(a.x - b.x) + math.abs(a.y - b.y)
                    if (not bd or d < bd) and clearsRuin(a, b) then bd, best = d, { a, b } end
                end
            end
            if best then
                grid:carveElbow(best[1].x, best[1].y, best[2].x, best[2].y)
            else
                -- Nothing to join to that does not go through the compound. Only reachable by a piece
                -- walled in behind the ruin, and a piece nobody can stand on is better as more ridge.
                for _, c in ipairs(pocket) do c.tile = "rock" end
            end
        end
    end
end

return Open
