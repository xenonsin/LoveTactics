-- Battle arena logic. When the player engages a combat encounter on the overworld
-- they drop into an 8x8 arena: the party occupies tiles on the near side, enemies
-- on the far side. This module is pure logic (no love.graphics; only love.math for a
-- seeded RNG) so it loads under the headless tests, mirroring models/overworld.lua.
--
-- A *layout* is the reusable part of an arena: tile types + spawn positions, with no
-- specific units bound yet. Both procedural generation (`generateLayout`) and curated
-- files (data/arenas/<id>.lua) produce a layout; `populate` binds party/enemy ids onto
-- its spawn points. The debug save (`serialize`/`save`) writes an arena back out as a
-- curated layout file, so a procedurally generated map can be captured and hand-edited
-- toward a curated pool.
--
--   local arena = Arena.build(
--       { prestige = 2, biome = "forest", quest = q },     -- ctx for composition()
--       { biome = "forest", party = { "character_knight", "character_mage" },  -- spec
--         composition = function(ctx) return { "character_wolf_grunt" } end,
--         objective = { type = "killAll" }, seed = 123 })
--   -- arena = { cols, rows, tileSize, biome, tiles[y][x]={type,moveCost,walkable},
--   --           party={{id,x,y}}, enemies={{id,x,y}}, objective, seed }

local Registry = require("models.registry")

local Arena = {}

Arena.COLS = 8
Arena.ROWS = 8
Arena.TILE_SIZE = 64 -- logical pixels per cell (8*64 = 512, centered in 1280x720)

-- Arena tile palette. Deliberately small; "special properties" (hazards, cover,
-- bonuses) are fleshed out with the turn system. Distinct from models/tileset.lua's
-- overworld TYPES, but the renderer still pulls *art* from the biome's tileset.
--   * moveCost  -- terrain-weighted enter cost (Dijkstra reach + timeline; see models/combat.lua)
--   * walkable  -- may a unit occupy the tile at all
--   * sightCost -- how much this tile obstructs a line of sight that passes THROUGH it. Combat
--     sums it over the tiles between shooter and target; a line is blocked once the sum reaches
--     Combat.SIGHT_BLOCK. 0 = transparent, forest (1) is soft cover that only LOWERS sight (two
--     stacked block), mountain/obstacle carry enough to block a shot on their own.
--   * bonus     -- optional positional modifiers granted to a unit STANDING on the tile, e.g.
--     { range = 1 } for high ground. Combat aggregates these (with any placed field objects) via
--     Combat.fieldBonus; a generic bag so future tiles/objects can grant other buffs the same way.
--   * tags      -- what the GROUND here is made of, for effects that ask a tile a question rather
--     than name a terrain type: "burnable" (fire creeps in -- Hazard.spread), "conductable" (lightning
--     arcs in -- Combat.conductLightning). A hazard on the tile or a status on whoever stands there
--     can carry the same tags, and Combat.tileHasTag answers across all three -- so a Rain cloud, a
--     Wet unit and a river are one thing to a lightning bolt. Add a tag, not a branch.
Arena.TILE_PROPS = {
    ground   = { moveCost = 1, walkable = true,  sightCost = 0 },  -- open field
    forest   = { moveCost = 2, walkable = true,  sightCost = 1, tags = { "burnable" } }, -- slow; soft cover; catches fire
    -- A ford / shallow pool: wadeable but slow, and it carries a charge to whatever stands in it.
    water    = { moveCost = 2, walkable = true,  sightCost = 0, tags = { "conductable" } },
    -- Steep high ground: blocks the view behind it, but a unit atop it sees + strikes one tile further.
    mountain = { moveCost = 3, walkable = true,  sightCost = 2, bonus = { range = 1 } },
    rough    = { moveCost = 2, walkable = true,  sightCost = 0 },  -- legacy penalty tile (curated arenas)
    obstacle = { moveCost = math.huge, walkable = false, sightCost = math.huge }, -- solid: blocks tile + sight
}

-- Default objective when an encounter/quest doesn't specify one.
local DEFAULT_OBJECTIVE = { type = "killAll" }

-- Curated arenas: data/arenas/<id>.lua, each a layout tagged with `biome`.
Arena.defs = Registry.load("data/arenas", "data.arenas")

-- ---------------------------------------------------------------------------
-- Composition & objective resolution
-- ---------------------------------------------------------------------------

