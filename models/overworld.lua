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
--   8. caches       - forging materials on the dead ends nothing else claimed,
--                     scaled by how far off the critical path they sit
--
-- Everything is seeded off `params.seed`, so the same seed reproduces the same
-- map (asserted in tests/overworld_spec.lua).
--
--   local Overworld = require("models.overworld")
--   local grid = Overworld.generate({ cols = 41, rows = 29, seed = 123,
--       encounterCount = 8, keyCount = 1, objective = { name = "Warlord" } })

local Tileset = require("models.tileset")
local Biome = require("models.biome")
local Material = require("models.material") -- cache payloads: craft grades + the sponsoring house's stock

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
-- and floored at a playable minimum. Play-area caps of 27x19 become ~31x23 once
-- the margin ring is added -- deliberately compact: a Dream Quest board is dense
-- and readable, every tile a choice, not a marathon warren to shuffle a token
-- through (see the plan / docs on the overworld redesign).
local DIM_MAX_COLS, DIM_MAX_ROWS = 27, 19
-- Tight biomes need a physically smaller footprint. A biome's node `spacing` sets how much of the
-- area is trail: a castle/underworld (spacing 2, 1-tile walls) packs roughly twice the corridor into
-- the same rectangle as a forest (spacing 4, 3-tile-thick fill). Sizing on encounter count alone --
-- as if every biome were as loose as the forest -- left tight biomes a vast, near-empty warren for
-- only a handful of stops. So scale the span by sqrt(spacing / baseline): density ~ 1/spacing, so
-- to hold encounter density constant the area scales with spacing and the linear span with its root.
-- Normalized to the forest's spacing, so forest maps are unchanged.
--
-- `caches` counts toward the content the same way keys do: a cache is a stop the player walks to, so
-- leaving it out of this sum would make maps DENSER rather than larger and quietly undo the sizing.
local BASELINE_SPACING = 4
local function deriveDims(encounters, keyCount, cacheCount, spacing)
    local content = (encounters or 0) + (keyCount or 0) + (cacheCount or 0)
    local tightness = math.sqrt((spacing or BASELINE_SPACING) / BASELINE_SPACING)
    local span = math.floor(4.0 * math.sqrt(content) * tightness) -- ~8 at content=4 (forest)
    local cols = math.max(13, math.min(DIM_MAX_COLS, 13 + span))
    local rows = math.max(11, math.min(DIM_MAX_ROWS, 11 + math.floor(span * 0.6)))
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

    -- Corridor spacing is resolved before sizing so a tight biome gets a smaller footprint (deriveDims).
    self.spacing = params.spacing or biomeDef.spacing or 4

    -- Material caches: how many spare dead ends this map pays out on. Derived from the encounter count
    -- (about one cache per two stops) unless the quest says otherwise, so a short errand scatters two
    -- and a long one four without any quest having to author a number. Resolved here, before sizing,
    -- for the same reason the encounter count is.
    self.cacheTarget = params.cacheCount ~= nil
        and resolveCount(params.cacheCount, self.rng)
        or math.max(1, math.floor((self.encounterTarget or 0) / 2))

    -- Vision is per-map, not a global constant: a rolled board reveals a NEIGHBOURHOOD (radius 3) so the
    -- player can read the encounters ahead and plan a route (reveal-then-choose). The tutorial's authored
    -- flight leg keeps the tighter radius 2 (set in fromLayout) so its next leg stays a mystery. A party
    -- torch still widens whatever this is -- states/game.lua maxes the two.
    self.visionRadius = params.visionRadius or 3

    -- Play area: honour explicit cols/rows, otherwise scale with the encounters
    -- (and keys) so the map never sprawls into empty wandering. See deriveDims.
    local dCols, dRows = deriveDims(self.encounterTarget, params.keyCount, self.cacheTarget, self.spacing)
    local playCols = params.cols or dCols
    local playRows = params.rows or dRows
    self.cols = playCols + 2 * self.margin
    self.rows = playRows + 2 * self.margin
    self.tilesetId = biomeDef.tileset      -- which data/tilesets/<id> draws this map
    self.tilesetDef = Tileset.get(self.tilesetId) -- merged types + this biome's art
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
    self:placeCaches(params)    -- pay out the dead ends nothing else claimed
    self:pruneDeadStubs()       -- trim barren spur-and-return corridors (no RNG)
    self:assignEncounterTiers() -- difficulty tell for the fog (drawn from rng LAST)

    return self
