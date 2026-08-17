-- GLADES: the maze, opened. The same recursive backtracker and the same braid rate, with clearings
-- carved at a spread of the lattice nodes.
--
-- The maze alone cannot hold a battle, and that is measured rather than argued: a board of 1-wide
-- corridors has ZERO open tiles on it -- not one tile with a full 3x3 of trail around it -- and seats
-- its fights at about 20 walkable tiles of the 64 a locked board holds, which is at or below the bare
-- minimum for four bodies to stand and move. Now that a fight is taken on these tiles rather than on a
-- board rolled to resemble them, that is the difference between a trail and a game.
--
-- So the trail stays a trail and periodically opens out. The corridors are still one tile wide, the
-- fill is still thick wood, and the character of walking it is unchanged -- what changes is that every
-- few junctions there is somewhere a fight can actually happen, and the placement pass seats fights
-- there (Overworld.BOX_OK).
--
-- WHY A SPREAD OF NODES AND NOT A SHARE OF THEM. Rolling each node independently at some probability
-- clumps: two clearings on adjacent nodes merge into one field, and a board gets one big opening and
-- four corridors instead of five glades. Clearings are chosen greedily with a minimum separation
-- instead, so they land as distinct rooms with trail between them -- which is the shape the offer rule
-- wants anyway, since a fight in a glade guards the corridor out of it.
--
-- A CLEARING OPENS A JUNCTION AND NEVER A SPUR, and this rule was learned the same way braiding's rate
-- was, by breaking the board and reading the report. Carved at any node, clearings took the guarded
-- share from 60% to 27% and the dead ends from 4.1 to 2.6 -- because a dead end is what a boon sits on
-- and a cut vertex is what a guard stands on, and opening a room over either one deletes it. It is the
-- identical failure docs/overworld.md records for the braid rate, arrived at from a different direction.
--
-- So a glade lands where trails MEET: a node with three or more passages, kept clear of any spur end by
-- more than its own radius. The spurs stay narrow, keep their dead ends, and keep the corridor that
-- gates them -- and the rooms end up on the through-routes, which is where a fight you can walk around
-- belongs anyway.

local Maze = require("models.layouts.maze")

local Glades = {}

Glades.name = "Glades"

-- How far apart clearings must sit, as a multiple of the lattice spacing. Two, so there is always at
-- least one whole node of corridor between two rooms and they cannot fuse.
local SEPARATION = 1.5

-- How many clearings a board gets, against how many nodes it has. A board seats four or five fights and
-- the fightability floor asks for one good site per fight, so this is deliberately a little generous:
-- an unclaimed glade is a place the player passes through, which is worth having.
local PER_NODES = 4
local MIN_CLEARINGS, MAX_CLEARINGS = 5, 14

Glades.density = Maze.density

-- How many carved passages leave this node, counted on the lattice: 1 is a spur end, 3 or more is a
-- junction. Read AFTER the braid, so a loop the braid put back counts as the passage it is.
local function passages(grid, x, y)
    local S = grid.spacing
    local n = 0
    for _, d in ipairs({ { S, 0 }, { -S, 0 }, { 0, S }, { 0, -S } }) do
        local ux = (d[1] > 0 and 1) or (d[1] < 0 and -1) or 0
        local uy = (d[2] > 0 and 1) or (d[2] < 0 and -1) or 0
        if grid:isNode(x + d[1], y + d[2]) and grid.cells[y + uy][x + ux].tile == "path" then
            n = n + 1
        end
    end
    return n
end

