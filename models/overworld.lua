-- THE FLOOR IS A GRID OF PLACES. Pure logic + data (no love.graphics at require-time) so it loads under
-- the headless test suite; only love.math's seeded RNG is used, which is available headless.
--
-- ONE CELL IS ONE PLACE, and it holds at most one thing: a fight, a find, a camp, a gate, a piece of
-- posted work, or the stair. Stepping onto it IS arriving. A blocked cell is not ground you cannot walk
-- through -- it is somewhere that is not there, and what it buys is the floor's silhouette and its
-- chokepoints.
--
-- WHAT THIS REPLACED, because the argument is the whole reason for the shape. For a long run of passes a
-- board was a rectangle with corridors CARVED through it: eight per-biome carves (models/layouts/), a
-- coastline eaten off the frame, rivers and bridges laid over it, spurs pruned, patrols walking beats
-- along it. A descent floor came out 40x40 -- 931 walkable tiles carrying thirteen stops, one every
-- thirty tiles, with the stair a forty-step walk from the door. Every invariant held. What it produced
-- was transit.
--
-- Two things had already knocked the props out from under it:
--
--   THE FIGHT STOPPED READING THE MAP. A board is built for its fight now (models/arena.lua) -- the
--   overworld under it contributes the biome and nothing else -- so the tile-level terrain that the
--   carve existed to produce fed nothing mechanical. See docs/overworld.md.
--
--   THE ROOM HAD ALREADY BECOME THE UNIT. The lattice carve that came last put one encounter in each
--   chamber, lit a chamber whole on entry, drew the floor as a plan of its chambers, and gated on the
--   room because "the gate was never going to be a tile on a board like this". A 40x40 floor of ten-tile
--   sectors is a 4x4 grid of places wearing 1,600 cells.
--
-- So the substrate is gone and the grid is the map. Dream Quest's own board: small, dense, the whole
-- floor on one screen, and every step a choice of which place to walk into next. Floor one is 6x6 and
-- the bottom is 8x8; the stair is about nine steps from the door instead of forty, and all nine are a
-- decision.
--
-- WHAT SURVIVED, and each earns it without the carve:
--   * the fog, adjacency-wide (Overworld:reveal). The silhouette is known from arrival, the CONTENTS
--     are not -- which is the rule the room layer had already landed on.
--   * gates and keys, built by construction rather than hoped for (Overworld:chokeAndGate).
--   * one connected region, guaranteed by the pass that blocks the cells and by nothing downstream
--     ([[carve-owns-connectivity]] -- the rule outlived the thing it was written about).
--   * every placement pass, which was always graph-generic: caches, encounters, guarantees, the combat
--     budget, the tier arc. They ran on BFS over pathNeighbors then and they run on it now.
--
-- WHAT WENT WITH IT: the eight layouts, the coastline, the rivers, the corridor carvers, decorate,
-- pruneDeadStubs, guardBoons, the patrols, the room layer, and line-of-sight (models/vision.lua) --
-- shadowcasting needs walls to cast against, and there are none.
--
--   local Overworld = require("models.overworld")
--   local grid = Overworld.generate({ cols = 6, rows = 6, seed = 123,
--       encounterCount = 11, keyCount = 1, objective = { name = "Warlord" } })

local Tileset = require("models.tileset")
local Biome = require("models.biome")
local Material = require("models.material") -- cache payloads: craft grades + the sponsoring house's stock
local Encounter = require("models.encounter") -- guaranteed stops resolve by kind off the blueprints

local Overworld = {}
Overworld.__index = Overworld

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- THE TWO TILE TYPES A FLOOR IS MADE OF, and they are the tileset's own names rather than new ones so
-- the renderer, the terrain table and every walkability test are untouched. `path` is a place you can
-- stand in; `thicket` is a cell that is not there.
Overworld.PLACE = "path"
Overworld.BLOCKED = "thicket"

-- Walkability is owned by the grid's (biome) tileset so the model and renderer never disagree.
-- Resolved once in generate() into self.tilesetDef.
function Overworld:typeWalkable(tile)
    local def = self.tilesetDef.tiles[tile]
    return def ~= nil and def.walkable == true
end

-- Stable integer key for a cell, used as a set/map index in BFS passes.
local function cellKey(c) return c.y * 100000 + c.x end
function Overworld:cellKey(x, y) return y * 100000 + x end

-- Resolve a count that may be a fixed number or a { min, max } range (drawn from the grid's seeded rng
-- so it stays deterministic).
local function resolveCount(v, rng)
    if type(v) == "table" then
        local lo, hi = v.min or 0, v.max or v.min or 0
        if hi < lo then hi = lo end
        return rng:random(lo, hi)
    end
    return v or 0
end

-- HOW MUCH OF A FLOOR IS NOT THERE.
--
-- A quarter, and both halves of that matter. Blocked cells are what give the floor a silhouette instead
-- of a rectangle, and -- far more load-bearing -- they are the only source of a CHOKEPOINT: on a full
-- grid every interior cell has four neighbours, nothing is an articulation point, and a gate could be
-- walked around. That is the same failure the room carve hit from the other direction.
--
-- A quarter rather than a third because the hollow pass refuses any block that would strand a place
-- (see Overworld:hollow), so a share pitched too high does not produce a more interesting floor, it
-- produces a pass that spends most of its candidates being refused and lands wherever it happens to
-- stop. Measure with `. board-report` before moving it.
Overworld.BLOCK_SHARE = 0.25

-- WHAT A FLOOR IS DRAWN AT, in logical pixels, and it is derived rather than fixed because the whole
-- floor now has to fit on one screen at every depth.
--
-- The board was 32 logical pixels a cell when it was a country you scrolled across, and 64 once a
-- chamber was the thing you were looking at. Neither answers the question a grid asks: a 10x10 floor and
-- a 12x12 floor must both read as THE FLOOR, filling the same frame, or the deep floors would quietly
-- shrink the world. So the extent is the constant and the cell size falls out of it -- 61 logical pixels
-- a cell at the top of the descent, 50 at the bottom.
--
-- 608 is what clears the HUD in the 1280x720 logical space with room either side for the readouts, and
-- it is the HEIGHT that binds: the title sits above the board and the control hint below it. Growing the
-- floor past about a dozen a side therefore costs cell size rather than screen, which is the real
-- ceiling on how big a floor can get before a marker stops being readable.
Overworld.BOARD_EXTENT = 608

-- The grid a board needs when the caller does not pin one. A descent floor always pins (see
-- Descent.floorDims), so this is the fallback for a spec or a tool that just wants a board: the square
-- that holds the content at about half occupancy, which is the density the whole shape is pitched at --
-- half the floor is somewhere with something in it, the rest is what you route through.
-- The cap is the deepest floor the descent itself asks for (Descent.floorDims tops out at 12), so a
-- caller that does not pin can never be handed a grid the mode would not draw.
local DIM_MIN, DIM_MAX = 5, 12
local function deriveDims(content)
    local places = math.max(1, content) * 2
    local span = math.ceil(math.sqrt(places / (1 - Overworld.BLOCK_SHARE)))
    span = math.max(DIM_MIN, math.min(DIM_MAX, span))
    return span, span
end

-- ---------------------------------------------------------------------------
-- Generation
-- ---------------------------------------------------------------------------