end

-- ---------------------------------------------------------------------------
-- Authored maps
-- ---------------------------------------------------------------------------

-- Char -> tile type for an authored map's ASCII `map`. The role chars (S / X / 1..9)
-- all stand on trail, so they are resolved to "path" below rather than listed here.
local LAYOUT_TILE = {
    ["#"] = "forest", ["."] = "path", ["="] = "bridge", ["~"] = "water",
    [","] = "grass",  ["^"] = "rock",
}

-- Build a HAND-AUTHORED overworld from data/overworld/<id>.lua instead of carving a maze. The layout is
-- an ASCII `map` (rows of equal-length strings) plus a biome; see data/overworld/tutorial_flight.lua for
-- the legend. `S` fixes the start, `X` the objective, and each digit `1..9` is a route stop: the Nth
-- stop is handed the Nth `params.alwaysEncounters` entry, so the geometry fixes WHERE each stop sits
-- while the quest stays the single source of WHAT it is (id / loot / conversation).
--
-- The result is an ordinary Overworld: same object shape and methods as generate(), so states/game.lua,
-- the renderer, fog and movement are none the wiser. Used by the prologue's flight leg, whose tutorial
-- choreography needs a fixed trail (the chest first, the boss last) rather than a roll that could
-- reorder the stops or crowd the opening.
function Overworld.fromLayout(params)
    local layout = params.layoutDef or require("data.overworld." .. params.layout)
    local self = setmetatable({}, Overworld)
    self.size = params.tileSize or layout.tileSize or 32
    self.biome = params.biome or layout.biome
    local biomeDef = Biome.get(self.biome)
    self.tilesetId = biomeDef.tileset
    self.tilesetDef = Tileset.get(self.tilesetId)
    self.margin = 0
    self.spacing = 1
    -- Authored legs keep the tight radius 2: their choreography spaces the stops so the fog only lifts
    -- off the next one as you reach it (see data/overworld/tutorial_flight.lua). Rolled maps use 3.
    self.visionRadius = params.visionRadius or 2
    self.originX, self.originY = 0, 0
    self.keyIds = {}
    self.gateCells = {}

    local grid = layout.map
    self.rows = #grid
    self.cols = #grid[1]
    self.cells = {}
    local routeCells = {}
    for y = 1, self.rows do
        self.cells[y] = {}
        local row = grid[y]
        assert(#row == self.cols,
            "authored layout row " .. y .. " is " .. #row .. " wide, expected " .. self.cols)
        for x = 1, self.cols do
            local ch = row:sub(x, x)
            local cell = { x = x, y = y, tile = LAYOUT_TILE[ch] or "path" }
            self.cells[y][x] = cell
            if ch == "S" then
                self.start = { x = x, y = y }
            elseif ch == "X" then
                self.objective = { x = x, y = y }
                cell.encounter = { kind = "objective",
                    name = params.objective and params.objective.name or "Objective" }
            elseif ch:match("%d") then
                routeCells[tonumber(ch)] = cell
            end
        end
    end

    assert(self.start, "authored layout has no start (S)")
    assert(self.objective, "authored layout has no objective (X)")

    -- Zip the quest's guaranteed encounters onto the numbered route cells, in order.
    local always = params.alwaysEncounters or {}
    for i, e in ipairs(always) do
        local cell = routeCells[i]
        if cell then
            cell.encounter = { kind = e.kind, id = e.id, name = e.name,
                loot = e.loot, conversation = e.conversation }
        end
    end
    self.encounterCount = #always

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
-- How broken-up a biome's fill reads. `rock`/`grass` are the noise thresholds the solid fill breaks at:
-- widening the gap between them leaves more unbroken fill, narrowing it produces a mottled floor. A
-- biome absent here uses `default`, which is the forest's original 0.72/0.28 at scale 0.15 -- so every
-- map that existed before this table produces exactly what it always did.
--
-- Deliberately noise-only: `love.math.noise` is deterministic on its coordinates and draws nothing from
-- the grid's rng, so retuning any row here cannot shift a single seeded draw in the passes that follow.
local DECOR = {
    default  = { scale = 0.15, rock = 0.72, grass = 0.28 },
    -- Dunes run in long unbroken sweeps: a coarse scale and thresholds pushed apart, so the fill
    -- stays whole and the eye reads distance rather than texture.
    desert   = { scale = 0.09, rock = 0.82, grass = 0.20 },
    -- Snow lies flat and even. Almost no rock breaks it; what does is scoured tussock.
    tundra   = { scale = 0.13, rock = 0.86, grass = 0.34 },
    -- Fissured, shattered ground -- the most broken fill in the game, at the finest scale.
    volcanic = { scale = 0.22, rock = 0.58, grass = 0.42 },
    -- Thicket and standing sedge, patchier than forest but not rocky: rock is rare, grass common.
    swamp    = { scale = 0.18, rock = 0.88, grass = 0.44 },
}

function Overworld:decorate()
    local d = DECOR[self.biome] or DECOR.default
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            if c.tile == "forest" then
                local n = love.math.noise(x * d.scale, y * d.scale)
                if n > d.rock then
                    c.tile = "rock"
                elseif n < d.grass then
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
    -- The objective MUST land on a strict dead-end, or its spine gate can simply be walked around (a
    -- degree-2 tile has a second route the gate never covers). On a compact, braided board the top
    -- distance band can hold no dead-end at all; when it doesn't, fall back to the FARTHEST dead-end
    -- there is rather than a plain far tile, and only accept a non-dead-end if the map has none.
    local farDeadEnd, farDeadD
    for _, e in ipairs(deadEnds) do
        if not farDeadD or e.d > farDeadD then farDeadD = e.d; farDeadEnd = e.cell end
    end
    objective = pick or farDeadEnd or objective
    self.objective = { x = objective.x, y = objective.y }
    objective.encounter = {
        kind = "objective",
        name = params.objective and params.objective.name or "Objective",
    }

    -- Spine: objective -> ... -> start (via BFS parents) = the critical path. Persist it as a set of
    -- cell keys so encounter placement can keep skippable combats OFF it -- a wounded party must always
    -- be able to route around to the boss. Built unconditionally, even with no keys.
    local spine = {}
    self.spineKeys = {}
    local cur = objective
    while cur do
        spine[#spine + 1] = cur
        self.spineKeys[cellKey(cur)] = true
        cur = parent[cellKey(cur)]
    end

    local K = params.keyCount or 0
    if K <= 0 then return end

    -- Gate the tiles right before the objective; each needs a distinct key.
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

-- ---------------------------------------------------------------------------
-- Material caches
-- ---------------------------------------------------------------------------

-- How far off the critical path every walkable tile lies: a multi-source BFS seeded from the whole
-- spine at once, so a tile ON the route reads 0 and a spur reads the number of tiles the detour costs.
-- The one measure a cache's payload scales on -- the generator already knows the route, so "how far
-- did you stray" is free where "was this worth it" would otherwise have to be guessed.
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
-- particular board offers -- so "the far spur pays best" is true on a cramped map and a sprawling one
-- alike. Absolute tile counts do not survive a braided maze, where a spur can wander twenty tiles off
-- a short spine and turn one tile into a whole campaign's ore.
--
-- Both counts are capped hard. The point of the far cache is that it is BETTER, not that it is a
-- windfall: a full +10 forge bills eleven craft stock, so a single tile must never come close.
local CACHE_CRAFT_MIN, CACHE_CRAFT_MAX = 1, 4
local CACHE_HOUSE_MIN, CACHE_HOUSE_MAX = 1, 3

-- Scatter material caches onto the dead ends nothing else claimed. Runs AFTER placeEncounters so it
-- takes the leftovers -- an encounter is the better payoff for a spur, and this pays out the ones that
-- would otherwise end in nothing. Runs BEFORE pruneDeadStubs, which treats a cache as reason enough to
-- keep a corridor alive.
--
-- TWO AXES, both already measured by the time this runs:
--   WHICH   the sponsoring house's stock (params.houseMaterial, resolved by the caller from the
--           quest's sponsor). Running one house's line therefore yields what ANOTHER house's gear
--           wants at the Forge -- seven sealed ladders become one economy.
--   HOW FAR the craft grade and both counts, off the tile's distance from the critical path.
--
-- Placing fewer than the target is fine and silent: a cramped board simply pays out less, the same
-- graceful fallback placeKeys takes.
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

    -- Dead ends first, then off-spine tiles: a board that braided all its spurs away still pays, it
    -- just pays somewhere the player was more likely to pass anyway.
    local cands = {}
    for _, c in ipairs(deadEnds) do cands[#cands + 1] = c end
    local dist = self:spineDistances()
    for _, c in ipairs(spare) do
        if (dist[cellKey(c)] or 0) > 0 then cands[#cands + 1] = c end
    end

    -- The deepest detour ON THIS BOARD is the top of the scale everything else is read against.
    local deepest = 0
    for _, c in ipairs(cands) do
        local d = dist[cellKey(c)] or 0
        if d > deepest then deepest = d end
    end

    -- Where `detour` sits on this board's 0..1 scale of strayed-from-the-road.
    local function ratioOf(detour)
        if deepest <= 0 then return 0 end
        return math.min(1, detour / deepest)
    end

    -- Scale `ratio` onto lo..hi, rounded, so the shallowest cache pays lo and the deepest pays hi.
    local function scaled(ratio, lo, hi)
        return lo + math.floor(ratio * (hi - lo) + 0.5)
    end

    local grades = Material.craftGrades()
    for i = 1, math.min(count, #cands) do
        local c = cands[i]
        local ratio = ratioOf(dist[cellKey(c)] or 0)

        local materials = {}
        materials[grades[scaled(ratio, 1, #grades)]] = scaled(ratio, CACHE_CRAFT_MIN, CACHE_CRAFT_MAX)
        if params.houseMaterial then
            materials[params.houseMaterial] = (materials[params.houseMaterial] or 0)
                + scaled(ratio, CACHE_HOUSE_MIN, CACHE_HOUSE_MAX)
        end
        c.cache = { materials = materials }
    end
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

    -- Skippable combats: keep combat/elite OFF the objective->start spine so a wounded party can always
    -- route around to the boss. Off-spine tiles are filled first (dead-end bias preserved within each
    -- half); on-spine tiles only take non-combat stops (a combat rolled onto one is re-seated as a
    -- non-combat, or skipped if the pool has none). Ascent maps opt out -- there combat IS the route.
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
                chosen.encounter = { kind = e.kind, id = e.id, name = e.name,
                                     loot = e.loot, conversation = e.conversation }
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
            c.encounter = { kind = e.kind, id = e.id, name = e.name,
                            loot = e.loot, conversation = e.conversation }
            placed[#placed + 1] = c
        end
    end

    -- Guaranteed VARIETY (density + mix): a rolled board must never be a wall of fights. Seat at least one
    -- of each "texture" kind the pool offers -- a Reliquary to stock the run's relics, a Rest to mend --
    -- when `always` didn't already. Placed like the guaranteed ids above (front candidates, spacing a
    -- preference), all non-combat so the objective spine stays walkable. Tunable via params.guaranteeKinds;
    -- the default is what the roguelike inner loop needs to feel like one (see models/relic.lua).
    for _, kind in ipairs(params.guaranteeKinds or { "relic_cache", "rest" }) do
        local have = false
        for _, p in ipairs(placed) do if p.encounter.kind == kind then have = true; break end end
        if not have then
            local entry
            for _, e in ipairs(pool) do if e.kind == kind then entry = e; break end end
            local c = entry and cands[next_]
            if c then
                next_ = next_ + 1
                c.encounter = { kind = entry.kind, id = entry.id, name = entry.name }
                placed[#placed + 1] = c
            end
        end
    end

    -- Fill the rest up to the resolved count with weighted, spaced picks.
    local target = math.max(count, #placed)
    -- Combat SHARE cap: the encounter pool is fight-heavy by blueprint COUNT (a dozen combat kinds, a
    -- handful of texture ones), so weighted-random alone leaves a run mostly fights. Hold combat to at most
    -- ~60% of the stops; a fight rolled past the cap is re-seated as a non-combat stop -- the same move the
    -- spine rule makes -- so the pool's caches, rests and stops fill the gaps. Tunable via params.combatShare.
    local isFight = function(k) return k == "combat" or k == "elite" end
    local combatCap = math.floor(target * (params.combatShare or 0.6))
    local combatPlaced = 0
    for _, p in ipairs(placed) do if isFight(p.encounter.kind) then combatPlaced = combatPlaced + 1 end end
    for i = next_, #cands do
        if #placed >= target then break end
        local c = cands[i]
        local ok = true
        for _, p in ipairs(placed) do
            if math.abs(p.x - c.x) + math.abs(p.y - c.y) < 2 then ok = false; break end
        end
        if ok then
            local pick = self:pickEncounter(pool)
            -- Re-seat a fight as a non-combat stop when it cannot stand here: on the walkable spine, or
            -- once the combat-share cap is full. Keep the fight only if the pool has no texture left.
            local onSpine = self.spineKeys and not params.ascent and self.spineKeys[cellKey(c)]
            if isFight(pick.kind) and (onSpine or combatPlaced >= combatCap) then
                pick = self:pickNonCombat(pool) or pick
            end
            if pick then
                c.encounter = { kind = pick.kind, id = pick.id, name = pick.name }
                placed[#placed + 1] = c
                if isFight(pick.kind) then combatPlaced = combatPlaced + 1 end
            end
        end
    end
    self.encounterCount = #placed
end

-- Weighted pick restricted to the pool's non-combat entries (treasure/event/rest/town), or nil if the
-- pool is all combat. Used to keep the objective spine walkable -- a stop there is never a forced fight.
function Overworld:pickNonCombat(pool)
    local sub = {}
    for _, e in ipairs(pool) do
        if e.kind ~= "combat" and e.kind ~= "elite" then sub[#sub + 1] = e end
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

-- Trim barren dead-end spurs. A corridor that terminates in nothing is pure spur-and-return walking,
-- the very thing that made the old sprawling maze a slog. Iteratively revert any degree-<=1 "path" leaf
-- that carries no encounter/gate/key (and is neither start nor objective) back to forest, until no such
-- leaf remains. Only true leaves are removed, so connectivity and solvability are preserved -- nothing
-- ever routes THROUGH a leaf. Bridges are left alone so a river crossing is never half-erased. Uses no
-- RNG, so it cannot perturb the seeded map (same seed still reproduces).
function Overworld:pruneDeadStubs()
    local function protected(c)
        -- A cache counts: a spur with something at the end of it is not a barren spur, which is the
        -- only kind this pass exists to remove.
        return c.encounter or c.gate or c.key or c.cache
            or (self.start and self.start.x == c.x and self.start.y == c.y)
            or (self.objective and self.objective.x == c.x and self.objective.y == c.y)
    end
    local changed = true
    while changed do
        changed = false
        for y = 1, self.rows do
            for x = 1, self.cols do
                local c = self.cells[y][x]
                if c.tile == "path" and not protected(c) and #self:pathNeighbors(x, y) <= 1 then
                    c.tile = "forest"
                    c.river = nil
                    changed = true
                end
            end
        end
    end
end

-- Difficulty tell for the fog: every combat/elite encounter gets a `tier` (1..3) the renderer shows as
-- pips so the player can read a fight's danger BEFORE committing to the tile (reveal-then-choose), and
-- #5 scales its reward by the same tier. Deeper on the board reads tougher. Drawn from self.rng LAST --
-- after every placement pass -- so it never shifts the seeded geometry, yet stays deterministic. Walked
-- in a stable grid order so the rng draws reproduce. Non-combat stops (treasure/rest/event) get no tier.
function Overworld:assignEncounterTiers()
    local dist = self:bfsDistances(self:startCell())
    local maxD = 1
    for _, d in pairs(dist) do if d > maxD then maxD = d end end
    for y = 1, self.rows do
        for x = 1, self.cols do
            local e = self.cells[y][x].encounter
            if e and (e.kind == "combat" or e.kind == "elite") then
                local base = (e.kind == "elite") and 3 or 1
                local depth = (dist[cellKey(self.cells[y][x])] or 0) / maxD -- 0..1
                local t = base + (depth >= 0.66 and 1 or 0)
                if self.rng:random() < 0.25 then t = t + 1 end -- the occasional spike
                e.tier = math.max(1, math.min(3, t))
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Run persistence (save/resume the active traversal; see models/save.lua)
-- ---------------------------------------------------------------------------

-- The per-cell fields worth persisting: the geometry the renderer/movement read (`tile`, plus the river
-- decoration), and the mutable run state a resume must restore -- fog (`seen`), an engaged encounter
-- (`cleared`), and a lifted key (`picked`). The `encounter`/`gate`/`key` sub-tables are plain data (ids,
-- names, tiers, loot/conversation ids) and ride along whole. `x`/`y` equal the cell's own indices, so they
-- are rebuilt from position rather than stored (this is most of the file's cells, so it matters).
local CELL_FIELDS = { "tile", "river", "bridge", "seen", "cleared", "picked", "encounter", "gate", "key", "cache" }

-- Snapshot the grid to plain data (no metatable, no love objects, no functions). The map cannot be
-- regenerated from a seed on load -- the encounter pool is drawn in an unspecified (`pairs`) order, so the
-- same seed would reshuffle the stops -- so the whole board is stored as-is. `tilesetDef` carries render
-- data and is re-resolved from `tilesetId` on restore rather than serialized (see Overworld.fromSnapshot).
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
        margin = self.margin, spacing = self.spacing,
        tilesetId = self.tilesetId, biome = self.biome,
        originX = self.originX, originY = self.originY,
        visionRadius = self.visionRadius,
        start = { x = self.start.x, y = self.start.y },
        objective = self.objective and { x = self.objective.x, y = self.objective.y } or nil,
        keyIds = self.keyIds,
        cells = cells,
    }
end

-- Rebuild an Overworld from Overworld:snapshot data. Same object shape and methods as generate(), so the
-- renderer, fog and movement are none the wiser; `tilesetDef` is re-resolved here (never serialized). The
-- generation-only scaffolding (spineKeys, gateCells map, rng) is not restored -- nothing at runtime reads it.
function Overworld.fromSnapshot(data)
    local self = setmetatable({}, Overworld)
    self.size = data.size or 32
    self.cols, self.rows = data.cols, data.rows
    self.margin = data.margin or 0
    self.spacing = data.spacing or 1
    self.biome = data.biome
    self.tilesetId = data.tilesetId
    self.tilesetDef = Tileset.get(self.tilesetId)
    self.originX = data.originX or 0
    self.originY = data.originY or 0
    self.visionRadius = data.visionRadius or 2
    self.start = { x = data.start.x, y = data.start.y }
    self.objective = data.objective and { x = data.objective.x, y = data.objective.y } or nil
    self.keyIds = data.keyIds or {}
    self.gateCells = {}
    self.cells = {}
    for y = 1, self.rows do
        self.cells[y] = {}
        local row = (data.cells and data.cells[y]) or {}
        for x = 1, self.cols do
            local src = row[x] or {}
            local cell = { x = x, y = y, tile = src.tile or "forest" }
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
-- Returns how many cells this call turned up for the FIRST time -- 0 when the step
-- only walked back over ground already mapped. Callers that pay out for exploring
-- (the Poacher's Map) gate on that, so re-treading can never mint anything.
function Overworld:reveal(cx, cy, radius)
    local found = 0
    for y = cy - radius, cy + radius do
        for x = cx - radius, cx + radius do
            if self:inVision(cx, cy, x, y, radius) then
                local c = self:get(x, y)
                if c and not c.seen then
                    c.seen = true
                    found = found + 1
                end
            end
        end
    end
    return found
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
