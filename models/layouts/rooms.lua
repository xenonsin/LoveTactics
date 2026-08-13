-- ROOMS: a stronghold is chambers joined by halls, and the interesting tile is always the doorway.
--
-- Recursive binary splits down to a minimum size, a chamber inset in each leaf, and the chambers strung
-- together with L-corridors. Replaces the castle's old `spacing = 2`, which made it "the forest, but
-- cramped" -- a 1-tile-walled warren that measured 34 walkable tiles in a locked board and was
-- unfightable anyway, because every one of those tiles was a corridor with wall on both sides. Room for
-- four bodies; no room for a decision.
--
-- Under one map a room is literally an arena, which is why this is the ground the whole idea reads most
-- naturally on: you fight in the hall you walked into, and the door you came through is the door the
-- enemy has to hold.
--
-- IT ALSO GIVES THE OFFER RULE ITS BEST GEOMETRY. Every chamber hangs off the chain by one corridor, so
-- doorways are cut vertices in quantity -- a cache in a side-chamber behind a sentry in its door is the
-- offer rule in its purest form, and needs no spur to exist at all.

local Rooms = {}

Rooms.name = "Rooms"

-- The one ground whose outline is not weathered (Overworld:weatherEdges). Everywhere else a straight
-- wall a whole board long is the generator showing through; here it is the curtain wall, and a stronghold
-- with a coastline for a perimeter is not a stronghold.
Rooms.ownsEdge = true

-- Walkable share, for sizing only. Chambers fill most of their leaf and the halls are thin, so a little
-- over a third of the rectangle ends up floor -- measured, not derived.
function Rooms.density() return 0.38 end

-- A leaf small enough to stop splitting. Both are above the arena box's 8 for a reason: a chamber that
-- cannot contain a board is a cupboard, and the whole point of this carve is that a room is a fight.
local MIN_W, MIN_H = 11, 9

function Rooms.carve(grid)
    local m = grid.margin
    local leaves = {}

    local function split(x, y, w, h, depth)
        local canH = w > MIN_W * 2
        local canV = h > MIN_H * 2
        if depth > 5 or (not canH and not canV) then
            leaves[#leaves + 1] = { x, y, w, h }
            return
        end
        -- Prefer cutting the long way, so leaves stay squarish and every chamber can hold a board.
        local horiz = canH and (not canV or (w >= h and grid.rng:random() < 0.75) or grid.rng:random() < 0.25)
        if horiz then
            local cut = grid.rng:random(MIN_W, w - MIN_W)
            split(x, y, cut, h, depth + 1)
            split(x + cut, y, w - cut, h, depth + 1)
        else
            local cut = grid.rng:random(MIN_H, h - MIN_H)
            split(x, y, w, cut, depth + 1)
            split(x, y + cut, w, h - cut, depth + 1)
        end
    end
    split(1 + m, 1 + m, grid.cols - 2 * m, grid.rows - 2 * m, 0)

    -- A chamber inset in each leaf, leaving real masonry between rooms so the doorway is the only way
    -- through. Sized generously -- at least 8 on a side wherever the leaf allows -- because that is the
    -- board.
    local centres = {}
    for _, leaf in ipairs(leaves) do
        local x, y, w, h = leaf[1], leaf[2], leaf[3], leaf[4]
        local rw = math.max(6, math.min(w - 2, grid.rng:random(math.floor(w * 0.6), w - 2)))
        local rh = math.max(5, math.min(h - 2, grid.rng:random(math.floor(h * 0.6), h - 2)))
        local rx = x + grid.rng:random(1, math.max(1, w - rw - 1))
        local ry = y + grid.rng:random(1, math.max(1, h - rh - 1))
        for j = ry, ry + rh - 1 do
            for i = rx, rx + rw - 1 do
                local c = grid.cells[j] and grid.cells[j][i]
                if c then c.tile = "path" end
            end
        end
        centres[#centres + 1] = { rx + math.floor(rw / 2), ry + math.floor(rh / 2) }
    end

    -- Halls, as a nearest-neighbour spanning TREE rather than a chain.
    --
    -- The chain was the first attempt and it guarded 1.6% of its boons. A chain has one route through
    -- every room, so every room is on the objective spine -- and combat is kept off the spine so a
    -- wounded company can always reach the boss, which meant no door on the board could seat a guard.
    -- The carve had produced a doorway for every chamber and the rule could use none of them.
    --
    -- A tree branches: the spine runs through some chambers and the rest hang off it, each by a single
    -- hall, each ending in a room that is a genuine dead end. That is the same shape a maze's spurs give
    -- the forest, built out of rooms instead of corridors.
    --
    -- A spanning tree and never a mesh: every extra hall is one fewer cut vertex, which is the braid
    -- rate's lesson wearing a different hat.
    local linked = { centres[1] }
    local rest = {}
    for i = 2, #centres do rest[#rest + 1] = centres[i] end
    while #rest > 0 do
        local bi, bj, bd = 1, 1, math.huge
        for i, a in ipairs(linked) do
            for j, b in ipairs(rest) do
                local d = math.abs(a[1] - b[1]) + math.abs(a[2] - b[2])
                if d < bd then bi, bj, bd = i, j, d end
            end
        end
        local a, b = linked[bi], rest[bj]
        grid:carveCorridor(a[1], a[2], b[1], a[2])
        grid:carveCorridor(b[1], a[2], b[1], b[2])
        linked[#linked + 1] = b
        table.remove(rest, bj)
    end
end

return Rooms