function Overworld.generate(params)
    params = params or {}
    local self = setmetatable({}, Overworld)
    self.biome = params.biome
    local biomeDef = Biome.get(params.biome)

    -- A BOARD IS DEALT OFF A SEED SOMEBODY CAN SAY, and never off the clock. Asking is a programming
    -- error rather than a silent roll -- the same gate Arena.generateLayout keeps over a battle's
    -- ground, for the same reason: a board rolled off the clock cannot be produced again, so the bug
    -- standing on it cannot be shown to anyone. See models/seed.lua.
    assert(type(params.seed) == "number",
        "Overworld.generate needs a seed -- a board rolled off the clock cannot be produced again")
    self.rng = love.math.newRandomGenerator(params.seed)

    -- Resolved up front (a { min, max } range is drawn here, once) so the grid can be sized to the
    -- content. placeEncounters reuses this same number.
    self.encounterTarget = resolveCount(params.encounterCount, self.rng)
    self.endTarget = (params.objectives and #params.objectives) or (params.objective and 1) or 0
    -- Material caches: about one per two stops unless the caller says otherwise, so a short errand
    -- scatters two and a long one four without any quest having to author a number.
    self.cacheTarget = params.cacheCount ~= nil
        and resolveCount(params.cacheCount, self.rng)
        or math.max(1, math.floor((self.encounterTarget or 0) / 2))

    -- HOW FAR THE FOG LIFTS, and one is the whole rule: what is in the place you are standing beside.
    -- It was a radius on a tile grid, where three tiles of trail was a neighbourhood; a cell is a place
    -- now, so one step is four places and a torch that raised it to two would hand over most of a small
    -- floor at a stroke. A party torch still maxes against whatever this is (states/game.lua).
    self.visionRadius = params.visionRadius or 1

    local dCols, dRows = deriveDims((self.encounterTarget or 0) + (self.cacheTarget or 0)
        + (params.keyCount or 0) + math.max(1, self.endTarget))
    self.cols = params.cols or dCols
    self.rows = params.rows or dRows

    -- No frame and no margin. The old grid padded a play area with fill so trails never hugged the edge
    -- and then ate a coastline out of the padding; a grid of places has no edge to hug -- the rim cells
    -- are places like any other, and the way up stands on one of them.
    self.margin = 0
    self.size = params.tileSize
        or math.floor(Overworld.BOARD_EXTENT / math.max(self.cols, self.rows))

    self.tilesetId = biomeDef.tileset      -- which data/tilesets/<id> draws this floor
    self.tilesetDef = Tileset.get(self.tilesetId) -- merged types + this biome's art
    self.originX = 0
    self.originY = 0
    self.keyIds = {}
    self.gateCells = {} -- keyId -> gate cell (for cleanup if a key can't be placed)

    self.cells = {}
    for y = 1, self.rows do
        self.cells[y] = {}
        for x = 1, self.cols do
            self.cells[y][x] = { x = x, y = y, tile = Overworld.PLACE }
        end
    end

    self:hollow()                 -- the silhouette, and the chokepoints under it
    self:placeObjectiveAndGates(params) -- the ends, the road back from them, and the lock on the deepest
    self:placeCaches(params)      -- the finds take the dead ends FIRST
    self:placeEncounters(params)  -- then the stops fill the places between them
    self:blockRoutes(params)      -- ...and most of the fights move onto the one way through something
    self:assignEncounterTiers()   -- the pips the fog shows, drawn from rng LAST
    self:placeSecrets(params)     -- ...and the places that read as absent until somebody finds them
    self:placeSecretRewards(params)
    self:placeExit(params)        -- ...and, on a floor you can leave, the way back up you came in by

    -- The floor is finished: no pass after this rewrites a cell.
    self.sealed = true

    return self
end

-- ---------------------------------------------------------------------------
-- The silhouette
-- ---------------------------------------------------------------------------

-- BLOCK A QUARTER OF THE CELLS, AND STRAND NOTHING.
--
-- THE PASS OWNS CONNECTIVITY AND NOTHING DOWNSTREAM REPAIRS IT. That rule was written about the layout
-- carves and it outlived them: computeStart takes a place without asking which piece of the floor it is
-- in, and every pass after it works off a BFS from there -- so a floor in two pieces is silently a floor
-- half the size, and reads as a small floor rather than as a bug ([[carve-owns-connectivity]]).
--
-- Here the guarantee is affordable outright rather than argued: the grid is at most a hundred cells, so
-- every candidate block is tested by re-flooding the whole floor and counting. A hundred floods of a
-- hundred cells is nothing, and it means the invariant holds by construction on every seed rather than
-- on the seeds a spec happened to roll.
--
-- Refusing a block also refuses the two shapes that would ruin a floor without disconnecting it: a place
-- with no open neighbour at all (an island of one), and the corner-only diagonal touch, which reads as
-- adjacent and is not walkable.
function Overworld:hollow()
    local want = math.floor(self.cols * self.rows * Overworld.BLOCK_SHARE)
    if want <= 0 then return end

    local order = {}
    for y = 1, self.rows do
        for x = 1, self.cols do order[#order + 1] = self.cells[y][x] end
    end
    for i = #order, 2, -1 do
        local j = self.rng:random(i)
        order[i], order[j] = order[j], order[i]
    end

    local blocked = 0
    for _, c in ipairs(order) do
        if blocked >= want then break end
        c.tile = Overworld.BLOCKED
        if self:oneRegion() then
            blocked = blocked + 1
        else
            c.tile = Overworld.PLACE -- it stranded something: put it back and try the next
        end
    end
    self.blockedCount = blocked
end

-- Whether every place on the floor can reach every other. Counts the open cells and floods from the
-- first one; equal counts is one region.
function Overworld:oneRegion()
    local first, total = nil, 0
    for y = 1, self.rows do
        for x = 1, self.cols do
            if self:typeWalkable(self.cells[y][x].tile) then
                total = total + 1
                first = first or self.cells[y][x]
            end
        end
    end
    if not first then return false end
    local seen, q, qi = { [cellKey(first)] = true }, { first }, 1
    local n = 1
    while qi <= #q do
        local c = q[qi]; qi = qi + 1
        for _, nb in ipairs(self:pathNeighbors(c.x, c.y)) do
            if not seen[cellKey(nb)] then
                seen[cellKey(nb)] = true
                n = n + 1
                q[#q + 1] = nb
            end
        end
    end
    return n == total
end

-- ---------------------------------------------------------------------------
-- Graph queries
-- ---------------------------------------------------------------------------

function Overworld:inBounds(x, y)
    return x >= 1 and y >= 1 and x <= self.cols and y <= self.rows
end

-- The places you can step to from here. Four directions: diagonals would halve every crossing and blur
-- what "adjacent" means for the fog and for the gate, both of which are counted in steps.
function Overworld:pathNeighbors(x, y)
    local res = {}
    for _, d in ipairs(DIRS) do
        local nx, ny = x + d[1], y + d[2]
        local c = self.cells[ny] and self.cells[ny][nx]
        if c and self:typeWalkable(c.tile) then res[#res + 1] = c end
    end
    return res
end

-- BFS over the floor (gates ignored). Returns dist[cellKey] and a parent map for reconstructing the
-- shortest walk back.
function Overworld:bfsDistances(from)
    local dist, parent = {}, {}
    dist[cellKey(from)] = 0
    local q, qi = { from }, 1
    while qi <= #q do
        local c = q[qi]; qi = qi + 1
        for _, n in ipairs(self:pathNeighbors(c.x, c.y)) do
            if dist[cellKey(n)] == nil then
                dist[cellKey(n)] = dist[cellKey(c)] + 1
                parent[cellKey(n)] = c
                q[#q + 1] = n
            end
        end
    end
    return dist, parent
end

-- THE WAY IN IS ON THE RIM. The old rule took the walkable tile nearest the middle, which was right for
-- a country -- you were dropped somewhere in it and the map ran off in every direction. A floor is a
-- place you walk INTO: entering at the middle would put the stair three steps away in every direction
-- and leave the floor with no depth at all. On the rim, the deepest cell is a genuine crossing.
-- THE WAY IN AND THE THING AT THE END OF THE FLOOR ARE THE TWO ENDS OF ITS LONGEST WALK.
--
-- Returns start, far, steps: the rim place whose farthest place is farther than any other rim place's,
-- and that farthest place. `placeObjectiveAndGates` uses the first as the way in and hands the second to
-- the deepest end, so the guardian stands as far from the door as this floor can put it.
--
-- IT WAS A COIN FLIP, and this is what that cost. The way in was `rim[rng:random(#rim)]` -- an arbitrary
-- rim place -- and the guardian was then the farthest place FROM THAT. So the crossing was the
-- eccentricity of a random cell rather than the floor's own longest walk, and a start that happened to
-- land mid-edge threw away everything the silhouette had to offer. Measured over twenty floors: the
-- crossing ran 17.85 steps against a diameter of 20.10, so about a ninth of the floor's depth went
-- unused on the average roll and considerably more on a bad one.
--
-- THE RIM CONSTRAINT STAYS, and it is not free -- the true diameter may run corner to corner through the
-- middle. A floor is a place you walk INTO: entering at the middle would put the stair three steps away
-- in every direction and there would be no depth to spend. Restricting the start to the rim and then
-- maximising is what buys the depth without giving up the arrival.
--
-- DETERMINISTIC, which is a change worth naming: the rng draw is gone, so a floor's way in is now a fact
-- about its silhouette rather than a roll on top of it. Variety survives -- the silhouette is what
-- varies between seeds -- and every tie is broken by position so the same seed still lays the same
-- floor.
--
-- Affordable outright: the rim of a twelve-a-side floor is at most forty-odd places and each costs one
-- flood of at most a hundred and forty-four cells.
function Overworld:longestWalk()
    local rim = {}
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            if self:typeWalkable(c.tile)
                and (x == 1 or y == 1 or x == self.cols or y == self.rows) then
                rim[#rim + 1] = c
            end
        end
    end
    if #rim == 0 then -- a floor whose whole rim is blocked: any place will do for the door
        for y = 1, self.rows do
            for x = 1, self.cols do
                if self:typeWalkable(self.cells[y][x].tile) then rim[#rim + 1] = self.cells[y][x] end
            end
        end
    end
    if #rim == 0 then return nil end

    -- Every rim place that ties for the deepest floor behind it, not just the first one found.
    --
    -- THE TIE IS THE WHOLE PROBLEM HERE. Plenty of rim places reach the same maximum -- a floor's
    -- diameter is usually available from several corners at once -- so taking the first one scanned
    -- resolves every tie the same way, and the scan runs y=1 outward. Measured: four starts in five
    -- landed on the TOP ROW, and every floor became a walk downward. A positional tie-break is not
    -- neutral, it is a bias with no author.
    local best, bestD = {}, nil
    for _, from in ipairs(rim) do
        local dist = self:bfsDistances(from)
        local far, farD
        for y = 1, self.rows do
            for x = 1, self.cols do
                local c = self.cells[y][x]
                local d = dist[cellKey(c)]
                if d and self:typeWalkable(c.tile) and (not farD or d > farD) then far, farD = c, d end
            end
        end
        if far then
            if not bestD or farD > bestD then
                best, bestD = { { from = from, to = far } }, farD
            elseif farD == bestD then
                best[#best + 1] = { from = from, to = far }
            end
        end
    end
    if #best == 0 then return nil end

    -- ...and the tie is broken by the SEED rather than by the scan. Which corner a floor is entered from
    -- is then a fact about that floor, varying between seeds and reproducing exactly within one -- which
    -- is what the old random start got right and the only part of it worth keeping. A caller with no rng
    -- (an authored floor) takes the first, deterministically.
    local pick = best[self.rng and self.rng:random(#best) or 1]
    return pick.from, pick.to, bestD
end

-- The way in, on its own. Kept because callers and specs speak it; it is the first half of the pair.
function Overworld:computeStart()
    return (self:longestWalk())
end

-- Step distance between two cells, straight-line. Used to hold a floor's several ends apart.
local function apart(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

-- ---------------------------------------------------------------------------
-- The ends, and the lock on the deepest
-- ---------------------------------------------------------------------------

-- A FLOOR CARRIES AS MANY ENDS AS THE DAY HAS WORK IN IT. `params.objectives` is a list -- one entry per
-- piece of work (models/quest.lua's Quest.trip) -- and a lone `params.objective` is read as a one-entry
-- list, which is what every authored leg and every descent floor still passes.
--
-- The deepest end is the farthest place there is, and the rest take the farthest remaining, held apart.
-- The old rule aimed at ~80% of the maximum rather than the maximum, to stop the objective being a
-- marathon to the far corner of a thirty-tile board. On a floor whose whole crossing is nine steps there
-- is no marathon to avoid, and the far corner is exactly where the stair should be.
function Overworld:placeObjectiveAndGates(params)
    -- THE PAIR, not two separate decisions. `longestWalk` hands back the rim place with the deepest
    -- floor behind it; the sort below then takes the deepest candidate from there, which is the other
    -- end of that same walk. So the guardian stands at the end of the longest road the floor has rather
    -- than at the end of whatever road an arbitrary door happened to open onto.
    --
    -- The far end is not forced, only reached: at equal distance the sort prefers a place with ONE
    -- approach, because that is what the choke pass can lock without moving anything. Same depth,
    -- better door.
    local start = self:computeStart()
    self.start = { x = start.x, y = start.y }

    local dist, parent = self:bfsDistances(start)

    local cands, maxDist = {}, 0
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            local d = dist[cellKey(c)]
            if self:typeWalkable(c.tile) and d and c ~= start then
                cands[#cands + 1] = { cell = c, d = d, deg = #self:pathNeighbors(x, y) }
                if d > maxDist then maxDist = d end
            end
        end
    end

    -- Deepest first, and a dead end breaks a tie: an end with one approach is one the choke pass below
    -- can lock without moving anything, and it is not a place the company walks through on the way
    -- somewhere else. Position is the last tie-break so a seed reproduces exactly.
    table.sort(cands, function(a, b)
        if a.d ~= b.d then return a.d > b.d end
        if (a.deg == 1) ~= (b.deg == 1) then return a.deg == 1 end
        if a.cell.y ~= b.cell.y then return a.cell.y < b.cell.y end
        return a.cell.x < b.cell.x
    end)

    local specs = params.objectives
    if not (specs and #specs > 0) then specs = { params.objective or {} } end

    local chosen, claimed = {}, {}
    for i = 1, #specs do
        local best
        -- Held apart at a quarter of the floor's reach, relaxing until something qualifies: a small
        -- floor may genuinely have no far-apart pair, and a crowded end still beats no end at all.
        local spread = (i == 1) and 0 or math.max(1, math.floor(maxDist * 0.25))
        while not best and spread >= 0 do
            for _, e in ipairs(cands) do
                if not claimed[cellKey(e.cell)] then
                    local ok = true
                    for _, c in ipairs(chosen) do
                        if apart(e.cell, c) < spread then ok = false break end
                    end
                    if ok then best = e.cell break end
                end
            end
            spread = spread - 1
        end
        -- NO PLACE LEFT. Rather than dropping the quest -- work the player travelled for, silently
        -- absent -- it says so, and `. board-report` counts these: a floor that keeps doing it is a
        -- floor whose sizing has stopped keeping up with what the day is posting on it.
        if not best then
            self.crowdedEnds = (self.crowdedEnds or 0) + 1
        else
            chosen[#chosen + 1] = best
            claimed[cellKey(best)] = true
        end
    end

    -- Stamp them. The cell carries the quest ID and nothing else of the spec: a spec may hold a
    -- composition FUNCTION (the finale sizes itself by how many generals are still standing) and the
    -- floor is serialized whole into the save, which has to stay plain data. states/game.lua looks the
    -- spec back up by this id when the cell is engaged.
    self.objectives = {}
    for i, cell in ipairs(chosen) do
        local spec = specs[i] or {}
        cell.encounter = { kind = "objective", name = spec.name or "Objective",
            questId = spec.questId, meet = spec.meet or nil }
        self.objectives[i] = { x = cell.x, y = cell.y, questId = spec.questId }
    end
    -- The deepest end, still under its old name. Everything that wants "the far end of this floor" as a
    -- single cell -- the opening pan, the report tools, the two map relics -- reads this.
    self.objective = self.objectives[1]

    self:chokeAndGate(params, chosen[1])
    self:markSpine(chosen)
end

-- THE SPINE: every end -> ... -> start, unioned, as a set of cell keys. What it is for is the floor's
-- oldest contract -- the objectives are the only fights you must take, and you need not take any of
-- them -- so placeEncounters keeps combat off it and a wounded company can always route to a stair, or
-- past one. The road home is a road NETWORK and the rule reads the same across all of it.
--
-- Recomputed AFTER the choke, because the choke blocks cells and a path that ran through one of them is
-- no longer a path.
function Overworld:markSpine(chosen)
    local start = self:startCell()
    local _, parent = self:bfsDistances(start)
    self.spineKeys = {}
    self.spineCells = {}
    for i, endCell in ipairs(chosen) do
        local path, cur = {}, endCell
        while cur do
            path[#path + 1] = cur
            self.spineKeys[cellKey(cur)] = true
            cur = parent[cellKey(cur)]
        end
        -- The deepest end's own path is the one an ascent measures itself along, so it is the one kept
        -- ordered, start -> objective.
        if i == 1 then
            for j = #path, 1, -1 do self.spineCells[#self.spineCells + 1] = path[j] end
        end
    end
end

-- ONE APPROACH TO THE DEEPEST END, MADE ON PURPOSE.
--
-- A gate on open ground is not a gate: lock a cell with two ways round it and the player has spent a key
-- hunt on a door they can walk past. The old board asked a maze for an articulation point and took what
-- it got -- which is why a floor of chambers, having none anywhere, measured 23% of its boons guarded
-- against a target of 80% and no amount of tuning moved it. The answer there was to admit the gate was
-- the room; the answer here is to build the chokepoint rather than to hope for one.
--
-- So: block the deepest end's other neighbours, one at a time, keeping only blocks that leave the floor
-- in one piece and never blocking the last one. What is left is a cell whose removal genuinely cuts the
-- end off, and that cell is the gate.
--
-- A CHAIN OF K GATES WALKS BACK FROM IT, and each link has to earn the same guarantee: a gate that is
-- not itself a cut is a second lock on a door that is already locked, which costs a key and buys
-- nothing. So the walk stops at the first cell that fails the test, and placeKeys drops the keys the
-- chain never used.
function Overworld:chokeAndGate(params, objective)
    local K = params.keyCount or 0
    if K <= 0 or not objective then return end

    local nbs = self:pathNeighbors(objective.x, objective.y)
    for _, n in ipairs(nbs) do
        if #self:pathNeighbors(objective.x, objective.y) <= 1 then break end
        if not n.encounter and not (self.start.x == n.x and self.start.y == n.y) then
            n.tile = Overworld.BLOCKED
            if not self:oneRegion() then n.tile = Overworld.PLACE end
        end
    end

    local start = self:startCell()
    local dist = self:bfsDistances(start)
    local firstGateDist = dist[cellKey(objective)] or 0

    -- Walk back from the end, gating each cell that is a genuine cut. `cuts` asks the question the gate
    -- is making a promise about: with this cell blocked, can the company still reach the end?
    local cur, prev = objective, nil
    for _ = 1, K do
        local nexts = {}
        for _, n in ipairs(self:pathNeighbors(cur.x, cur.y)) do
            if n ~= prev then nexts[#nexts + 1] = n end
        end
        local g = nexts[1]
        if not g or #nexts > 1 then break end
        if g.encounter or g.cache or (self.start.x == g.x and self.start.y == g.y) then break end
        if not self:cuts(g, objective) then break end

        local keyId = "key" .. (#self.keyIds + 1)
        g.gate = { keyId = keyId }
        self.gateCells[keyId] = g
        self.keyIds[#self.keyIds + 1] = keyId
        firstGateDist = math.min(firstGateDist, dist[cellKey(g)] or firstGateDist)
        prev, cur = cur, g
    end

    if #self.keyIds > 0 then self:placeKeys(dist, firstGateDist) end
end

-- Whether blocking `cell` puts `target` out of reach of the start. The gate's whole promise, asked
-- directly rather than inferred from a degree count -- on a grid a cell can have one neighbour and still
-- be walked around, and can have three and still be the only way through.
function Overworld:cuts(cell, target)
    local was = cell.tile
    cell.tile = Overworld.BLOCKED
    local start = self:startCell()
    local reachable = start and self:reachable(start) or {}
    cell.tile = was
    return reachable[cellKey(target)] == nil
end

-- Scatter one pickup per key into the region before the first gate. Any key that cannot be placed (a
-- very small floor) unlocks its gate, so the floor is never unsolvable.
function Overworld:placeKeys(dist, firstGateDist)
    local candidates = {}
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            local d = dist[cellKey(c)]
            if self:typeWalkable(c.tile) and d and d < firstGateDist
                and not c.gate and not c.encounter
                and not (self.start.x == x and self.start.y == y) then
                candidates[#candidates + 1] = c
            end
        end
    end

    for i = #candidates, 2, -1 do
        local j = self.rng:random(i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    local placed = {}
    for idx, keyId in ipairs(self.keyIds) do
        local c = candidates[idx]
        if c then
            c.key = { keyId = keyId }
            placed[keyId] = true
        else
            local gate = self.gateCells[keyId]
            if gate then gate.gate = nil end
        end
    end

    local kept = {}
    for _, keyId in ipairs(self.keyIds) do
        if placed[keyId] then kept[#kept + 1] = keyId end
    end
    self.keyIds = kept
end

-- ---------------------------------------------------------------------------
-- Secret places
-- ---------------------------------------------------------------------------

-- HOW MANY A FLOOR HIDES. Small. A secret is worth having because finding one is a surprise; a floor
-- with six of them is a floor where searching is a chore you perform against every wall, which is the
-- failure mode Wizardry's own later entries fell into.
Overworld.SECRETS = { min = 2, max = 3 }

-- What is behind a door, paid at the TOP of the cache band rather than scaled by detour like the
-- floor's own. The ordinary rule prices a cache by how far off the road it sits, which is a proxy for
-- what it cost to reach; a secret's real cost is having looked at all, and distance cannot see that.
Overworld.SECRET_CRAFT = 6
Overworld.SECRET_HOUSE = 5

-- A PLACE THAT READS AS ABSENT UNTIL SOMEBODY FINDS IT.
--
-- On the old board a secret was a door carved into dead wall, opening onto a spur of corridor that
-- existed nowhere else -- the whole difference between a secret and a shortcut being that the ground
-- behind it was new. A grid keeps that distinction for free: a blocked cell is not a wall, it is
-- somewhere that is not there, so turning one into a place ADDS a place to the floor. Nothing is joined
-- to anything and no route is shortened.
--
-- Runs after the encounters and the caches, so the hidden place is empty when it is found and takes its
-- reward from placeSecretRewards rather than competing for the floor's own stops. A secret that hid an
-- ordinary fight would be a fight the player never found.
function Overworld:placeSecrets(params)
    if not params.secrets then return end
    local n = resolveCount(Overworld.SECRETS, self.rng)

    local cands = {}
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            -- Blocked, and touching at least one place -- a secret nobody can stand beside cannot be
            -- found, since finding one is a fact about having walked there (Overworld:findSecrets).
            if not self:typeWalkable(c.tile) and #self:pathNeighbors(x, y) > 0 then
                cands[#cands + 1] = c
            end
        end
    end
    for i = #cands, 2, -1 do
        local j = self.rng:random(i)
        cands[i], cands[j] = cands[j], cands[i]
    end

    self.secretCells = {}
    for i = 1, math.min(n, #cands) do
        local c = cands[i]
        c.secret = true
        c.secretEnd = true -- generation-only scaffolding; consumed below
        self.secretCells[#self.secretCells + 1] = c
    end
end

function Overworld:placeSecretRewards(params)
    local houses = params.houseMaterials
    if not houses or #houses == 0 then
        houses = params.houseMaterial and { params.houseMaterial } or {}
    end
    local grades = Material.craftGrades()
    local i = 0
    for _, c in ipairs(self.secretCells or {}) do
        c.secretEnd = nil
        if not c.cache then
            i = i + 1
            local materials = {}
            -- The deepest craft grade the floor deals, since this is the deepest thing on it.
            materials[grades[#grades]] = Overworld.SECRET_CRAFT
            local house = houses[((i - 1) % math.max(1, #houses)) + 1]
            if house then
                materials[house] = (materials[house] or 0) + Overworld.SECRET_HOUSE
            end
            -- `secret` rides on the cache so the pickup can tell this pile from the floor's own: it is
            -- what turns the search verb into a payout the roll is not allowed to produce
            -- (models/spoils.lua's SECRET_ABOVE).
            c.cache = { materials = materials, secret = true }
        end
    end
end

function Overworld:isHidden(cell)
    return cell ~= nil and cell.secret == true
end

-- Search the places around (cx, cy) for one that is not there. Returns the cell found, or nil.
--
-- ADJACENCY, NOT A ROLL. Wizardry makes you stand at a wall and press Search, sometimes for several
-- turns, and the turns are the cost. There is no turn economy on this floor to spend -- so the cost is
-- being THERE: a place is found by having walked to the one beside it, and a company that never goes
-- down the dead end never finds it.
function Overworld:findSecrets(cx, cy, radius)
    radius = radius or 1
    local found
    for y = cy - radius, cy + radius do
        for x = cx - radius, cx + radius do
            local c = self:get(x, y)
            if c and c.secret then
                c.secret = nil
                c.tile = Overworld.PLACE -- it was always a place; now it is one you can walk into
                found = found or c
            end
        end
    end
    return found
end

-- ---------------------------------------------------------------------------
-- Material caches
-- ---------------------------------------------------------------------------

-- How far off the critical path every place lies: a multi-source BFS seeded from the whole spine at
-- once, so a place ON the route reads 0 and a detour reads the steps it costs.
function Overworld:spineDistances()
    local dist = {}
    local q, qi = {}, 1
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            if self.spineKeys and self.spineKeys[cellKey(c)] and self:typeWalkable(c.tile) then
                dist[cellKey(c)] = 0
                q[#q + 1] = c
            end
        end
    end
    while qi <= #q do
        local c = q[qi]; qi = qi + 1
        for _, n in ipairs(self:pathNeighbors(c.x, c.y)) do
            if dist[cellKey(n)] == nil then
                dist[cellKey(n)] = dist[cellKey(c)] + 1
                q[#q + 1] = n
            end
        end
    end
    return dist
end

-- A cache's payload scales with the detour it cost, measured RELATIVE to the deepest detour this
-- particular floor offers -- so "the far corner pays best" is true on a cramped floor and a wide one
-- alike. Both counts are capped hard: the point of the far cache is that it is BETTER, not that it is a
-- windfall.
local CACHE_CRAFT_MIN, CACHE_CRAFT_MAX = 1, 4
local CACHE_HOUSE_MIN, CACHE_HOUSE_MAX = 1, 3

-- Scatter material caches, FIRST -- before placeEncounters, so the finds get their pick of the dead ends
-- and the stops fill the places leading to them.
function Overworld:placeCaches(params)
    local count = self.cacheTarget or 0
    if count <= 0 then return end

    local deadEnds, spare = {}, {}
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            if self:typeWalkable(c.tile) and not c.encounter and not c.gate and not c.key
                and not (self.start.x == x and self.start.y == y) then
                if #self:pathNeighbors(x, y) == 1 then
                    deadEnds[#deadEnds + 1] = c
                else
                    spare[#spare + 1] = c
                end
            end
        end
    end

    local function shuffle(t)
        for i = #t, 2, -1 do
            local j = self.rng:random(i)
            t[i], t[j] = t[j], t[i]
        end
    end
    shuffle(deadEnds)
    shuffle(spare)

    -- A BOON PREFERS GROUND OFF THE ROAD. Depth off the critical path is the cheap proxy for "somewhere
    -- you went out of your way to reach", and it is already computed for the payout scale, which wants
    -- exactly the same thing. The shuffle survives as the tie-break, so boons at equal depth still move
    -- between seeds.
    local dist = self:spineDistances()
    local shuffled = {}
    for i, c in ipairs(spare) do shuffled[c] = i end
    table.sort(spare, function(a, b)
        local da, db = dist[cellKey(a)] or 0, dist[cellKey(b)] or 0
        if da ~= db then return da > db end
        return shuffled[a] < shuffled[b]
    end)

    local cands = {}
    for _, c in ipairs(deadEnds) do cands[#cands + 1] = c end
    for _, c in ipairs(spare) do
        if (dist[cellKey(c)] or 0) > 0 then cands[#cands + 1] = c end
    end

    local deepest = 0
    for _, c in ipairs(cands) do
        local d = dist[cellKey(c)] or 0
        if d > deepest then deepest = d end
    end

    local function ratioOf(detour)
        if deepest <= 0 then return 0 end
        return math.min(1, detour / deepest)
    end
    local function scaled(ratio, lo, hi)
        return lo + math.floor(ratio * (hi - lo) + 0.5)
    end

    -- WHOSE STOCK THE CACHES CARRY. Dealt round-robin across every house asking, over the caches the
    -- floor already has -- the floor does not grow to fit them, which is the whole tension: three houses
    -- against four caches means no single trip fills every quota.
    local houses = params.houseMaterials
    if not houses or #houses == 0 then
        houses = params.houseMaterial and { params.houseMaterial } or {}
    end

    local grades = Material.craftGrades()
    for i = 1, math.min(count, #cands) do
        local c = cands[i]
        local ratio = ratioOf(dist[cellKey(c)] or 0)

        local materials = {}
        materials[grades[scaled(ratio, 1, #grades)]] = scaled(ratio, CACHE_CRAFT_MIN, CACHE_CRAFT_MAX)
        local house = houses[((i - 1) % math.max(1, #houses)) + 1]
        if house then
            materials[house] = (materials[house] or 0) + scaled(ratio, CACHE_HOUSE_MIN, CACHE_HOUSE_MAX)
        end
        c.cache = { materials = materials, house = house }
    end
end

-- ---------------------------------------------------------------------------
-- The stops
-- ---------------------------------------------------------------------------

-- The floor's difficulty arc, as two rules, applied in the fill loop below.
--
-- ELITE_SHARE is to rank what `combatShare` is to kind: a ceiling the pool's weights cannot argue with,
-- because a blueprint weight is authored per encounter with no view of the others.
-- ELITE_MIN_DEPTH is the arc itself: an elite is a thing you meet once the road has gone on a while.
local ELITE_SHARE = 0.25
local ELITE_MIN_DEPTH = 0.5

-- HOW FAR APART THE STOPS STAND, and on a grid of places the answer is finally a plain one: not next to
-- each other.
--
-- It used to be a derived Poisson radius -- the square root of the ground each mark got to itself --
-- because a tile board's stops were darts thrown at nine hundred cells and darts clump. A place is a
-- stop's own unit now, so the only question left is whether two stops share a side, and two adjacent
-- places on a 6x6 floor are as close as two marks can be without being the same mark.
--
-- It relaxes to 1 (adjacent allowed) on a floor too crowded to meet it, which is the same graceful
-- partial every pass in here takes -- and unlike the old rule it can never relax into a stack, because
-- a place holds one thing by construction.
local STOP_GAP, STOP_GAP_MIN = 2, 1

function Overworld:markGap()
    return STOP_GAP
end

-- The texture a floor is guaranteed to hold whatever the draw does.
local GUARANTEE = {
    rest = { per = 6, spine = 1 }, -- one rest per 6 stops, on or beside the road
}

-- The knobs a particular floor is placing under: the default above, OVERLAID with whatever
-- `params.guarantee` names for that kind rather than replaced by it. A floor that wants a different
-- number of rests is saying nothing about whether a rest belongs beside the road.
local function guaranteeFor(params, kind)
    local base = GUARANTEE[kind]
    local over = params.guarantee and params.guarantee[kind]
    if not over then return base end
    local g = {}
    for k, v in pairs(base or {}) do g[k] = v end
    for k, v in pairs(over) do g[k] = v end
    return g
end

-- Resolve a guaranteed KIND to a placeable { kind, id, name }.
--
-- The pool is preferred, so a quest supplying its own encounter list still decides what its Reliquary
-- is. But the pool is WEIGHT-FILTERED and some texture kinds are deliberately weight 0 -- a Rest is
-- authored-only precisely so it never turns up at random or in clusters -- so reading the guarantee off
-- the pool asked the wrong table and made a DENSITY floor depend on a RANDOM-DRAW weight. Fall back to
-- the blueprint registry, walked in sorted id order because `pairs` is unspecified and this pick has to
-- reproduce from a seed like everything else in here.
local function guaranteedEntry(pool, kind)
    for _, e in ipairs(pool) do
        if e.kind == kind then return e end
    end
    local ids = {}
    for id, def in pairs(Encounter.defs) do
        if def.kind == kind then ids[#ids + 1] = id end
    end
    if #ids == 0 then return nil end
    table.sort(ids)
    return { kind = kind, id = ids[1], name = Encounter.defs[ids[1]].name }
end

-- Place the stops. `params.encounterCount` is a number or { min, max }; `params.alwaysEncounters` are
-- guaranteed picks placed first; the rest are drawn from the weighted `params.encounters` pool. Both
-- come pre-filtered for the player's prestige/conditionals by the caller (see models/encounter.lua).
function Overworld:placeEncounters(params)
    local count = self.encounterTarget or resolveCount(params.encounterCount, self.rng)
    local pool = params.encounters or { { kind = "combat", weight = 1 } }
    local always = params.alwaysEncounters or {}

    -- WHICH STOPS SOMEBODY CHOSE, as opposed to which the roll dealt. Generation-only scaffolding, like
    -- spineKeys: it never reaches a save, because it is a fact about how a floor was BUILT rather than
    -- about the floor. :blockRoutes reads it and moves nothing that is in it -- an authored stop is
    -- placed on purpose, and on an ascent the placement IS the content (the outer ring first, the thing
    -- leaning on the gate last). Moving one is not a re-seating, it is a rewrite.
    self.authoredCells = {}

    local cands = {}
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            -- `not c.cache` matters because caches are placed FIRST: a stop dropped onto one would bury
            -- the find under it.
            if self:typeWalkable(c.tile) and not c.encounter and not c.gate and not c.key and not c.cache
                and not (self.start.x == x and self.start.y == y) then
                cands[#cands + 1] = c
            end
        end
    end

    for i = #cands, 2, -1 do
        local j = self.rng:random(i)
        cands[i], cands[j] = cands[j], cands[i]
    end

    -- Skippable combats: keep combat/elite OFF the spine so a wounded company can always route around to
    -- an end. Off-spine places are filled first; on-spine ones only take non-combat stops. Ascent floors
    -- opt out -- there combat IS the route.
    if self.spineKeys and not params.ascent then
        local off, on = {}, {}
        for _, c in ipairs(cands) do
            if self.spineKeys[cellKey(c)] then on[#on + 1] = c else off[#off + 1] = c end
        end
        cands = {}
        for _, c in ipairs(off) do cands[#cands + 1] = c end
        for _, c in ipairs(on) do cands[#cands + 1] = c end
    end

    local placed = {}
    self.stopGap = STOP_GAP

    local function spacedAt(c, gap)
        for _, p in ipairs(placed) do
            if math.abs(p.x - c.x) + math.abs(p.y - c.y) < gap then return false end
        end
        return true
    end

    local function firstSpaced(filter)
        for gap = STOP_GAP, STOP_GAP_MIN, -1 do
            for _, c in ipairs(cands) do
                if not c.encounter and (not filter or filter(c)) and spacedAt(c, gap) then return c end
            end
        end
        return nil
    end

    -- ...and the same, for a stop that wants particular ground. `prefer` outranks the gap whole: a rest
    -- seated in the far corner is not the pressure valve GUARANTEE.rest asks for, however evenly it is
    -- spread. Falls through to the first free place of any kind -- a guarantee that cannot be honoured
    -- exactly is still better honoured somewhere than dropped.
    local function takeSpaced(prefer)
        local pick = (prefer and firstSpaced(prefer)) or firstSpaced(nil)
        if pick then return pick end
        for _, c in ipairs(cands) do
            if not c.encounter then return c end
        end
        return nil
    end

    -- ASCENT floors: the guaranteed encounters are a ROUTE, not a set -- seated ALONG the road in
    -- authored order, marker k of n at k/(n+1) of the way up the spine, so the outer ring is met first
    -- and the thing leaning on the gate last. Off by default: an ordinary floor wants its guaranteed
    -- stops scattered, and a fixed running order would make every quest that uses `always` a corridor.
    if params.ascent and #always > 0 then
        local dist = self:bfsDistances(self:startCell())
        local open = {}
        for _, c in ipairs(cands) do
            if dist[cellKey(c)] then open[cellKey(c)] = c end
        end
        local spine = self.spineCells or {}
        local n, L = #always, #spine
        local lastIdx = 1

        for k, e in ipairs(always) do
            local chosen
            if L > 2 then
                local ideal = math.max(lastIdx + 1, math.floor(k / (n + 1) * (L - 1) + 0.5) + 1)
                for j = ideal, L - 1 do
                    local c = open[cellKey(spine[j])]
                    if c and not c.encounter then chosen, lastIdx = c, j; break end
                end
                if not chosen then
                    for j = math.min(ideal - 1, L - 1), lastIdx + 1, -1 do
                        local c = open[cellKey(spine[j])]
                        if c and not c.encounter then chosen, lastIdx = c, j; break end
                    end
                end
            end
            -- Off-spine fallback: a short or heavily gated road still gets every authored encounter
            -- rather than silently dropping the top of the climb.
            chosen = chosen or takeSpaced()
            if chosen then
                chosen.encounter = { kind = e.kind, id = e.id, name = e.name,
                                     loot = e.loot, conversation = e.conversation }
                -- AUTHORED, so nothing downstream moves it. The ascent route IS its order.
                self.authoredCells[cellKey(chosen)] = true
                placed[#placed + 1] = chosen
            end
        end
        self.encounterCount = #placed
        return
    end

    -- Guaranteed specific encounters first -- spaced like every other stop. They used to be taken off
    -- the front of the list "even if a little close", which on a quest authoring three of them put the
    -- three things the quest is ABOUT in one corner.
    for _, e in ipairs(always) do
        local c = takeSpaced()
        if c then
            c.encounter = { kind = e.kind, id = e.id, name = e.name,
                            loot = e.loot, conversation = e.conversation }
            -- AUTHORED: a quest named this stop, so :blockRoutes leaves it where it was put.
            self.authoredCells[cellKey(c)] = true
            placed[#placed + 1] = c
        end
    end

    -- Guaranteed VARIETY: a rolled floor must never be a wall of fights. Seat the texture kinds -- a
    -- Reliquary to stock the run's relics, a Rest to heal -- that `always` did not already.
    local spineDist
    local function withinSpine(c, radius)
        spineDist = spineDist or self:spineDistances()
        return (spineDist[cellKey(c)] or math.huge) <= radius
    end

    for _, kind in ipairs(params.guaranteeKinds or { "relic_cache", "rest" }) do
        local g = guaranteeFor(params, kind)
        local want = (g and g.count)
            or ((g and g.per) and math.max(1, math.ceil((count or 0) / g.per)))
            or 1
        local have = 0
        for _, p in ipairs(placed) do if p.encounter.kind == kind then have = have + 1 end end
        local entry = (have < want) and guaranteedEntry(pool, kind) or nil
        local prefer = (g and g.spine) and function(c) return withinSpine(c, g.spine) end or nil
        while entry and have < want do
            local c = takeSpaced(prefer)
            if not c then break end -- the floor is full: it simply holds fewer
            c.encounter = { kind = entry.kind, id = entry.id, name = entry.name }
            placed[#placed + 1] = c
            have = have + 1
        end
    end

    local target = math.max(count, #placed)
    -- Combat SHARE cap, or an ABSOLUTE budget where the caller gives one. A share is the right
    -- instrument for a roadside, where the question is what fraction of the walk is fighting. It is the
    -- wrong one wherever a caller has to count the fights on the WHOLE floor, because the ends are
    -- seated by a different pass and no fraction of the stop count can see them -- a descent floor
    -- carries the stair plus one end per errand and subtracts them itself (Descent.floorBudget).
    local isFight = function(k) return k == "combat" or k == "elite" end
    local combatCap = params.combatBudget or math.floor(target * (params.combatShare or 0.6))
    local combatPlaced = 0
    for _, p in ipairs(placed) do if isFight(p.encounter.kind) then combatPlaced = combatPlaced + 1 end end

    local eliteCap = math.floor(target * (params.eliteShare or ELITE_SHARE))
    local elitePlaced = 0
    for _, p in ipairs(placed) do if p.encounter.kind == "elite" then elitePlaced = elitePlaced + 1 end end
    local startDist = self:bfsDistances(self:startCell())
    local farthest = 1
    for _, d in pairs(startDist) do if d > farthest then farthest = d end end

    local function seat(c)
        local pick = self:pickEncounter(pool)
        local onSpine = self.spineKeys and not params.ascent and self.spineKeys[cellKey(c)]
        if isFight(pick.kind) and (onSpine or combatPlaced >= combatCap) then
            pick = self:pickNonCombat(pool) or pick
        end
        -- Then the rank rule, after the kind rule: a stop demoted to texture above is no longer a fight
        -- and must not spend the elite budget on its way past.
        if pick.kind == "elite" then
            local depth = (startDist[cellKey(c)] or 0) / farthest
            if depth < ELITE_MIN_DEPTH or elitePlaced >= eliteCap then
                pick = self:pickOrdinaryCombat(pool) or pick
            end
        end
        if pick.kind == "elite" then elitePlaced = elitePlaced + 1 end
        if pick then
            c.encounter = { kind = pick.kind, id = pick.id, name = pick.name }
            placed[#placed + 1] = c
            if isFight(pick.kind) then combatPlaced = combatPlaced + 1 end
        end
    end

    -- Widest gap first, then a step narrower. The first pass takes only places that stand clear of every
    -- stop already down -- which is what spreads them over the floor rather than over the front of the
    -- shuffled list -- and the second fills in what a crowded floor has left.
    for gap = STOP_GAP, STOP_GAP_MIN, -1 do
        if #placed >= target then break end
        for _, c in ipairs(cands) do
            if #placed >= target then break end
            if not c.encounter and spacedAt(c, gap) then seat(c) end
        end
    end
    self.encounterCount = #placed
end

-- ---------------------------------------------------------------------------
-- The fights that block the way
-- ---------------------------------------------------------------------------

-- WHAT SHARE OF A FLOOR'S FIGHTS STAND IN THE ONLY WAY TO SOMETHING.
--
-- Most, and deliberately not all. An unbroken rule turns the floor into a checklist and teaches the
-- player to read markers instead of the ground; the loose remainder is what keeps a find on the road
-- feeling like a find, and what makes the blocked ones read as a decision rather than as a toll booth.
Overworld.BLOCKING_SHARE = 0.6

-- THE MOST OF A FLOOR ONE FIGHT MAY HOLD BACK, and the rule that stops this pass turning on the player.
--
-- `stranded` measures the side AWAY from the company, so a cut that strands sixty of seventy-five places
-- is not a fight guarding a wing -- it is a fight standing between the company and the entire rest of
-- the floor, with the company in the pocket. Sorting candidates by "most stranded first" therefore
-- reached for the door's own mouth every time, and it did: measured, three floors in four opened with
-- the way in penned by a fight, against 13% before this pass existed. The instrument said so in one line
-- (`free from the door` fell from 44 places to 11) and no amount of reading the code would have.
--
-- Half. A fight may gate a wing, a spur, a pocket -- not the floor.
Overworld.MAX_GATED = 0.5

-- ...AND THE COMPANY MUST BE ABLE TO DO SOMETHING BEFORE IT FIGHTS ANYTHING.
--
-- The cap above is per-cut and cannot see the whole picture: two fights that each gate a legal share can
-- still box the entrance between them. So the floor is checked once at the end, as a floor -- how much
-- of it can be reached from the door without committing to a battle -- and fights are lifted back off
-- the chokepoints until it is enough.
--
-- A QUARTER, which is about eighteen places on a first floor. Not a number about fairness: it is what
-- makes the first decision a decision. A company that steps off the stair with one legal move has not
-- chosen anything, and on a floor where fights are the thing you route around, the routing has to exist
-- before the first fight does.
Overworld.MIN_FREE_AT_DOOR = 0.25

-- MOVE THE FIGHTS ONTO THE CHOKEPOINTS.
--
-- THE PROBLEM THIS ANSWERS, in the player's words: "I can reveal the entire map then selectively choose
-- what to encounter." Every stop on a grid of places is optional by construction -- a cell holds one
-- thing and you step onto it or you do not -- so a floor whose fights are scattered on open ground is a
-- shopping list. Nothing is ever in the way of anything.
--
-- The board this replaced had a pass for exactly this (`guardBoons`: the boon behind, the fight in the
-- way) and it went with the carve, on the argument that a fight now pays for itself in spoils and
-- levels. That is true and it is not enough: a fight that pays for itself is a fight you take when you
-- feel like it, which is the same shopping list with a price tag on each row.
--
-- A CUT, NOT A NEIGHBOUR, and that is the difference from the old pass. `guardBoons` stood a fight
-- BESIDE a reward and hoped the geometry made it a gate; this asks the question directly -- take this
-- place away, and is anything now out of reach? -- so a blocking fight is blocking by proof rather than
-- by adjacency. `. board-report` says the supply was never the problem: a floor offers about fourteen
-- such places and had fights on 6% of them.
--
-- IT MOVES FIGHTS RATHER THAN ADDING THEM. The floor's budget is authored (Descent.FLOOR_FIGHTS) and a
-- pass that seated extra fights to make a point would quietly re-price the sitting. Everything upstream
-- still decides WHAT the floor holds; this decides only where the fights ended up -- the same move
-- every re-seating pass in here makes.
function Overworld:blockRoutes(params)
    if params and params.blockRoutes == false then return end

    local start = self:startCell()
    if not start then return end

    -- Every walkable place, minus this one: what does taking it away strand?
    local total = 0
    for y = 1, self.rows do
        for x = 1, self.cols do
            if self:typeWalkable(self.cells[y][x].tile) then total = total + 1 end
        end
    end

    local function stranded(c)
        local was = c.tile
        c.tile = Overworld.BLOCKED
        local reach = self:reachable(start)
        c.tile = was
        local n = 0
        for _ in pairs(reach) do n = n + 1 end
        return total - 1 - n
    end

    -- The candidates: free places that are a real cut. Free means nothing already stands there -- a
    -- cache would be buried under the fight meant to guard it, and an end is a fight already.
    local cuts = {}
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            if self:typeWalkable(c.tile) and c ~= start
                and not c.encounter and not c.cache and not c.gate and not c.key then
                -- A campaign ground keeps its promise that the road to an end is walkable: combat stays
                -- off the spine there, so a cut ON the spine is not a candidate. A descent floor sets
                -- `ascent`, where combat IS the route, and every cut is fair.
                local onSpine = self.spineKeys and not (params and params.ascent)
                    and self.spineKeys[cellKey(c)]
                if not onSpine then
                    local n = stranded(c)
                    -- A fight may gate a wing, not the floor. `stranded` counts the side AWAY from the
                    -- company, so a huge number here means the company is in the pocket and everything
                    -- else is behind the fight -- which is the door being penned rather than content
                    -- being guarded. See Overworld.MAX_GATED.
                    if n > 0 and n <= total * Overworld.MAX_GATED then
                        cuts[#cuts + 1] = { cell = c, n = n }
                    end
                end
            end
        end
    end
    if #cuts == 0 then return end

    -- The fights that are standing in the open, and could be somewhere that means something.
    --
    -- AUTHORED STOPS ARE NOT AMONG THEM. A quest named those and an ascent's whole route is the order
    -- they were laid in -- the outer ring first, the thing leaning on the gate last -- so moving one is
    -- not a re-seating, it is a rewrite. This pass moves what the ROLL dealt.
    local authored = self.authoredCells or {}
    local loose, already = {}, 0
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            local e = c.encounter
            if e and (e.kind == "combat" or e.kind == "elite") then
                if stranded(c) > 0 then
                    -- Already standing in the only way to something, by luck of the seating. It counts
                    -- toward the share -- the share is of the floor's FIGHTS, not of the ones that
                    -- happen to need moving, or a floor that rolled well would end up with more
                    -- blocking fights than one that did not.
                    already = already + 1
                elseif not authored[cellKey(c)] then
                    loose[#loose + 1] = c
                end
            end
        end
    end
    if #loose == 0 then return end

    -- HOW DEEP EACH CUT SITS, because an ELITE MAY NOT BE MOVED SHALLOW. The floor's arc is carried by
    -- placement (ELITE_MIN_DEPTH: an elite rolled onto the near half is re-seated as an ordinary fight),
    -- and a pass that then picked one up and put it down on a doorstep chokepoint would quietly undo the
    -- arc it was just given. The old guarded-boon pass had to learn this too, and for the same reason.
    local startDist = self:bfsDistances(start)
    local farthest = 1
    for _, d in pairs(startDist) do if d > farthest then farthest = d end end
    local function depthOf(c) return (startDist[cellKey(c)] or 0) / farthest end

    -- MOST GROUND FIRST. A cut that strands half the floor is a route decision; one that strands a
    -- single dead end is a fight in front of one cupboard. Position breaks the tie so a seed reproduces.
    table.sort(cuts, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        if a.cell.y ~= b.cell.y then return a.cell.y < b.cell.y end
        return a.cell.x < b.cell.x
    end)

    -- The share is of every fight on the floor, and what is left to MOVE is that target less the ones
    -- already in place. (This counted only the loose ones once, which quietly overshot: a floor whose
    -- seating happened to drop two fights on cuts then moved a full 60% of the rest on top of them.)
    local share = (params and params.blockingShare) or Overworld.BLOCKING_SHARE
    local want = math.floor((#loose + already) * share + 0.5) - already
    local moved = 0
    for _, entry in ipairs(cuts) do
        if moved >= want or #loose == 0 then break end
        -- Take the first loose fight this cut can legally hold. An elite needs the deep half; an
        -- ordinary fight will stand anywhere. Walked rather than popped, so a shallow cut takes the
        -- plain fight further down the list instead of turning an elite into a doorstep.
        local pick
        for i = #loose, 1, -1 do
            local e = loose[i].encounter
            if e.kind ~= "elite" or depthOf(entry.cell) >= ELITE_MIN_DEPTH then
                pick = table.remove(loose, i)
                break
            end
        end
        if pick then
            entry.cell.encounter = pick.encounter
            pick.encounter = nil
            pick.blockedFrom = entry.cell -- so the door pass below can put it back where it came from
            moved = moved + 1
        end
    end
    self.blockingFights = moved
    self:freeTheDoor()
end

-- THE COMPANY CAN ALWAYS DO SOMETHING BEFORE IT FIGHTS ANYTHING.
--
-- The per-cut cap (Overworld.MAX_GATED) stops any ONE fight holding back the floor, and it cannot stop
-- two of them boxing the entrance between them -- each gating a legal share, the company standing in
-- what is left. So the floor is asked the question as a floor, once, at the end: walking from the door
-- and refusing every battle, how much of this place can be reached?
--
-- Short of the floor (Overworld.MIN_FREE_AT_DOOR), a fight on the edge of that region is lifted back off
-- its chokepoint and put where it came from, and the question is asked again. Fights are given back in
-- the order they were taken, so what is un-blocked first is the last thing this pass decided -- the
-- least considered of its choices rather than the most.
--
-- IT IS A RETREAT, NOT A REPAIR. Nothing new is invented and nothing moves anywhere it was not already
-- standing: the pass simply gives back what it should not have taken. A floor that cannot meet the bar
-- even with every fight returned is a floor whose silhouette pens the door on its own, which `hollow`
-- cannot produce -- it refuses any block that strands a place -- so the loop terminates on the fights.
function Overworld:freeTheDoor()
    local start = self:startCell()
    if not start then return end

    local total = 0
    for y = 1, self.rows do
        for x = 1, self.cols do
            if self:typeWalkable(self.cells[y][x].tile) then total = total + 1 end
        end
    end
    local want = math.max(2, math.floor(total * Overworld.MIN_FREE_AT_DOOR))

    local function isFight(c)
        local e = c and c.encounter
        return (e and not c.cleared
            and (e.kind == "combat" or e.kind == "elite" or e.kind == "objective")) or false
    end

    -- The places reachable from the door without walking into a battle, plus the fights standing on that
    -- region's edge -- which are exactly the ones that could be given back to widen it.
    local function survey()
        local seen = { [cellKey(start)] = true }
        local q, qi, n, frontier = { start }, 1, 1, {}
        while qi <= #q do
            local c = q[qi]; qi = qi + 1
            for _, nb in ipairs(self:pathNeighbors(c.x, c.y)) do
                local k = cellKey(nb)
                if not seen[k] then
                    seen[k] = true
                    if isFight(nb) then
                        frontier[#frontier + 1] = nb
                    else
                        n = n + 1
                        q[#q + 1] = nb
                    end
                end
            end
        end
        return n, frontier
    end

    local n, frontier = survey()
    local guard = 0
    while n < want and #frontier > 0 and guard < 64 do
        guard = guard + 1
        -- The most recently blocked fight on the frontier, put back where it stood. An end is never
        -- moved -- the floor's own work is not this pass's to relocate.
        local give
        for i = #frontier, 1, -1 do
            local c = frontier[i]
            if c.encounter.kind ~= "objective" and c.blockedFrom then give = c; break end
        end

        -- NOT ONLY THE ONES THIS PASS MOVED. Giving back its own choices clears the floors it penned,
        -- and leaves the ones the ordinary seating penned on its own -- measured at 13%, which is one
        -- floor in eight opening on a company that has no move but a battle. The rule the player asked
        -- for is about the DOOR, not about which pass put the fight there, so a frontier fight that was
        -- never blocked is relocated instead: to the deepest free place on the floor, which is both far
        -- from the door and the likeliest to be worth walking to.
        local home
        if give then
            home = give.blockedFrom
            give.blockedFrom = nil
        else
            for i = #frontier, 1, -1 do
                if frontier[i].encounter.kind ~= "objective" then give = frontier[i]; break end
            end
            if not give then break end
            local dist = self:bfsDistances(start)
            local bestD
            for y = 1, self.rows do
                for x = 1, self.cols do
                    local c = self.cells[y][x]
                    local d = dist[cellKey(c)]
                    if d and self:typeWalkable(c.tile) and c ~= start
                        and not c.encounter and not c.cache and not c.gate and not c.key
                        and (not bestD or d > bestD) then
                        home, bestD = c, d
                    end
                end
            end
        end

        if home and not home.encounter then
            home.encounter = give.encounter
            give.encounter = nil
            self.blockingFights = math.max(0, (self.blockingFights or 1) - 1)
        else
            break
        end
        n, frontier = survey()
    end
    self.freeAtDoor = n
end

-- Weighted pick restricted to the pool's non-combat entries, or nil if the pool is all combat. Used to
-- keep the spine walkable -- a stop there is never a forced fight.
function Overworld:pickNonCombat(pool)
    local sub = {}
    for _, e in ipairs(pool) do
        if e.kind ~= "combat" and e.kind ~= "elite" then sub[#sub + 1] = e end
    end
    if #sub == 0 then return nil end
    return self:pickEncounter(sub)
end

-- The demotion partner to pickNonCombat: an elite rolled onto shallow ground is re-seated as a plain
-- fight rather than dropped, so the floor keeps the fight and loses only its rank.
function Overworld:pickOrdinaryCombat(pool)
    local sub = {}
    for _, e in ipairs(pool) do
        if e.kind == "combat" then sub[#sub + 1] = e end
    end
    if #sub == 0 then return nil end
    return self:pickEncounter(sub)
end

-- Weighted pick from a pool of { kind, weight, id?, name? } entries.
function Overworld:pickEncounter(pool)
    local total = 0
    for _, e in ipairs(pool) do total = total + (e.weight or 1) end
    local r = self.rng:random() * total
    for _, e in ipairs(pool) do
        r = r - (e.weight or 1)
        if r <= 0 then return e end
    end
    return pool[1]
end

-- How often a stop reads one tier above its band, so the arc is a slope rather than three flat shelves.
local TIER_SPIKE = 0.12

-- The pips the fog shows, stamped LAST so geometry never shifts under them.
function Overworld:assignEncounterTiers()
    local dist = self:bfsDistances(self:startCell())
    local maxD = 1
    for _, d in pairs(dist) do if d > maxD then maxD = d end end
    for y = 1, self.rows do
        for x = 1, self.cols do
            local e = self.cells[y][x].encounter
            if e and (e.kind == "combat" or e.kind == "elite") then
                local depth = (dist[cellKey(self.cells[y][x])] or 0) / maxD -- 0..1
                -- min(2, ...) rather than a clamp after the fact: depth is exactly 1.0 at the far
                -- corner, and floor(1.0 * 3) is 3, which would put that one place in a fourth band.
                local t = 1 + math.min(2, math.floor(depth * 3))
                if e.kind == "elite" then t = t + 1 end
                -- An AUTHORED floor has no rng and gets no spike: its stops are chosen, and a coin flip
                -- that made one of them a tier harder on some loads and not others would be a roll
                -- inside a file whose whole reason for existing is that it is not rolled.
                if self.rng and self.rng:random() < TIER_SPIKE then t = t + 1 end
                e.tier = math.max(1, math.min(3, t))
            end
        end
    end
end

-- THE WAY BACK UP, standing on the place the company walked in on.
--
-- A campaign ground has no such thing and does not want one: a quest is left by pressing Back and
-- leaving is free, so a cell offering it would be offering nothing. A DESCENT FLOOR is the other case,
-- and this is the whole of Wizardry's pacing engine: an expedition ends by WALKING BACK to the stair you
-- came down by, so how deep you push is bounded by how far you are willing to be from the way out.
--
-- Seated as an `encounter` rather than a field of its own, and that buys the whole pipeline: the marker
-- draws, the fog hides and reveals it, walking onto it engages through the same seam every other stop
-- uses, and the run save carries it in `cells` with the rest.
function Overworld:placeExit(params)
    if not params.exitAtStart then return end
    local start = self:startCell()
    if not start or start.encounter then return end
    start.encounter = { kind = "ascent", name = "The Way Up" }
end

-- ---------------------------------------------------------------------------
-- Authored floors
-- ---------------------------------------------------------------------------

-- Char -> tile for an authored floor's ASCII `map`. The role chars (S / X / 1..9) all stand on a place,
-- so they resolve to PLACE below rather than being listed here.
local LAYOUT_TILE = {
    ["#"] = Overworld.BLOCKED,
    ["."] = Overworld.PLACE,
}

-- Build a HAND-AUTHORED floor from data/overworld/<id>.lua instead of rolling one. The layout is an
-- ASCII `map` (rows of equal-length strings) plus a biome; see data/overworld/tutorial_flight.lua for
-- the legend. `S` fixes the start, `X` the objective, and each digit `1..9` is a stop: the Nth stop is
-- handed the Nth `params.alwaysEncounters` entry, so the geometry fixes WHERE each stop sits while the
-- quest stays the single source of WHAT it is (id / loot / conversation).
--
-- The result is an ordinary Overworld: same object shape and methods as generate(), so states/game.lua,
-- the renderer, fog and movement are none the wiser. Used by the prologue, whose tutorial choreography
-- needs a fixed route (the chest first, the boss last) rather than a roll that could reorder the stops.
function Overworld.fromLayout(params)
    local layout = params.layoutDef or require("data.overworld." .. params.layout)
    local self = setmetatable({}, Overworld)
    self.biome = params.biome or layout.biome
    local biomeDef = Biome.get(self.biome)
    self.tilesetId = biomeDef.tileset
    self.tilesetDef = Tileset.get(self.tilesetId)
    self.originX, self.originY = 0, 0
    self.margin = 0
    self.keyIds = {}
    self.gateCells = {}
    -- An authored floor keeps the tighter reveal for the same reason it is authored: its next place is
    -- meant to be a question.
    self.visionRadius = params.visionRadius or layout.visionRadius or 1

    local map = layout.map
    self.rows = #map
    self.cols = #map[1]
    self.size = params.tileSize or layout.tileSize
        or math.floor(Overworld.BOARD_EXTENT / math.max(self.cols, self.rows))

    local stops = {}
    self.cells = {}
    for y = 1, self.rows do
        self.cells[y] = {}
        local row = map[y]
        for x = 1, self.cols do
            local ch = row:sub(x, x)
            local cell = { x = x, y = y, tile = LAYOUT_TILE[ch] or Overworld.PLACE }
            self.cells[y][x] = cell
            if ch == "S" then
                self.start = { x = x, y = y }
            elseif ch == "X" then
                self.objective = { x = x, y = y }
            elseif ch:match("%d") then
                stops[tonumber(ch)] = cell
            end
        end
    end

    self.start = self.start or { x = 1, y = 1 }
    local objSpec = params.objective or layout.objective or {}
    if self.objective then
        local c = self.cells[self.objective.y][self.objective.x]
        c.encounter = { kind = "objective", name = objSpec.name or "Objective",
            questId = objSpec.questId, meet = objSpec.meet or nil }
        self.objective.questId = objSpec.questId
    end
    self.objectives = self.objective and { self.objective } or {}

    -- The Nth stop takes the Nth guaranteed encounter, so the authored order IS the running order.
    for i, e in ipairs(params.alwaysEncounters or {}) do
        local c = stops[i]
        if c then
            c.encounter = { kind = e.kind, id = e.id, name = e.name,
                            loot = e.loot, conversation = e.conversation }
        end
    end

    if self.objective then self:markSpine({ self.cells[self.objective.y][self.objective.x] }) end
    self:assignEncounterTiers()
    self.sealed = true
    return self
end

-- ---------------------------------------------------------------------------
-- Run persistence (save/resume the active traversal; see models/save.lua)
-- ---------------------------------------------------------------------------

-- The per-cell fields worth persisting: the geometry the renderer and movement read (`tile`), and the
-- mutable run state a resume must restore -- fog (`seen`), an engaged stop (`cleared`), a lifted key
-- (`picked`). The `encounter`/`gate`/`key`/`cache` sub-tables are plain data and ride along whole.
-- `x`/`y` equal the cell's own indices, so they are rebuilt from position rather than stored.
--
-- `secret` rides out because it is RUN STATE and not geometry: a place found on the third trip down must
-- still be there on the fourth, and a descent keeps its floors (Descent.keepFloor) precisely so that
-- discovery persists. `secretEnd` deliberately does NOT -- it is generation-only scaffolding, consumed
-- by placeSecretRewards before the floor is ever saved.
local CELL_FIELDS = { "tile", "seen", "cleared", "picked", "encounter", "gate", "key", "cache",
                      "secret", "errandAnswered" }

-- Snapshot the floor to plain data (no metatable, no love objects, no functions). It cannot be
-- regenerated from a seed on load -- the encounter pool is drawn in an unspecified (`pairs`) order --
-- so the whole floor is stored as-is. `tilesetDef` carries render data and is re-resolved from
-- `tilesetId` on restore rather than serialized.
function Overworld:snapshot()
    local cells = {}
    for y = 1, self.rows do
        local row = {}
        for x = 1, self.cols do
            local c, out = self.cells[y][x], {}
            for _, f in ipairs(CELL_FIELDS) do out[f] = c[f] end
            row[x] = out
        end
        cells[y] = row
    end

    return {
        cols = self.cols, rows = self.rows, size = self.size,
        margin = self.margin,
        tilesetId = self.tilesetId, biome = self.biome,
        originX = self.originX, originY = self.originY,
        visionRadius = self.visionRadius,
        start = { x = self.start.x, y = self.start.y },
        objective = self.objective and { x = self.objective.x, y = self.objective.y } or nil,
        -- EVERY end this floor carries, with the quest each belongs to. The cells already hold the same
        -- ids on their encounters; this is the index the checklist reads, and without it a resumed trip
        -- would come back with an empty list of work and no way to tick anything off.
        objectives = self.objectives,
        keyIds = self.keyIds,
        cells = cells,
    }
end

-- Rebuild an Overworld from Overworld:snapshot data. Same object shape and methods as generate(), so the
-- renderer, fog and movement are none the wiser. The generation-only scaffolding (spineKeys, gateCells,
-- rng) is not restored -- nothing at runtime reads it.
function Overworld.fromSnapshot(data)
    local self = setmetatable({}, Overworld)
    self.cols, self.rows = data.cols, data.rows
    self.size = data.size or math.floor(Overworld.BOARD_EXTENT / math.max(self.cols, self.rows))
    self.margin = data.margin or 0
    self.biome = data.biome
    self.tilesetId = data.tilesetId
    self.tilesetDef = Tileset.get(self.tilesetId)
    self.originX = data.originX or 0
    self.originY = data.originY or 0
    self.visionRadius = data.visionRadius or 1
    self.start = { x = data.start.x, y = data.start.y }
    self.objective = data.objective and { x = data.objective.x, y = data.objective.y } or nil
    self.objectives = data.objectives or (self.objective and { self.objective }) or {}
    self.keyIds = data.keyIds or {}
    self.gateCells = {}
    self.sealed = true -- a restored floor is finished by definition
    self.cells = {}
    for y = 1, self.rows do
        self.cells[y] = {}
        local row = (data.cells and data.cells[y]) or {}
        for x = 1, self.cols do
            local src = row[x] or {}
            local cell = { x = x, y = y, tile = src.tile or Overworld.BLOCKED }
            for _, f in ipairs(CELL_FIELDS) do
                if f ~= "tile" then cell[f] = src[f] end
            end
            self.cells[y][x] = cell
        end
    end
    return self
end

-- ---------------------------------------------------------------------------
-- Runtime queries (used by ui/overworld_map.lua and states/game.lua)
-- ---------------------------------------------------------------------------

function Overworld:get(x, y)
    return self.cells[y] and self.cells[y][x]
end

function Overworld:startCell() return self:get(self.start.x, self.start.y) end
function Overworld:objectiveCell() return self:get(self.objective.x, self.objective.y) end

-- Whether (x, y) is within `radius` STEPS of (cx, cy). Straight-line rather than walked: a place you can
-- see across a blocked cell is still a place you can see, and the fog is about how far the company can
-- read rather than how far it can walk.
function Overworld:inRange(cx, cy, x, y, radius)
    return math.abs(x - cx) + math.abs(y - cy) <= radius
end

-- Whether (x, y) can be READ from (cx, cy). Shared by reveal (which places get discovered) and the
-- renderer's fog (which are lit right now) so the two can never disagree.
--
-- There is no line of sight any more and there is nothing for one to do. Shadowcasting
-- (models/vision.lua) made walking a country an act of looking, because a wall stopped the light and a
-- junction opened as you reached it. A floor of places has no walls to cast against -- its silhouette is
-- on the map from arrival -- and what the fog hides is not WHERE the places are but WHAT IS IN THEM.
function Overworld:inVision(cx, cy, x, y, radius)
    return self:inRange(cx, cy, x, y, radius)
end

-- Fog: mark every place within `radius` of (cx, cy) as read. Discovery is permanent for the run.
-- Returns how many this call turned up for the FIRST time -- 0 when the step only walked back over
-- ground already known. Callers that pay out for exploring (the Poacher's Map) gate on that, so
-- re-treading can never mint anything.
function Overworld:reveal(cx, cy, radius)
    local found = 0
    for y = cy - radius, cy + radius do
        for x = cx - radius, cx + radius do
            if self:inVision(cx, cy, x, y, radius) then
                local c = self:get(x, y)
                -- A SECRET STOPS THE LIGHT. While the mark is on it the cell reads as absent, which is
                -- the whole of what makes it a secret; cleared by Overworld:findSecrets, after which it
                -- is an ordinary place and reads like one.
                if c and not c.seen and not self:isHidden(c) then
                    c.seen = true
                    found = found + 1
                end
            end
        end
    end
    return found
end

-- Walkable for an actor holding `keysHeld` (a set of keyId -> true). A gate is passable only with its
-- matching key.
function Overworld:isWalkable(x, y, keysHeld)
    local c = self:get(x, y)
    if not c then return false end
    if not self:typeWalkable(c.tile) then return false end
    if c.gate and not (keysHeld and keysHeld[c.gate.keyId]) then return false end
    return true
end

function Overworld:cellToPixel(x, y)
    return self.originX + (x - 1) * self.size, self.originY + (y - 1) * self.size
end

function Overworld:pixelToCell(px, py)
    return math.floor((px - self.originX) / self.size) + 1,
        math.floor((py - self.originY) / self.size) + 1
end

-- Flood fill over the floor ignoring gates. Backs the connectivity guarantee: every place should be
-- reachable from the start.
function Overworld:reachable(from)
    from = from or self:startCell()
    local seen = { [cellKey(from)] = from }
    local q, qi = { from }, 1
    while qi <= #q do
        local c = q[qi]; qi = qi + 1
        for _, n in ipairs(self:pathNeighbors(c.x, c.y)) do
            if not seen[cellKey(n)] then
                seen[cellKey(n)] = n
                q[#q + 1] = n
            end
        end
    end
    return seen
end

-- Forward-simulation solver: BFS from start with a growing key set, re-running whenever a new key is
-- collected, until it reaches a fixpoint. Returns (solved, info) where solved = objective reachable AND
-- every key collected.
function Overworld:solve()
    local start = self:startCell()
    local keys, collected = {}, {}

    while true do
        local seen = { [cellKey(start)] = start }
        local q, qi = { start }, 1
        local gotNew = false
        while qi <= #q do
            local c = q[qi]; qi = qi + 1
            if c.key and not keys[c.key.keyId] then
                keys[c.key.keyId] = true
                collected[c.key.keyId] = true
                gotNew = true
            end
            for _, d in ipairs(DIRS) do
                local nx, ny = c.x + d[1], c.y + d[2]
                if self:isWalkable(nx, ny, keys) then
                    local n = self:get(nx, ny)
                    if not seen[cellKey(n)] then
                        seen[cellKey(n)] = n
                        q[#q + 1] = n
                    end
                end
            end
        end

        if not gotNew then
            local reached = seen[cellKey(self:objectiveCell())] ~= nil
            local allKeys = true
            for _, keyId in ipairs(self.keyIds) do
                if not collected[keyId] then allKeys = false end
            end
            return reached and allKeys, {
                objectiveReached = reached,
                keysCollected = collected,
                keyIds = self.keyIds,
            }
        end
    end
end

return Overworld
