-- Procedurally generated overworld map: the scrolling grid loaded when a quest
-- starts. Pure logic + data (no love.graphics at require-time) so it loads under
-- the headless test suite; only love.math (seeded RNG + noise) is used, which is
-- available headless.
--
-- Generation pipeline (see docs/architecture.md / the plan):
--   1. maze carve   - recursive backtracker -> 1-tile-wide "path" corridors
--   2. braid        - knock out some dead-ends to add loops (the cycles)
--   3. rivers       - wandering "water" lines; a river over a path -> "bridge"
--   4. decorate     - forest fill gets rock/grass variants via noise (visual)
--   5. objective    - farthest dead-end becomes the boss/end-condition tile
--   6. gates/keys   - lock the objective's approach behind keys placed so they
--                     are always collectible first (solvable by construction)
--   7. encounters   - weighted markers on spaced path tiles
--
-- Everything is seeded off `params.seed`, so the same seed reproduces the same
-- map (asserted in tests/overworld_spec.lua).
--
--   local Overworld = require("models.overworld")
--   local grid = Overworld.generate({ cols = 41, rows = 29, seed = 123,
--       encounterCount = 8, keyCount = 1, objective = { name = "Warlord" } })

local Tileset = require("models.tileset")
local Biome = require("models.biome")

local Overworld = {}
Overworld.__index = Overworld

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- Walkability is owned by the grid's (biome) tileset so the model and renderer
-- never disagree. Resolved once in generate() into self.tilesetDef.
function Overworld:typeWalkable(tile)
    local def = self.tilesetDef.tiles[tile]
    return def ~= nil and def.walkable == true
end

-- Stable integer key for a cell, used as a set/map index in BFS passes.
local function cellKey(c) return c.y * 100000 + c.x end

