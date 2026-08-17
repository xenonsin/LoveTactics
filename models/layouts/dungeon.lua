-- THE DUNGEON: a warren of one-tile corridors with chambers cut into it. The carve a descent floor is
-- laid on, and the only one in the game written for a place you go DOWN into rather than a country you
-- cross.
--
-- WHY IT EXISTS, measured rather than argued. A descent floor used to inherit its biome's layout, which
-- meant it inherited a campaign GROUND -- volcanic gets `rifts`, desert gets `sands`, and those carve
-- open country with a road through it, because that is what a quest board's leg is. Walked with a
-- stopwatch, at a 20x20 play area:
--
--   biome default (rifts)   237 walkable   deepest point 19 tiles   1.9s round trip
--   this, at spacing 2      278 walkable   deepest point 74 tiles   7.4s round trip
--
-- Nineteen tiles is not a dungeon. It is a courtyard, and everything a descent wants to put on a floor --
-- a way up worth walking back to, ground worth mapping, somewhere for a chute to drop you that you then
-- have to walk out of -- needs distance to be about.
--
-- AND THE LEVER IS SPACING, NOT SIZE. This was the surprising half. Growing the rectangle barely moves
-- the distance: 20x20 to 44x44 is five times the area and takes the deepest point from 32 tiles to 40,
-- because a lattice carve lays one corridor per `spacing` tiles however big the frame is, so a bigger
-- board is mostly more fill. Halving the spacing doubles the corridor per unit area AND lengthens every
-- path through it. That is why a descent names `spacing` (models/descent.lua) and why growing the board
-- was the wrong instinct.
--
-- WHAT IT IS MADE OF, and it is deliberately almost nothing of its own:
--
--   the warren     models/layouts/maze.lua's recursive backtracker, unchanged, at the caller's spacing.
--   the chambers   the same pass models/layouts/glades.lua uses, because the rules it encodes are hard
--                  won and apply here identically: a room opens a JUNCTION and never a spur, it SHRINKS
--                  rather than standing down when a spur is near, and it keeps a separation so two
--                  rooms cannot fuse into one field. Those three were each learned by breaking the
--                  board and reading `. board-report`, and re-deriving them here would be re-earning
--                  them. See that file for the numbers.
--
-- WHAT IT CHANGES is two things, and both are about being indoors:
--
--   ownsEdge       a dungeon is MASONRY. The shared weathering pass (Overworld:weatherEdges) eats a
--                  wandering couple of tiles off every side so a rolled country does not end in a
--                  straight line -- which is right for a coastline and wrong for a floor that was
--                  built. Layout.lua's own words: "Masonry was built; ground merely ended."
--   chambers       more of them, and smaller. A campaign board seats four or five fights and glades is
--                  tuned to be a little generous with room for them; a descent floor is a place you
--                  explore, so chambers are the texture of it rather than a service to the fight
--                  placer. See ROOM_RADIUS.
--
-- The biome still supplies the TILESET, so a swamp floor is a swamp warren and a castle floor is a
-- castle one. What the sin owns is the look; what the descent owns is the shape underneath it.

local Maze = require("models.layouts.maze")

local Dungeon = {}

Dungeon.name = "Dungeon"

-- Indoors: the frame is a wall somebody built, not a coast that ran out. See the header.
Dungeon.ownsEdge = true

-- Sizing proxy, for Overworld's deriveDims. Same as the maze's -- a lattice's walkable share is
-- 1/spacing by construction -- though a descent pins its own cols/rows and never reaches this.
Dungeon.density = Maze.density

-- How far apart two chambers must sit, as a multiple of the lattice spacing. Larger than glades' 1.5
-- because a descent runs at spacing 2, where 1.5 is three tiles and two rooms would touch.
local SEPARATION = 2

-- How many chambers, against how many nodes there are. A warren has roughly four times the nodes of a
-- campaign lattice at the same size, so the per-node rate is proportionally leaner and the cap is what
-- actually binds on a normal floor.
local PER_NODES = 5
local MIN_ROOMS, MAX_ROOMS = 10, 20

-- Chambers are SMALLER than glades' clearings (which roll 3..5). At spacing 2 a radius-5 disc swallows
-- five nodes of warren in every direction and the corridor structure the floor is made of goes with it;
-- the measured effect is a board that reads as two big caves joined by a thread. Three to four keeps a
-- room a room -- radius 3 is still the smallest disc with an interior, so every one of these can hold a
-- fight (models/layouts/glades.lua explains why 2 cannot).
local ROOM_MIN, ROOM_MAX = 3, 4

-- How many carved passages leave this node, on the lattice: 1 is a spur end, 2+ is a through node.
-- Read AFTER the braid, so a loop the braid put back counts as the passage it is.
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

function Dungeon.carve(grid)
    local nodes = Maze.backtrack(grid)
    Maze.braid(grid, grid.braidRate)

    -- Spur ends are what the offer rule is built on (a boon sits on a dead end, a guard stands on the
    -- cut vertex before it) and are never opened; through nodes are where a chamber may go.
    local spurs, junctions = {}, {}
    for _, n in ipairs(nodes) do
        if passages(grid, n[1], n[2]) <= 1 then
            spurs[#spurs + 1] = n
        else
            junctions[#junctions + 1] = n
        end
    end

    -- Shuffled off the grid's own rng, so a seed reproduces its chambers exactly like everything else.
    for i = #junctions, 2, -1 do
        local j = grid.rng:random(i)
        junctions[i], junctions[j] = junctions[j], junctions[i]
    end

    local want = math.max(MIN_ROOMS, math.min(MAX_ROOMS, math.floor(#nodes / PER_NODES)))
    local gap = grid.spacing * SEPARATION
    local taken = {}

    for _, n in ipairs(junctions) do
        if #taken >= want then break end
        local x, y = n[1], n[2]
        local radius = grid.rng:random(ROOM_MIN, ROOM_MAX)
        -- Keep a chamber off the buffer ring: a room half-eaten by the wall is not a room.
        local edge = grid.margin + radius
        if x > edge and y > edge and x <= grid.cols - edge and y <= grid.rows - edge then
            local clear = true
            for _, t in ipairs(taken) do
                if math.abs(t[1] - x) < gap and math.abs(t[2] - y) < gap then
                    clear = false
                    break
                end
            end
            -- A ROOM SHRINKS TO SPARE A SPUR RATHER THAN STANDING DOWN FOR ONE. Glades measured both
            -- wrong answers -- rejecting near a spur starves the board of rooms, carving anyway deletes
            -- the dead ends the offer rule runs on -- and shrinking satisfies both. Two tiles of
            -- clearance: one for the spur end, one for the cut vertex a guard has to stand on.
            if clear then
                for _, s in ipairs(spurs) do
                    local dx, dy = s[1] - x, s[2] - y
                    local d = math.floor(math.sqrt(dx * dx + dy * dy))
                    if d - 2 < radius then radius = d - 2 end
                end
                if radius < ROOM_MIN then clear = false end
            end
            if clear then
                taken[#taken + 1] = { x, y }
                grid:carveBlob(x, y, radius, "path")
            end
        end
    end
end

return Dungeon
