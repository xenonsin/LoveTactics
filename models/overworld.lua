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

local Tileset = require("data.tilesets.overworld")
local Biome = require("models.biome")

local Overworld = {}
Overworld.__index = Overworld

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- Walkability is owned by the tileset so the model and renderer never disagree.
local function typeWalkable(tile)
    local def = Tileset.tiles[tile]
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

-- ---------------------------------------------------------------------------
-- Generation
-- ---------------------------------------------------------------------------

function Overworld.generate(params)
    params = params or {}
    local self = setmetatable({}, Overworld)
    self.cols = params.cols or 41
    self.rows = params.rows or 29
    self.size = params.tileSize or 32 -- logical pixels per cell (for cell<->pixel)
    -- The biome (forest is loose, castle is tight) drives maze spacing and river
    -- count; explicit params still win. Corridors stay 1 tile wide while the
    -- walls between them are (spacing - 1) tiles thick.
    self.biome = params.biome
    local biomeDef = Biome.get(params.biome)
    self.spacing = params.spacing or biomeDef.spacing or 4
    self.originX = 0
    self.originY = 0
    self.rng = love.math.newRandomGenerator(params.seed or os.time())
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
    self:braid(params.braid or 0.4)
    local riverSpec = params.riverCount
    if riverSpec == nil then riverSpec = biomeDef.rivers end
    self:placeRivers(resolveCount(riverSpec, self.rng))
    self:decorate()
    self:placeObjectiveAndGates(params)
    self:placeEncounters(params)

    return self
end

function Overworld:inBounds(x, y)
    return x >= 1 and y >= 1 and x <= self.cols and y <= self.rows
end

local function isNode(self, x, y)
    return self:inBounds(x, y)
        and (x - 1) % self.spacing == 0 and (y - 1) % self.spacing == 0
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
    local sx, sy = 1, 1
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
    for y = 1, self.rows, S do
        for x = 1, self.cols, S do
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

-- One continuous river laid across the whole map (edge to edge), gently
-- meandering. Each vertical/horizontal step also marks the corner tile so the
-- water stays orthogonally connected (no diagonal gaps). A river tile over a
-- path becomes a walkable bridge so trail connectivity is preserved; over
-- anything else it blocks.
function Overworld:placeRivers(count)
    for _ = 1, count do
        if self.rng:random() < 0.5 then
            local y = self.rng:random(3, self.rows - 2)
            for x = 1, self.cols do
                self:markRiver(x, y)
                if self.rng:random() < 0.25 then
                    local ny = y + (self.rng:random() < 0.5 and -1 or 1)
                    if ny >= 2 and ny <= self.rows - 1 then
                        self:markRiver(x, ny) -- corner fill keeps the water connected
                        y = ny
                    end
                end
            end
        else
            local x = self.rng:random(3, self.cols - 2)
            for y = 1, self.rows do
                self:markRiver(x, y)
                if self.rng:random() < 0.25 then
                    local nx = x + (self.rng:random() < 0.5 and -1 or 1)
                    if nx >= 2 and nx <= self.cols - 1 then
                        self:markRiver(nx, y) -- corner fill keeps the water connected
                        x = nx
                    end
                end
            end
        end
    end
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
        if c and typeWalkable(c.tile) then res[#res + 1] = c end
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
            if typeWalkable(c.tile) then
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

    -- Prefer the farthest dead-end (degree 1) so gating its corridor truly locks
    -- the objective; fall back to the plain farthest tile.
    local objective, objd, deadObj, deadd
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            local d = dist[cellKey(c)]
            if typeWalkable(c.tile) and d then
                if not objd or d > objd then objd = d; objective = c end
                if c ~= start and #self:pathNeighbors(x, y) == 1 then
                    if not deadd or d > deadd then deadd = d; deadObj = c end
                end
            end
        end
    end
    objective = deadObj or objective
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
            if typeWalkable(c.tile) and d and d < firstGateDist
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
    local count = resolveCount(params.encounterCount, self.rng)
    local pool = params.encounters or { { kind = "combat", weight = 1 } }
    local always = params.alwaysEncounters or {}

    local cands = {}
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            if typeWalkable(c.tile) and not c.encounter and not c.gate and not c.key
                and not (self.start.x == x and self.start.y == y) then
                cands[#cands + 1] = c
            end
        end
    end

    for i = #cands, 2, -1 do
        local j = self.rng:random(i)
        cands[i], cands[j] = cands[j], cands[i]
    end

    local placed = {}
    local next_ = 1

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

function Overworld:startCell() return self:get(self.start.x, self.start.y) end
function Overworld:objectiveCell() return self:get(self.objective.x, self.objective.y) end

-- Walkable for an actor holding `keysHeld` (a set of keyId -> true). A gate is
-- passable only with its matching key.
function Overworld:isWalkable(x, y, keysHeld)
    local c = self:get(x, y)
    if not c then return false end
    if not typeWalkable(c.tile) then return false end
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