function Glades.carve(grid)
    local nodes = Maze.backtrack(grid)
    Maze.braid(grid, grid.braidRate)

    -- Sort the nodes into the two kinds this pass cares about. Spur ends are what the offer rule is
    -- built on and are never touched; junctions are where a room may go.
    local spurs, junctions = {}, {}
    for _, n in ipairs(nodes) do
        local p = passages(grid, n[1], n[2])
        if p <= 1 then
            spurs[#spurs + 1] = n
        else
            -- Any THROUGH node, not only a three-way meeting. Restricting glades to junctions was the
            -- first attempt and it starved the board: a perfect maze is mostly degree-2, so junctions
            -- are a sixth of the nodes, and after separation and the spur rule two clearings landed on a
            -- 41x29 board. A bend in the trail is as good a place to widen as a fork, and what actually
            -- has to be protected is the spur END, which the radius rule below does directly.
            junctions[#junctions + 1] = n
        end
    end

    -- Shuffled off the grid's own rng, so a seed reproduces its clearings exactly like everything here.
    for i = #junctions, 2, -1 do
        local j = grid.rng:random(i)
        junctions[i], junctions[j] = junctions[j], junctions[i]
    end

    local want = math.max(MIN_CLEARINGS,
        math.min(MAX_CLEARINGS, math.floor(#nodes / PER_NODES)))
    local gap = grid.spacing * SEPARATION
    local taken = {}

    for _, n in ipairs(junctions) do
        if #taken >= want then break end
        local x, y = n[1], n[2]
        local radius = grid.rng:random(3, 5)
        -- Keep a clearing off the buffer ring: a room half-eaten by the map edge is not a room, and the
        -- margin exists so no trail ever hugs the border.
        local edge = grid.margin + radius
        if x > edge and y > edge and x <= grid.cols - edge and y <= grid.rows - edge then
            local clear = true
            for _, t in ipairs(taken) do
                if math.abs(t[1] - x) < gap and math.abs(t[2] - y) < gap then
                    clear = false
                    break
                end
            end
            -- A ROOM SHRINKS TO SPARE A SPUR RATHER THAN STANDING DOWN FOR ONE. The thing that must be
            -- protected is small -- the dead-end tile a boon sits on, and the tile beside it that gates
            -- it -- and rejecting a whole clearing to protect it is enormously more expensive than
            -- trimming a tile off the radius.
            --
            -- Both wrong answers were measured. Reject-if-near took fightability to 19.9%, because on a
            -- 4-spaced lattice a maze's spur ends are everywhere and almost every node has one within
            -- five tiles. Carve-anyway took the guarded share from 60% to 27%, which is the braid rate's
            -- failure exactly: a room over a dead end deletes the dead end. Shrinking satisfies both.
            if clear then
                for _, s in ipairs(spurs) do
                    local dx, dy = s[1] - x, s[2] - y
                    local d = math.floor(math.sqrt(dx * dx + dy * dy))
                    -- Stay ONE tile clear: the spur end itself, and nothing more.
                    --
                    -- It used to be two, reserving the cut vertex beside the spur end so "a guard has to
                    -- be able to stand on" it -- and that was right about which tile the guard takes and
                    -- wrong about what standing there means. It reserved that tile as CORRIDOR, and a
                    -- guard is a fight now: the reservation was handing every guarded boon on this
                    -- ground a fight in a hallway. Measured with `. board-report`, once the seat floor
                    -- reached this pass, forest kept only 16% of its guarded boons -- not for want of
                    -- cut vertices (96% of boons have one) but because the layout had deliberately put
                    -- every one of them outside the room.
                    --
                    -- At one, the clearing's rim IS the cut vertex. The spur end keeps its single
                    -- neighbour and stays a strict dead end -- everything the offer rule needs -- and
                    -- the tile that gates it now looks into the glade, so the fight standing in the
                    -- doorway is fought in the room behind it (Overworld.BOX_OPEN scores the window, not
                    -- the tile).
                    if d - 1 < radius then radius = d - 1 end
                end
                -- Below 3 a disc has no interior, so every tile in it still has wall in its 3x3 and it
                -- would add walkable ground without adding anywhere to fight. Not worth carving.
                if radius < 3 then clear = false end
            end
            if clear then
                taken[#taken + 1] = { x, y }
                -- Radius 3 is the smallest disc whose interior holds open ground: at 2 the whole blob is
                -- edge, and every tile in it still has wall in its 3x3.
                grid:carveBlob(x, y, radius, "path")
            end
        end
    end
end

return Glades