-- Resolve a count that may be a fixed number or a { min, max } range (drawn from
-- the grid's seeded rng so it stays deterministic).
local function resolveCount(v, rng)
    if type(v) == "table" then
        local lo, hi = v.min or 0, v.max or v.min or 0
        if hi < lo then hi = lo end
        return rng:random(lo, hi)
    end
    return v or 0
end

-- Scale the play area to the number of "stops" the trail must host — the
-- encounters this map actually rolled, plus the objective and any keys — so a
-- light quest gets a compact map instead of a sparse, half-empty one.
--
-- Growth is *sub-linear* (span ~ sqrt(content)): if each side grew linearly with
-- content the area (and thus the walk) would balloon quadratically, which is what
-- made heavy quests feel like a slog. A sqrt span keeps encounter density roughly
-- constant while the map stays traversable, and both sides are hard-capped so no
-- roll can produce a marathon maze. Dimensions are kept odd for a centred lattice
-- and floored at a playable minimum. Play-area caps of 45x31 become ~49x35 once
-- the margin ring is added.
local DIM_MAX_COLS, DIM_MAX_ROWS = 45, 31
local function deriveDims(encounters, keyCount)
    local content = (encounters or 0) + (keyCount or 0)
    local span = math.floor(5.5 * math.sqrt(content)) -- ~11 at content=4, ~22 at 16
    local cols = math.max(17, math.min(DIM_MAX_COLS, 15 + span))
    local rows = math.max(13, math.min(DIM_MAX_ROWS, 13 + math.floor(span * 0.6)))
    if cols % 2 == 0 then cols = cols + 1 end
    if rows % 2 == 0 then rows = rows + 1 end
    return cols, rows
end

-- ---------------------------------------------------------------------------
-- Generation
-- ---------------------------------------------------------------------------

function Overworld.generate(params)
    params = params or {}
    local self = setmetatable({}, Overworld)
    self.size = params.tileSize or 32 -- logical pixels per cell (for cell<->pixel)
    -- The biome (forest is loose, castle is tight) drives maze spacing and river
    -- count; explicit params still win. Corridors stay 1 tile wide while the
    -- walls between them are (spacing - 1) tiles thick.
    self.biome = params.biome
    local biomeDef = Biome.get(params.biome)
    -- A ring of `margin` fill tiles frames the whole map so trails never hug the
    -- edge. It is padding *around* the requested play area (the quest's cols/rows),
    -- not carved out of it: we inflate the grid by 2*margin and offset the node
    -- lattice inward by the same amount, so the trail network keeps its full size.
    self.margin = params.margin or biomeDef.margin or 2
    self.rng = love.math.newRandomGenerator(params.seed or os.time())

    -- Resolve how many encounters this map will actually hold up front (a
    -- { min, max } range is drawn here, once) so the play area can be sized to
    -- fit the content. placeEncounters reuses this same number.
    self.encounterTarget = resolveCount(params.encounterCount, self.rng)

    -- Play area: honour explicit cols/rows, otherwise scale with the encounters
    -- (and keys) so the map never sprawls into empty wandering. See deriveDims.
    local dCols, dRows = deriveDims(self.encounterTarget, params.keyCount)
    local playCols = params.cols or dCols
    local playRows = params.rows or dRows
    self.cols = playCols + 2 * self.margin
    self.rows = playRows + 2 * self.margin
    self.tilesetId = biomeDef.tileset      -- which data/tilesets/<id> draws this map
    self.tilesetDef = Tileset.get(self.tilesetId) -- merged types + this biome's art
    self.spacing = params.spacing or biomeDef.spacing or 4
    self.originX = 0
    self.originY = 0
    self.keyIds = {}
    self.gateCells = {} -- keyId -> gate cell (for cleanup if a key can't be placed)

    self.cells = {}
    for y = 1, self.rows do
        self.cells[y] = {}
        for x = 1, self.cols do
            self.cells[y][x] = { x = x, y = y, tile = "forest" }
        end
    end

    self:carveMaze()
    self:braid(params.braid or 0.55)
    local riverSpec = params.riverCount
    if riverSpec == nil then riverSpec = biomeDef.rivers end
    self:placeRivers(resolveCount(riverSpec, self.rng))
    self:thinBridges() -- guarantee every bridge is exactly one tile
    self:decorate()
    self:placeObjectiveAndGates(params)
    self:placeEncounters(params)

    return self
end

function Overworld:inBounds(x, y)
    return x >= 1 and y >= 1 and x <= self.cols and y <= self.rows
end

-- Maze nodes sit on a lattice inset from the map edge by `margin` and spaced
-- `spacing` apart, so no corridor endpoint (and thus no path) ever lands in the
-- buffer ring.
local function isNode(self, x, y)
    local m = self.margin
    return x >= 1 + m and y >= 1 + m
        and x <= self.cols - m and y <= self.rows - m
        and (x - (1 + m)) % self.spacing == 0
        and (y - (1 + m)) % self.spacing == 0
end

-- Per-axis form of `isNode`: is this column / row one of the trail lattice lines?
-- Rivers use these to stay in the forest bands *between* corridors so they never
-- run alongside a road (which would fuse a long multi-tile bridge).
function Overworld:isNodeCol(x)
    local m = self.margin
    return x >= 1 + m and x <= self.cols - m and (x - (1 + m)) % self.spacing == 0
end

function Overworld:isNodeRow(y)
    local m = self.margin
    return y >= 1 + m and y <= self.rows - m and (y - (1 + m)) % self.spacing == 0
end

-- Carve a 1-tile-wide corridor between two nodes `spacing` apart. Only the line
-- of tiles is turned into "path"; the surrounding forest blocks stay thick.
function Overworld:carveCorridor(ax, ay, bx, by)
    local ux = (bx > ax and 1) or (bx < ax and -1) or 0
    local uy = (by > ay and 1) or (by < ay and -1) or 0
    local x, y = ax, ay
    while true do
        self.cells[y][x].tile = "path"
        if x == bx and y == by then break end
        x, y = x + ux, y + uy
    end
end

-- Recursive backtracker over the spaced node grid. Each carved passage is a
-- single-tile corridor; walls between corridors are (spacing - 1) tiles thick.
function Overworld:carveMaze()
    local S = self.spacing
    local dirs = { { S, 0 }, { -S, 0 }, { 0, S }, { 0, -S } }
    local visited = {}
    local sx, sy = 1 + self.margin, 1 + self.margin
    self.cells[sy][sx].tile = "path"
    visited[cellKey(self.cells[sy][sx])] = true

    local stack = { { sx, sy } }
    while #stack > 0 do
        local cur = stack[#stack]
        local cx, cy = cur[1], cur[2]

        local cand = {}
        for _, d in ipairs(dirs) do
            local nx, ny = cx + d[1], cy + d[2]
            if isNode(self, nx, ny) and not visited[cellKey(self.cells[ny][nx])] then
                cand[#cand + 1] = { nx, ny }
            end
        end

        if #cand > 0 then
            local pick = cand[self.rng:random(#cand)]
            self:carveCorridor(cx, cy, pick[1], pick[2])
            visited[cellKey(self.cells[pick[2]][pick[1]])] = true
            stack[#stack + 1] = { pick[1], pick[2] }
        else
            stack[#stack] = nil
        end
    end
end

-- Add loops: for each node that is a dead-end (<=1 open passage), sometimes
-- carve a corridor through to a neighbouring node.
function Overworld:braid(prob)
    local S = self.spacing
    local dirs = { { S, 0 }, { -S, 0 }, { 0, S }, { 0, -S } }
    for y = 1 + self.margin, self.rows - self.margin, S do
        for x = 1 + self.margin, self.cols - self.margin, S do
            local c = self.cells[y] and self.cells[y][x]
            if c and c.tile == "path" then
                local open, walls = 0, {}
                for _, d in ipairs(dirs) do
                    local nx, ny = x + d[1], y + d[2]
                    if isNode(self, nx, ny) then
                        local ux = (d[1] > 0 and 1) or (d[1] < 0 and -1) or 0
                        local uy = (d[2] > 0 and 1) or (d[2] < 0 and -1) or 0
                        if self.cells[y + uy][x + ux].tile == "path" then
                            open = open + 1
                        else
                            walls[#walls + 1] = { nx, ny }
                        end
                    end
                end
                if open <= 1 and #walls > 0 and self.rng:random() < prob then
                    local w = walls[self.rng:random(#walls)]
                    self:carveCorridor(x, y, w[1], w[2])
                end
            end
        end
    end
end

-- Pick a river's constant coordinate (row for a horizontal river, col for a
-- vertical one) inside a *forest band* — never on a trail lattice line — so the
-- river runs between corridors and only ever crosses them head-on. `size` is the
-- axis length (rows/cols); `lineOnGrid` tests whether a coordinate is a node line.
function Overworld:bandCoord(size, lineOnGrid)
    local m = self.margin
    if self.spacing > 1 then
        local span = size - 2 * m                 -- play length along this axis
        local nodes = math.max(0, math.floor((span - 1) / self.spacing)) -- node cells - 1
        local base = (1 + m) + self.spacing * self.rng:random(0, nodes)
        local off = self.rng:random(1, self.spacing - 1)
        local c = math.min(base + off, size - 1)
        if not self[lineOnGrid](self, c) then return c end
    end
    -- Fallback (tight biomes / degenerate spacing): any interior coordinate.
    return self.rng:random(2, size - 1)
end

-- Lay `count` rivers, each running edge-to-edge along one axis (chosen at random).
function Overworld:placeRivers(count)
    for _ = 1, count do
        self:walkRiver(self.rng:random() < 0.5)
    end
end

-- Walk one meandering river across the map. `horiz` = true runs it left->right
-- (drifting vertically); false runs it top->bottom (drifting horizontally). The
-- river keeps a persistent drift heading so it curves and wanders across the whole
-- map instead of tracing a straight line, while two rules keep the crossings clean:
--   * it never *dwells* on a trail lattice line (the moment it lands on one it
--     steps off), so it can only cross a road head-on, never run alongside it;
--   * it never drifts while sitting on a corridor tile, so a crossing stays a
--     single perpendicular tile.
-- `thinBridges` is the final backstop enforcing the exactly-one-tile guarantee.
function Overworld:walkRiver(horiz)
    local mainLen = horiz and self.cols or self.rows
    local crossMax = horiz and self.rows or self.cols
    local nodeLine = horiz and "isNodeRow" or "isNodeCol"
    local cross = self:bandCoord(crossMax, nodeLine) -- start off a trail line
    local dir = self.rng:random() < 0.5 and -1 or 1  -- persistent drift heading

    local function mark(main, c)
        if horiz then self:markRiver(main, c) else self:markRiver(c, main) end
    end
    local function onTrail(main, c)
        if horiz then return self:onTrailTile(main, c) else return self:onTrailTile(c, main) end
    end
    -- Step the drift to `cross + dir`, reflecting off the map edge, and lay the
    -- corner tile so the water stays orthogonally connected.
    local function drift(main)
        local nc = cross + dir
        if nc < 2 or nc > crossMax - 1 then dir = -dir; nc = cross + dir end
        if nc >= 2 and nc <= crossMax - 1 then mark(main, nc); cross = nc end
    end

    for main = 1, mainLen do
        mark(main, cross)
        if self[nodeLine](self, cross) then
            drift(main) -- never run along a road: leave the trail line immediately
        elseif not onTrail(main, cross) then
            if self.rng:random() < 0.14 then dir = -dir end -- long, smooth arcs
            if self.rng:random() < 0.4 then drift(main) end
        end
        -- (on a corridor tile but not a node line = a head-on crossing: hold course
        --  so it stays a single bridge tile.)
    end
end

-- Whether (x, y) is currently a walkable trail (path or an already-placed bridge).
function Overworld:onTrailTile(x, y)
    local c = self.cells[y] and self.cells[y][x]
    return c ~= nil and (c.tile == "path" or c.tile == "bridge")
end

function Overworld:markRiver(x, y)
    local c = self.cells[y] and self.cells[y][x]
    if not c then return end
    c.river = true
    if c.tile == "path" or c.tile == "bridge" then
        c.tile = "bridge"
        c.bridge = true
    else
        c.tile = "water"
    end
end

-- Enforce the "every bridge is exactly one tile" rule. Routing avoids the common
-- causes (rivers alongside roads, meander-doubling on a crossing), but two rivers
-- could still cross the same corridor a tile apart. For each orthogonally-connected
-- run of bridge tiles, keep the first and revert the rest to plain trail: still
-- walkable (road connectivity holds) and no longer a river tile (so the
-- "no river left as a path" invariant still holds).
function Overworld:thinBridges()
    local visited = {}
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            if c.tile == "bridge" and not visited[cellKey(c)] then
                visited[cellKey(c)] = true
                local q, qi = { c }, 1
                while qi <= #q do
                    local cur = q[qi]; qi = qi + 1
                    for _, d in ipairs(DIRS) do
                        local n = self.cells[cur.y + d[2]] and self.cells[cur.y + d[2]][cur.x + d[1]]
                        if n and n.tile == "bridge" and not visited[cellKey(n)] then
                            visited[cellKey(n)] = true
                            n.tile = "path" -- demote the extra crossing tile back to trail
                            n.bridge = nil
                            n.river = nil
                            q[#q + 1] = n
                        end
                    end
                end
            end
        end
    end
end

-- Cosmetic variety for the forest fill (all non-path types are blocked anyway).
function Overworld:decorate()
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            if c.tile == "forest" then
                local n = love.math.noise(x * 0.15, y * 0.15)
                if n > 0.72 then
                    c.tile = "rock"
                elseif n < 0.28 then
                    c.tile = "grass"
                end
            end
        end
    end
end

-- Orthogonal neighbours that are walkable by tile type (gates ignored).
function Overworld:pathNeighbors(x, y)
    local res = {}
    for _, d in ipairs(DIRS) do
        local nx, ny = x + d[1], y + d[2]
        local c = self.cells[ny] and self.cells[ny][nx]
        if c and self:typeWalkable(c.tile) then res[#res + 1] = c end
    end
    return res
end

-- BFS over the trail network (gates ignored). Returns dist[cellKey] and a
-- parent map for reconstructing the shortest-path spine.
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

-- Player start = the walkable tile nearest the map centre.
function Overworld:computeStart()
    local cx, cy = math.floor(self.cols / 2), math.floor(self.rows / 2)
    local best, bestd
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            if self:typeWalkable(c.tile) then
                local d = (x - cx) * (x - cx) + (y - cy) * (y - cy)
                if not bestd or d < bestd then bestd = d; best = c end
            end
        end
    end
    return best
end

-- Objective (usually a boss) + the lock/key chain that gates it. Keys are placed
-- strictly inside the region reachable *before* the first gate, so they are
-- always collectible in order and the objective is always reachable once held.
function Overworld:placeObjectiveAndGates(params)
    local start = self:computeStart()
    self.start = { x = start.x, y = start.y }

    local dist, parent = self:bfsDistances(start)

    -- Objective goes on a far dead-end (gating its corridor truly locks it), but
    -- NOT necessarily the single farthest one -- always maxing the distance made
    -- the objective a marathon to the map's far corner. Collect dead-ends in the
    -- top distance band and pick the one nearest ~80% of the max, so the critical
    -- path is long enough to gate meaningfully without being the worst case.
    local objective, objd = nil, nil -- plain farthest walkable tile (fallback)
    local maxDist = 0
    local deadEnds = {}              -- { cell, d } for every degree-1 tile
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            local d = dist[cellKey(c)]
            if self:typeWalkable(c.tile) and d then
                if not objd or d > objd then objd = d; objective = c end
                if d > maxDist then maxDist = d end
                if c ~= start and #self:pathNeighbors(x, y) == 1 then
                    deadEnds[#deadEnds + 1] = { cell = c, d = d }
                end
            end
        end
    end
    -- On an ASCENT map the objective is the PEAK: the farthest dead-end there is, not a comfortable
    -- one in the top band. The marathon this band exists to avoid is exactly what a climb is for --
    -- the road has to run out, and the thing at the end of it has to be the last thing.
    local pick, pickScore
    if params.ascent then
        for _, e in ipairs(deadEnds) do -- score is distance: take the highest
            if not pickScore or e.d > pickScore then pickScore = e.d; pick = e.cell end
        end
    else
        local band, want = maxDist * 0.7, maxDist * 0.8
        for _, e in ipairs(deadEnds) do -- score is error against the band: take the lowest
            if e.d >= band then
                local err = math.abs(e.d - want)
                if not pickScore or err < pickScore then pickScore = err; pick = e.cell end
            end
        end
    end
    objective = pick or objective
    self.objective = { x = objective.x, y = objective.y }
    objective.encounter = {
        kind = "objective",
        name = params.objective and params.objective.name or "Objective",
    }

    local K = params.keyCount or 0
    if K <= 0 then return end

    -- Spine: objective -> ... -> start (via BFS parents). Gate the tiles right
    -- before the objective; each needs a distinct key.
    local spine = {}
    local cur = objective
    while cur do
        spine[#spine + 1] = cur
        cur = parent[cellKey(cur)]
    end

    local firstGateDist = objd
    for i = 2, math.min(K + 1, #spine - 1) do
        local g = spine[i]
        local keyId = "key" .. (#self.keyIds + 1)
        g.gate = { keyId = keyId }
        self.gateCells[keyId] = g
        self.keyIds[#self.keyIds + 1] = keyId
        firstGateDist = math.min(firstGateDist, dist[cellKey(g)])
    end

    self:placeKeys(dist, firstGateDist)
end

-- Scatter one pickup per key into the pre-gate region. Any key that can't be
-- placed (tiny map) unlocks its gate, so the map is never unsolvable.
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
            -- Could not place this key: unlock its gate so solvability holds.
            local gate = self.gateCells[keyId]
            if gate then gate.gate = nil end
        end
    end

    -- Drop unlocked keyIds from the required list.
    local kept = {}
    for _, keyId in ipairs(self.keyIds) do
        if placed[keyId] then kept[#kept + 1] = keyId end
    end
    self.keyIds = kept
end

-- Place encounters on spaced trail tiles (never on start/objective/gate/key).
-- `params.encounterCount` is a number or { min, max } range (total encounters).
-- `params.alwaysEncounters` are guaranteed picks placed first; the rest are
-- drawn from the weighted `params.encounters` pool. Both come pre-filtered for
-- the player's prestige/conditionals by the caller (see models/encounter.lua).
function Overworld:placeEncounters(params)
    -- Resolved once in generate() (so the map could be sized to it); reuse it here.
    local count = self.encounterTarget or resolveCount(params.encounterCount, self.rng)
    local pool = params.encounters or { { kind = "combat", weight = 1 } }
    local always = params.alwaysEncounters or {}

    local cands = {}
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            if self:typeWalkable(c.tile) and not c.encounter and not c.gate and not c.key
                and not (self.start.x == x and self.start.y == y) then
                cands[#cands + 1] = c
            end
        end
    end

    for i = #cands, 2, -1 do
        local j = self.rng:random(i)
        cands[i], cands[j] = cands[j], cands[i]
    end

    -- Partial bias toward dead-ends: terminating a corridor in nothing feels like
    -- a wasted trip, so *some* encounters reward the detour -- but filling every
    -- dead-end first forced constant spur-and-return walking. Cap the dead-end
    -- share at ~half the count; the rest go on through-tiles the player passes en
    -- route. Leftover dead-ends trail the through-tiles as fallback. Order is
    -- otherwise preserved (stable) so the spacing rule below still holds.
    local deadEnds, rest = {}, {}
    for _, c in ipairs(cands) do
        if #self:pathNeighbors(c.x, c.y) == 1 then
            deadEnds[#deadEnds + 1] = c
        else
            rest[#rest + 1] = c
        end
    end
    local deadQuota = math.ceil((count or 0) * 0.5)
    cands = {}
    for i = 1, math.min(deadQuota, #deadEnds) do cands[#cands + 1] = deadEnds[i] end
    for _, c in ipairs(rest) do cands[#cands + 1] = c end
    for i = deadQuota + 1, #deadEnds do cands[#cands + 1] = deadEnds[i] end

    local placed = {}
    local next_ = 1

    -- ASCENT maps (`params.ascent`): the guaranteed encounters are a ROUTE, not a set. Laid out in
    -- authored order by distance from the start, so `always = { pickets, pickets, line, line, breach }`
    -- is met bottom-to-top -- the outer ring first, the thing leaning on the gate last, and the
    -- objective beyond all of them at the farthest point (see placeObjectiveAndGates).
    --
    -- Off by default: ordinary maps want their guaranteed encounters scattered, and a fixed running
    -- order would make every quest that uses `always` read as a corridor.
    if params.ascent and #always > 0 then
        local dist = self:bfsDistances(self.start)
        local byDist = {}
        for _, c in ipairs(cands) do
            if dist[cellKey(c)] then byDist[#byDist + 1] = c end
        end
        table.sort(byDist, function(a, b)
            local da, db = dist[cellKey(a)], dist[cellKey(b)]
            if da ~= db then return da < db end
            -- Stable tie-break, so a given seed still reproduces its map exactly.
            if a.y ~= b.y then return a.y < b.y end
            return a.x < b.x
        end)

        -- Walk outward, taking the first tile far enough from the last marker. Spacing is a
        -- preference, not a requirement: a short trail that cannot honour it still gets every
        -- authored encounter rather than silently dropping the top of the climb.
        local i = 1
        for _, e in ipairs(always) do
            local chosen
            for j = i, #byDist do
                local c = byDist[j]
                local last = placed[#placed]
                if not last or (math.abs(last.x - c.x) + math.abs(last.y - c.y)) >= 3 then
                    chosen, i = c, j + 1
                    break
                end
            end
            chosen = chosen or byDist[i]
            if chosen then
                i = i + 1
                chosen.encounter = { kind = e.kind, id = e.id, name = e.name }
                placed[#placed + 1] = chosen
            end
        end
        self.encounterCount = #placed
        return
    end

    -- Guaranteed specific encounters first (placed even if a little close).
    for _, e in ipairs(always) do
        local c = cands[next_]
        next_ = next_ + 1
        if c then
            c.encounter = { kind = e.kind, id = e.id, name = e.name }
            placed[#placed + 1] = c
        end
    end

    -- Fill the rest up to the resolved count with weighted, spaced picks.
    local target = math.max(count, #placed)
    for i = next_, #cands do
        if #placed >= target then break end
        local c = cands[i]
        local ok = true
        for _, p in ipairs(placed) do
            if math.abs(p.x - c.x) + math.abs(p.y - c.y) < 3 then ok = false; break end
        end
        if ok then
            local pick = self:pickEncounter(pool)
            c.encounter = { kind = pick.kind, id = pick.id, name = pick.name }
            placed[#placed + 1] = c
        end
    end
    self.encounterCount = #placed
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

-- ---------------------------------------------------------------------------
-- Runtime queries (used by ui/overworld_map.lua and states/game.lua)
-- ---------------------------------------------------------------------------

function Overworld:get(x, y)
    return self.cells[y] and self.cells[y][x]
end

-- Whether tile (x, y) is within vision `radius` of (cx, cy). Circular (Euclidean)
-- with a small bias so the lit area reads as a soft disc rather than a hard square.
-- Shared by reveal (which tiles get discovered) and the renderer's fog (which are
-- currently lit) so the two can never disagree.
function Overworld:inVision(cx, cy, x, y, radius)
    local dx, dy = x - cx, y - cy
    return dx * dx + dy * dy <= radius * radius + radius
end

-- Fog of war: mark every cell within vision `radius` of (cx, cy) as discovered.
-- Discovery is permanent for the run (the grid is rebuilt fresh each quest); the
-- renderer recomputes which discovered tiles are *currently* in vision each frame.
function Overworld:reveal(cx, cy, radius)
    for y = cy - radius, cy + radius do
        for x = cx - radius, cx + radius do
            if self:inVision(cx, cy, x, y, radius) then
                local c = self:get(x, y)
                if c then c.seen = true end
            end
        end
    end
end

function Overworld:startCell() return self:get(self.start.x, self.start.y) end
function Overworld:objectiveCell() return self:get(self.objective.x, self.objective.y) end

-- Walkable for an actor holding `keysHeld` (a set of keyId -> true). A gate is
-- passable only with its matching key.
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

-- Flood fill over the trail network ignoring gates. Backs the connectivity
-- guarantee: every trail tile should be reachable from the start.
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

-- Forward-simulation solver: BFS from start with a growing key set, re-running
-- whenever a new key is collected, until it reaches a fixpoint. Returns
-- (solved, info) where solved = objective reachable AND every key collected.
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
