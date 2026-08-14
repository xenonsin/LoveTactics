-- SANDS: the bowl. One enormous oval of floor with the stands all the way round it, a scatter of the
-- house's own furniture on it, and the pens cut into the corners underneath.
--
-- Every other ground answers "where can I go". This one answers nothing -- you can go anywhere, and so
-- can they, and that is the whole of it. It is the only board in the game with no route on it at all:
-- no corridor, no branch, no long way round. What a bout costs is decided entirely by what is standing
-- on the sand with you and where you stood when it started, which is what a colosseum is FOR. The
-- desert's plain is the nearest thing to it and is still a landscape you cross; this is a room you were
-- put in, and the shape says so -- the wall is the same distance away whichever way you run.
--
-- THREE THINGS ARE ON THE FLOOR, and none of them is terrain:
--
--   the barriers  short blocks of two to four tiles, set out for the card. Thin and few, because a bowl
--                 the crowd cannot see into is not a bowl -- they exist so a line has something to
--                 anchor on, never so a fight can be hidden behind one.
--   the pillars   single blocks. A body to break a charge on and a corner to be knocked into, the same
--                 job the Demon Champion's neck does (data/arenas/demon_champion.lua).
--   the pens      the reason this layout is possible at all. `placeObjectiveAndGates` needs a STRICT
--                 dead end to hang the objective and its gate chain on, and an open oval has no cut
--                 vertex anywhere -- the identical problem models/layouts/open.lua solved with its
--                 walled ruin. Here the answer was already in the fiction: the cells under the stands,
--                 each opening onto the sand through one mouth. A cage is a dead end that means
--                 something, and what waits at the end of the road is what the house keeps in it.
--
-- NOTHING IS ALLOWED TO SPLIT THE FLOOR. Each piece of furniture is laid, then taken back up again if
-- the sand is no longer one room with it there -- an arena that can be cut in two is a corridor with
-- delusions, and the checking is cheaper than the constraints that would prevent it.

local Sands = {}

Sands.name = "Sands"

-- Walkable share of the rectangle: an inscribed ellipse is pi/4 of it, less the furniture, plus what
-- the pens give back. Measured off the rolled boards, and deliberately the highest in the game -- this
-- ground is a floor with edges rather than a route through fill.
function Sands.density() return 0.74 end

-- The oval IS the outline, so the coastline pass would only chew the stands into a ragged cave mouth
-- (Overworld:weatherEdges). A bowl was built, and built round.
Sands.ownsEdge = true

-- HOW MUCH FURNITURE, AND WHERE. The unit this is tuned in is not the map, it is the FIGHT: a bout is
-- taken on an 8x8 window of these tiles (Arena.fromGrid), so the only question worth asking is what is
-- standing in one of those sixty-four.
--
-- Both earlier answers were wrong in the same direction. The first was tuned to keep the share of OPEN
-- ground high -- a claim about the board seen whole -- and put about two tiles of stone in a window: a
-- card fought in an empty room. The second raised the count and threw the pieces at random, which
-- clumps, so a quarter of the bowl still came out bare and a fight cut from it had nothing in it at
-- all. A floor with nothing on it is not a neutral floor; it is a floor with no decisions on it, and
-- this is the one ground where the terrain is the ONLY thing there is to use.
--
-- So the pieces sit on a lattice with a stride shorter than a board is wide, jittered off it. Every
-- window a fight can be cut from holds at least one lattice cell, so every fight has a lane to hold, a
-- corner to break a charge on, or a body to shoot past. It still cannot close the room: each piece is
-- laid and taken straight back up if the sand stops being one room with it there (see `place`), so how
-- dense this gets is bounded by the shape rather than by the count.
local FURNITURE_STEP = 4   -- a piece every four tiles each way: half the 8 a fight is cut at
local FURNITURE_JITTER = 2 -- ...moved off the lattice by up to this, so it never reads as a grid
local PILLAR_SHARE = 0.34  -- single blocks
local BARRIER_SHARE = 0.40 -- runs; the rest are two-deep stands
local BARRIER_MIN, BARRIER_MAX = 2, 5 -- how long a barrier runs
local FURNITURE_GAP = 2    -- tiles between two pieces, so they can never fuse into a wall
local PEN_W, PEN_H = 3, 2               -- a cell under the stands
local PENS_MIN, PENS_MAX = 3, 4         -- ...and how many of the four corners hold one