-- Resolve an encounter's `composition` (a function(ctx) or a plain id list) to a
-- flat list of character ids. A nil composition falls back to a single generic foe.
function Arena.resolveComposition(composition, ctx)
    if type(composition) == "function" then
        return composition(ctx or {}) or {}
    elseif type(composition) == "table" then
        return composition
    end
    return { "character_bandit" }
end

-- Is (x, y) ground a unit can stand on? Reads the layout's type strings through TILE_PROPS,
-- which is the same table hydrateTiles expands -- so a region can never hand out a tile that
-- an objective is then unable to be satisfied on.
local function walkableAt(layout, x, y)
    if x < 1 or y < 1 or x > layout.cols or y > layout.rows then return false end
    local t = (layout.tiles[y] and layout.tiles[y][x]) or "ground"
    local props = Arena.TILE_PROPS[t] or Arena.TILE_PROPS.ground
    return props.walkable
end

-- Objective REGIONS: a symbolic patch of ground an objective is pointed at, resolved against
-- the board once it exists.
--
-- This indirection is the whole reason `reach` and `hold` can be used by an ordinary quest. Quest
-- boards are GENERATED per run (Arena.generateLayout, off the quest's biome and a seed), so a
-- blueprint cannot name coordinates -- there is no board yet when it is written, and the one it
-- gets will be different next time. It names a SHAPE instead, and the arena finds it.
--
-- A curated arena that does know its own geometry can skip all of this and author
-- `win = { type = "reach", tiles = { { x = 3, y = 1 } } }` outright; an explicit `tiles` list is
-- never overwritten.
Arena.OBJECTIVE_REGIONS = {
    -- The far edge -- the side of the board the party did not land on. What crossing means.
    far = function(layout)
        local sum, n = 0, 0
        for _, s in ipairs(layout.partySpawns or {}) do sum, n = sum + s.y, n + 1 end
        -- Measured off the party's own spawns rather than hardcoding a row, so the region is
        -- still correct if a curated arena seats the party at the top instead of the bottom.
        local avg = (n > 0) and (sum / n) or layout.rows
        local goalY = (avg > layout.rows / 2) and 1 or layout.rows
        local tiles = {}
        for x = 1, layout.cols do
            if walkableAt(layout, x, goalY) then tiles[#tiles + 1] = { x = x, y = goalY } end
        end
        return tiles
    end,
    -- The middle ground: the 2x2 at the board's heart, which is the ground two lines meet over.
    center = function(layout)
        local cx, cy = math.floor(layout.cols / 2), math.floor(layout.rows / 2)
        local tiles = {}
        for y = cy, cy + 1 do
            for x = cx, cx + 1 do
                if walkableAt(layout, x, y) then tiles[#tiles + 1] = { x = x, y = y } end
            end
        end
        return tiles
    end,
    -- Just ahead of the party's own line -- the row two steps toward mid-board from where the party
    -- lands. A protected unit anchored here stands close enough for the party to interpose on turn 1
    -- (unlike `center`, which the enemy reaches first). Measured off the party's spawns like `far`, so
    -- it still points inward if a curated map seats the party at the top instead of the bottom.
    rally = function(layout)
        local sum, n = 0, 0
        for _, s in ipairs(layout.partySpawns or {}) do sum, n = sum + s.y, n + 1 end
        local avg = (n > 0) and (sum / n) or layout.rows
        local dir = (avg > layout.rows / 2) and -1 or 1 -- step toward the center
        local goalY = math.max(1, math.min(layout.rows, math.floor(avg + dir * 2 + 0.5)))
        local tiles = {}
        for x = 1, layout.cols do
            if walkableAt(layout, x, goalY) then tiles[#tiles + 1] = { x = x, y = goalY } end
        end
        return tiles
    end,
}

-- Resolve a region name to concrete tiles, widening the search if the board's scatter happened
-- to bury the whole patch under obstacles. An objective with no reachable tile is unwinnable, and
-- a generated board is allowed to be unlucky -- so this never returns empty while ANY walkable
-- tile exists.
function Arena.resolveRegion(name, layout)
    local region = Arena.OBJECTIVE_REGIONS[name] or Arena.OBJECTIVE_REGIONS.center
    local tiles = region(layout)
    if #tiles > 0 then return tiles end

    for y = 1, layout.rows do
        for x = 1, layout.cols do
            if walkableAt(layout, x, y) then return { { x = x, y = y } } end
        end
    end
    return {}
end

-- Copy the objective and, for the tile-based win types, stamp the ground onto it. Copied rather
-- than mutated: `spec.objective` comes straight off an immutable quest blueprint, and writing
-- resolved tiles into it would leak one run's board into the next (tests/quest_spec.lua pins that).
local function normalizeObjective(obj, layout)
    if not obj or not obj.type then return { type = DEFAULT_OBJECTIVE.type } end

    local out = {}
    for k, v in pairs(obj) do out[k] = v end
    if (out.type == "reach" or out.type == "hold") and not out.tiles then
        out.tiles = Arena.resolveRegion(out.region or (out.type == "reach" and "far" or "center"), layout)
    end
    -- A `defend` objective is anchored to a region too (where the protected unit stands), so the HUD
    -- can mark that ground and an enemy's `objectiveTile` has a handle to path toward.
    if out.type == "defend" and not out.tiles then
        out.tiles = Arena.resolveRegion(out.anchor or "center", layout)
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Layouts
-- ---------------------------------------------------------------------------

local function key(x, y) return x .. "," .. y end

-- Place `count` units spread evenly across the given rows (near rows for party, far
-- rows for enemies). Deterministic; fills row by row, nudging around collisions.
local function placeUnits(rowList, count, cols, occupied)
    local spawns = {}
    local placed = 0
    for _, ry in ipairs(rowList) do
        if placed >= count then break end
        local n = math.min(count - placed, cols)
        for i = 1, n do
            local x = math.floor(i * (cols + 1) / (n + 1) + 0.5)
            x = math.max(1, math.min(cols, x))
            while occupied[key(x, ry)] do x = (x % cols) + 1 end
            occupied[key(x, ry)] = true
            placed = placed + 1
            spawns[placed] = { x = x, y = ry }
        end
    end
    return spawns
end

-- A deliberately fresh seed, for a caller that wants a board it has never seen. The one place the
-- clock is allowed to pick, so "this arena came from nowhere" is a greppable decision rather than
-- something that happens by omission.
function Arena.randomSeed()
    return os.time() + math.floor(((love.timer and love.timer.getTime()) or 0) * 1000) % 100000
end

-- Every generated board has to be reproducible from a seed its caller chose: a bug report replays,
-- and two machines building the same fight from the same number get the same ground underfoot. A
-- clock fallback here would hand back a board that looks perfectly correct and cannot be produced
-- again -- the failure that hides longest -- so a missing seed is a programming error, not a roll.
local function requireSeed(seed, who)
    if not seed then
        error(who .. " needs a seed; pass one through the spec, or Arena.randomSeed() if a"
            .. " board nobody has seen is actually what you want", 3)
    end
    return seed
end

-- Procedurally generate a layout: all `ground`, with a few `forest`/`mountain`/`obstacle`
-- tiles scattered across the middle rows (never on a spawn tile). Deterministic off
-- `params.seed` (required -- see requireSeed). `params.party` / `params.enemies` are unit *counts*.
function Arena.generateLayout(params)
    params = params or {}
    local cols, rows = Arena.COLS, Arena.ROWS
    local rng = love.math.newRandomGenerator(requireSeed(params.seed, "Arena.generateLayout"))

    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do tiles[y][x] = "ground" end
    end

    local occupied = {}
    local partySpawns = placeUnits({ rows, rows - 1 }, params.party or 0, cols, occupied)
    local enemySpawns = placeUnits({ 1, 2 }, params.enemies or 0, cols, occupied)

    -- Scatter terrain only on the neutral middle band so it never walls off a side.
    local function scatter(kind, n)
        local tries = 0
        while n > 0 and tries < 100 do
            tries = tries + 1
            local x, y = rng:random(1, cols), rng:random(3, rows - 2)
            if tiles[y][x] == "ground" and not occupied[key(x, y)] then
                tiles[y][x] = kind
                occupied[key(x, y)] = true
                n = n - 1
            end
        end
    end
    scatter("forest", rng:random(2, 5))
    scatter("mountain", rng:random(1, 3))
    scatter("obstacle", rng:random(1, 3))

    return {
        cols = cols, rows = rows, tiles = tiles,
        partySpawns = partySpawns, enemySpawns = enemySpawns,
        biome = params.biome, seed = params.seed,
    }
end

-- Curated arena files store tiles as plain type strings; ensure they carry the full
-- cols/rows/spawn shape a layout needs (tolerating a hand-edited file).
local function hydrateLayout(def)
    return {
        cols = def.cols or (def.tiles and #def.tiles[1]) or Arena.COLS,
        rows = def.rows or (def.tiles and #def.tiles) or Arena.ROWS,
        tiles = def.tiles,
        partySpawns = def.partySpawns or {},
        enemySpawns = def.enemySpawns or {},
        traps = def.traps or {}, -- authored traps: { { id, x, y, side }, ... }
        biome = def.biome,
    }
end

-- Choose a layout for this build. Procedural generation and every curated arena
-- tagged for the biome share one random pool: the pick is uniform over
-- { procedural, curated_1, ... }, so curated maps are mixed in rather than always
-- preferred, and a fresh procedural map stays a live outcome. Deterministic off the
-- seed (curated entries are sorted by id so the pick is stable across runs).
--
-- Two escapes from the pool, for a fight authored against a specific board (the prologue's
-- tutorial): `spec.layout` names one outright, and a layout marked `fixed` is excluded from the
-- random pool -- otherwise dropping a scripted map into data/arenas/ would make ordinary fights of
-- its biome roll it, and its authored coordinates mean nothing outside the scene that wrote them.
function Arena.pickLayout(spec, partyCount, enemyCount)
    local forced = spec.layout and Arena.defs[spec.layout]
    if forced then return hydrateLayout(forced) end

    local rng = love.math.newRandomGenerator(requireSeed(spec.seed, "Arena.pickLayout"))

    local curated = {}
    for id, def in pairs(Arena.defs) do
        if def.biome == spec.biome and not def.fixed then
            curated[#curated + 1] = { id = id, def = def }
        end
    end
    table.sort(curated, function(a, b) return a.id < b.id end)

    -- Index 0 is the procedural slot; 1..#curated select a curated arena.
    local pick = rng:random(0, #curated)
    if pick == 0 then
        return Arena.generateLayout({
            biome = spec.biome, seed = spec.seed,
            party = partyCount, enemies = enemyCount,
        })
    end
    return hydrateLayout(curated[pick].def)
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------

-- Expand a layout's type-string tiles into { type, moveCost, walkable } cells.
local function hydrateTiles(layout)
    local tiles = {}
    for y = 1, layout.rows do
        tiles[y] = {}
        for x = 1, layout.cols do
            local t = (layout.tiles[y] and layout.tiles[y][x]) or "ground"
            local p = Arena.TILE_PROPS[t] or Arena.TILE_PROPS.ground
            tiles[y][x] = { type = t, moveCost = p.moveCost, walkable = p.walkable,
                            sightCost = p.sightCost or 0, bonus = p.bonus, tags = p.tags }
        end
    end
    return tiles
end

-- Bind unit id lists onto a layout's spawn points (zipping to the shorter length).
-- `offset` skips spawn points already claimed by an earlier bind.
local function bindUnits(ids, spawns, offset)
    offset = offset or 0
    local units = {}
    for i, id in ipairs(ids) do
        local sp = spawns[i + offset]
        if not sp then break end
        units[i] = { id = id, x = sp.x, y = sp.y }
    end
    return units
end

-- Seat the party's escort/allies. Normally they claim party spawn points after the party itself.
-- But an objective may ANCHOR the thing it protects to a region of the board -- "defend the
-- survivors in the middle" -- in which case every ally matching `objective.protect` is placed on the
-- resolved region (mid-map) and the rest fall back to party spawns. This is the seam that lets a
-- defended unit (or an inert "object") stand somewhere other than beside the party.
local function bindAllies(allyIds, spec, layout)
    local party = spec.party or {}
    local obj = spec.objective
    local anchor = obj and obj.anchor
    local protectId = obj and obj.protect
    if not (anchor and protectId) then
        return bindUnits(allyIds, layout.partySpawns, #party)
    end

    -- Region tiles that no unit already stands on, so an anchored survivor never shares a cell.
    local taken = {}
    for i = 1, #party do
        local sp = layout.partySpawns[i]
        if sp then taken[key(sp.x, sp.y)] = true end
    end
    local anchorTiles = {}
    for _, t in ipairs(Arena.resolveRegion(anchor, layout)) do
        if not taken[key(t.x, t.y)] then anchorTiles[#anchorTiles + 1] = t end
    end

    local units, anchored, rest = {}, 0, 0
    for _, id in ipairs(allyIds) do
        if id == protectId and anchorTiles[anchored + 1] then
            anchored = anchored + 1
            local t = anchorTiles[anchored]
            units[#units + 1] = { id = id, x = t.x, y = t.y }
        else
            rest = rest + 1
            local sp = layout.partySpawns[#party + rest]
            if sp then units[#units + 1] = { id = id, x = sp.x, y = sp.y } end
        end
    end
    return units
end

-- Build a fully populated arena from a context + spec. See the module header for the
-- spec shape. Deterministic when `spec.seed` is set.
--
-- `spec.allies` names non-party characters that fight on the party's side under AI control
-- (an escorted caravan, a herd to defend). They claim party spawn points after the party
-- itself, and are what a `protect` objective is usually pointed at.
function Arena.build(ctx, spec)
    spec = spec or {}
    local partyIds = spec.party or {}
    local allyIds = Arena.resolveComposition(spec.allies, ctx)
    if not spec.allies then allyIds = {} end -- resolveComposition defaults to a bandit; allies default to none
    local enemyIds = Arena.resolveComposition(spec.composition, ctx)

    local layout = Arena.pickLayout(spec, #partyIds + #allyIds, #enemyIds)

    -- A curated layout may not have authored enough party spawns for the party *and* its
    -- escort. Dropping the escortee would instantly fail a `protect` objective, so fall
    -- back to a procedural layout sized for everyone. Only escort builds can trip this.
    if #allyIds > 0 and #layout.partySpawns < #partyIds + #allyIds then
        layout = Arena.generateLayout({
            biome = spec.biome, seed = spec.seed,
            party = #partyIds + #allyIds, enemies = #enemyIds,
        })
    end

    return {
        cols = layout.cols, rows = layout.rows,
        tileSize = Arena.TILE_SIZE,
        biome = spec.biome or layout.biome,
        tiles = hydrateTiles(layout),
        party = bindUnits(partyIds, layout.partySpawns),
        allies = bindAllies(allyIds, spec, layout),
        enemies = bindUnits(enemyIds, layout.enemySpawns),
        traps = layout.traps or {}, -- authored traps carried into combat (side defaults to enemy)
        objective = normalizeObjective(spec.objective, layout),
        -- The seed the caller chose, not whatever the layout happened to record: it is what the
        -- battle's own draw sequence is built from (Combat.new), so it has to be the authoritative
        -- number even when a curated layout was picked and generated nothing.
        seed = spec.seed or layout.seed,
    }
end

-- ---------------------------------------------------------------------------
-- Debug save / serialize
-- ---------------------------------------------------------------------------

-- Serialize an arena back to a curated-layout Lua source string: tile *types* plus
-- party/enemy spawn positions (unit ids are dropped -- they come from the encounter's
-- composition at load time). The result is a valid data/arenas/<id>.lua file.
function Arena.serialize(arena)
    local out = { "return {\n" }
    out[#out + 1] = string.format("    biome = %q,\n", arena.biome or "forest")

    out[#out + 1] = "    tiles = {\n"
    for y = 1, arena.rows do
        local row = {}
        for x = 1, arena.cols do
            row[x] = string.format("%q", arena.tiles[y][x].type)
        end
        out[#out + 1] = "        { " .. table.concat(row, ", ") .. " },\n"
    end
    out[#out + 1] = "    },\n"

    local function spawnBlock(name, units)
        out[#out + 1] = "    " .. name .. " = {\n"
        for _, u in ipairs(units) do
            out[#out + 1] = string.format("        { x = %d, y = %d },\n", u.x, u.y)
        end
        out[#out + 1] = "    },\n"
    end
    spawnBlock("partySpawns", arena.party)
    spawnBlock("enemySpawns", arena.enemies)

    -- Authored traps, if any: { id, x, y, side }. Omitted entirely when the arena has none.
    if arena.traps and #arena.traps > 0 then
        out[#out + 1] = "    traps = {\n"
        for _, t in ipairs(arena.traps) do
            out[#out + 1] = string.format("        { id = %q, x = %d, y = %d, side = %q },\n",
                t.id, t.x, t.y, t.side or "enemy")
        end
        out[#out + 1] = "    },\n"
    end

    out[#out + 1] = "}\n"
    return table.concat(out)
end

-- Dev-only: write the arena to data/arenas/<name>.lua in the *project source tree* so
-- it can be hand-edited and committed. Uses a raw io.open on the source path, which
-- only works when running unfused from source (i.e. `love .`); a no-op (with a warning)
-- otherwise. love.filesystem.write can't reach the source tree, only the save dir.
function Arena.save(arena, name)
    if not (love and love.filesystem and love.filesystem.getSource) then
        print("Arena.save: love.filesystem unavailable")
        return false
    end
    local path = love.filesystem.getSource() .. "/data/arenas/" .. name .. ".lua"
    local f = io.open(path, "w")
    if not f then
        print("Arena.save: could not open " .. path .. " (dev-only; run unfused from source)")
        return false
    end
    f:write(Arena.serialize(arena))
    f:close()
    print("Arena.save: wrote " .. path)
    return true
end

return Arena