-- Is the whole floor still one room? A flood fill from any walkable tile, counted against every
-- walkable tile there is.
local function whole(grid)
    local start, total = nil, 0
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            if grid:typeWalkable(grid.cells[y][x].tile) then
                total = total + 1
                start = start or grid.cells[y][x]
            end
        end
    end
    if not start then return true end
    local seen = { [grid:cellKey(start.x, start.y)] = true }
    local q, qi, reached = { start }, 1, 0
    while qi <= #q do
        local cur = q[qi]; qi = qi + 1
        reached = reached + 1
        for _, n in ipairs(grid:pathNeighbors(cur.x, cur.y)) do
            local k = grid:cellKey(n.x, n.y)
            if not seen[k] then
                seen[k] = true
                q[#q + 1] = n
            end
        end
    end
    return reached == total
end

-- Lay a piece of furniture, and take it back up if the sand stopped being one room with it there.
local function place(grid, cells)
    local was = {}
    for i, c in ipairs(cells) do was[i] = c.tile end
    for _, c in ipairs(cells) do c.tile = "rock" end
    if whole(grid) then return true end
    for i, c in ipairs(cells) do c.tile = was[i] end
    return false
end

function Sands.carve(grid)
    local m = grid.margin
    local x0, x1 = 1 + m, grid.cols - m
    local y0, y1 = 1 + m, grid.rows - m
    local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    local rx, ry = math.max(1, (x1 - x0) / 2), math.max(1, (y1 - y0) / 2)

    -- Inside the bowl. The one geometric fact this whole ground is made of.
    local function onSand(x, y)
        local dx, dy = (x - cx) / rx, (y - cy) / ry
        return dx * dx + dy * dy <= 1
    end

    for y = y0, y1 do
        for x = x0, x1 do
            if onSand(x, y) then grid.cells[y][x].tile = "path" end
        end
    end

    -- Kept clear of the furniture already down, and of the wall -- a barrier laid against the stands
    -- is a pocket rather than a piece of cover, and the pens are the only pockets this floor wants.
    local taken = {}
    local function free(x, y, shape)
        for _, o in ipairs(shape) do
            local px, py = x + o[1], y + o[2]
            -- One tile of sand all round it, so nothing is set flush against the wall.
            for oy = -1, 1 do
                for ox = -1, 1 do
                    if not onSand(px + ox, py + oy) then return false end
                end
            end
            for _, t in ipairs(taken) do
                if math.abs(t.x - px) < FURNITURE_GAP and math.abs(t.y - py) < FURNITURE_GAP then
                    return false
                end
            end
        end
        return true
    end

    -- WHAT GETS SET DOWN. Three things, because one repeated shape is scenery and three read as a card
    -- somebody laid out: a single BLOCK to break a charge on, a RUN to hold a lane behind, and a
    -- two-deep STAND that a body can be lost behind entirely.
    local function shapeFor()
        local roll = grid.rng:random()
        if roll < PILLAR_SHARE then
            return { { 0, 0 } }
        elseif roll < PILLAR_SHARE + BARRIER_SHARE then
            local len = grid.rng:random(BARRIER_MIN, BARRIER_MAX)
            local horiz = grid.rng:random() < 0.5
            local out = {}
            for i = 0, len - 1 do out[#out + 1] = horiz and { i, 0 } or { 0, i } end
            return out
        end
        -- Two deep, never three by three: a square that size is a building, and it takes nine tiles of
        -- standing room out of a board that only has sixty-four.
        local w = grid.rng:random(2, 3)
        local h = (w == 3) and 2 or grid.rng:random(2, 3)
        local out = {}
        for j = 0, h - 1 do
            for i = 0, w - 1 do out[#out + 1] = { i, j } end
        end
        return out
    end

    -- Lay one piece near (ax, ay), trying a few nudges before giving up: a board with one piece fewer
    -- is not a problem, and a piece jammed anywhere it fits would be a grid.
    local function furnish(ax, ay)
        local shape = shapeFor()
        for _ = 1, 8 do
            local x = math.max(x0 + 1, math.min(x1 - 1, ax + grid.rng:random(-FURNITURE_JITTER, FURNITURE_JITTER)))
            local y = math.max(y0 + 1, math.min(y1 - 1, ay + grid.rng:random(-FURNITURE_JITTER, FURNITURE_JITTER)))
            if free(x, y, shape) then
                local cells = {}
                for _, o in ipairs(shape) do cells[#cells + 1] = grid.cells[y + o[2]][x + o[1]] end
                if place(grid, cells) then
                    for _, c in ipairs(cells) do taken[#taken + 1] = c end
                end
                return
            end
        end
    end

    -- WALKED, NOT THROWN. The count was right and the SPREAD was not: darts thrown at the floor clump,
    -- and what a clump leaves behind is the thing this is here to prevent -- a quarter of the bowl with
    -- nothing on it, which is an 8x8 window that is sixty-four tiles of nothing to think about. So the
    -- pieces sit on a lattice a stride shorter than a board is wide, jittered off it so it never reads
    -- as a grid: every window a fight can be cut from contains at least one lattice cell, so every fight
    -- has something in it.
    for ay = y0 + math.floor(FURNITURE_STEP / 2), y1, FURNITURE_STEP do
        for ax = x0 + math.floor(FURNITURE_STEP / 2), x1, FURNITURE_STEP do
            furnish(ax, ay)
        end
    end

    Sands.cutPens(grid, x0, x1, y0, y1, cx, cy, rx, ry, onSand)
end

-- WHERE THE COMPANY COMES IN AND WHERE THE CARD IS FOUGHT -- both named rather than found, because on
-- this one ground the shared rules produce the exact inverse of the place. `computeStart` takes the
-- walkable tile nearest the middle of the map, so the company would begin standing in the centre of the
-- sand with the crowd already watching; the objective goes on a far dead end, so the bout it came for
-- would be held in a cage under the stands. Both are correct on ground you are crossing. Neither is
-- correct in a bowl.
--
-- So: the fight is in the MIDDLE, where the floor is widest and everything on it can see you, and the
-- company walks in from the BOTTOM, through the gate at the near edge -- which is also the longest
-- approach the oval has, and the one the camera is already pointing down.
--
-- The gate chain goes with it, and that is deliberate rather than a casualty: a gate in the middle of an
-- open floor is walked around. Overworld:placeObjectiveAndGates skips the keys when the objective is not
-- a strict dead end, so a colosseum board has no locked doors on it. There are none in an arena.
function Sands.anchors(grid)
    local m = grid.margin
    local x0, x1 = 1 + m, grid.cols - m
    local y0, y1 = 1 + m, grid.rows - m
    local cx = (x0 + x1) / 2

    -- The nearest floor tile to a point, so furniture standing on the exact spot moves the anchor by a
    -- tile instead of dropping it. Ties break north-then-west, so a seed reproduces its board.
    local function nearest(tx, ty)
        local best, bestd
        for y = y0, y1 do
            for x = x0, x1 do
                if grid:typeWalkable(grid.cells[y][x].tile) then
                    local dx, dy = x - tx, y - ty
                    local d = dx * dx + dy * dy
                    if not bestd or d < bestd then bestd, best = d, grid.cells[y][x] end
                end
            end
        end
        return best
    end

    return nearest(cx, y1), nearest(cx, (y0 + y1) / 2)
end

-- The cells under the stands. Each is cut into a CORNER of the play rectangle -- ground the oval never
-- reaches, so a pen costs the floor nothing -- and joined to the sand by a single tunnel, which is the
-- cut vertex the guarded boons and the caches hang off.
function Sands.cutPens(grid, x0, x1, y0, y1, cx, cy, rx, ry, onSand)
    local corners = {
        { x = x0, y = y0, sx = 1, sy = 1 },
        { x = x1 - PEN_W + 1, y = y0, sx = -1, sy = 1 },
        { x = x0, y = y1 - PEN_H + 1, sx = 1, sy = -1 },
        { x = x1 - PEN_W + 1, y = y1 - PEN_H + 1, sx = -1, sy = -1 },
    }
    for i = #corners, 2, -1 do -- shuffled off the grid's own rng, so a seed reproduces its pens
        local j = grid.rng:random(i)
        corners[i], corners[j] = corners[j], corners[i]
    end

    local want = grid.rng:random(PENS_MIN, PENS_MAX)
    for i = 1, math.min(want, #corners) do
        local c = corners[i]
        -- A pen only goes in where the oval was never going to be: cutting one out of the sand would
        -- put a room inside the room.
        local clear = true
        for y = c.y, c.y + PEN_H - 1 do
            for x = c.x, c.x + PEN_W - 1 do
                if not grid.cells[y] or not grid.cells[y][x] or onSand(x, y) then clear = false end
            end
        end
        if clear then
            local cut = {}
            for y = c.y, c.y + PEN_H - 1 do
                for x = c.x, c.x + PEN_W - 1 do
                    cut[#cut + 1] = grid.cells[y][x]
                    grid.cells[y][x].tile = "path"
                end
            end
            -- The mouth: from the pen's inner corner, a staircase at the middle of the floor, stopping
            -- the moment it breaks through. It steps whichever axis is further out in the OVAL's own
            -- units rather than in tiles, which is what keeps it a short diagonal run under the stands
            -- -- a straight one takes the long way to a curved wall, and the first version of this pass
            -- opened the whole top row of the board doing it.
            local x = (c.sx > 0) and (c.x + PEN_W - 1) or c.x
            local y = (c.sy > 0) and (c.y + PEN_H - 1) or c.y
            local broke = false
            while x > x0 and x < x1 and y > y0 and y < y1 do
                if math.abs((cx - x) / rx) > math.abs((cy - y) / ry) then
                    x = x + c.sx
                else
                    y = y + c.sy
                end
                if grid:typeWalkable(grid.cells[y][x].tile) then
                    broke = true
                    break
                end
                cut[#cut + 1] = grid.cells[y][x]
                grid.cells[y][x].tile = "path"
            end
            -- A mouth that ran out of board before it found the sand would leave the pen an ISLAND, and
            -- an island reads to every pass downstream as a very small board rather than as a broken one
            -- (see tests/board_connectivity_spec.lua). It cannot happen on the oval this carve draws --
            -- the staircase is aimed at the middle of it -- which is exactly why the pen is filled back
            -- in rather than trusted: the day it can happen is the day someone changes the ellipse.
            if not broke then
                for _, cell in ipairs(cut) do cell.tile = "thicket" end
            end
        end
    end
end

return Sands
