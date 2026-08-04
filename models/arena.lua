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
--       { biome = "forest", party = { "character_rowan", "character_mage" },  -- spec
--         composition = function(ctx) return { "character_wolf_grunt" } end,
--         objective = { type = "killAll" }, seed = 123 })
--   -- arena = { cols, rows, tileSize, biome, tiles[y][x]={type,moveCost,walkable},
--   --           party={{id,x,y}}, enemies={{id,x,y}}, deployZone={{x,y}}, objective, seed }
--
-- `party` is where the board WOULD seat the company, and on most fights it is only the opening
-- suggestion: the player picks who stands where in the deployment phase, over `deployZone`. See
-- deployZoneFor below and docs/deployment.md.

local Registry = require("models.registry")
local Prop = require("models.prop")
local Biome = require("models.biome") -- signature ground a generated board seeds (Biome.hazardFor)

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

    -- The biome floors below are each the deliberate INVERSE of one above, so a board built on them
    -- plays differently rather than merely looking different. None of them grants cover: every one is
    -- sightCost 0, because the thing that makes a strange floor interesting is what it does to feet
    -- and to reach, not what it hides behind.

    -- Loose sand: heavy going with nothing to stand behind -- forest's cost without forest's cover, so
    -- a desert board is a long ranged exchange nobody can cross quickly or safely.
    sand     = { moveCost = 2, walkable = true,  sightCost = 0 },
    -- Frozen ground: the ONLY terrain feature that does not tax a step. Every other floor here costs
    -- more than open field; ice costs exactly the same, so a board scattered with it is a board with no
    -- movement obstacles at all. What it charges instead is conduction -- a lightning line that would
    -- clip one body on grass sweeps a whole frozen front. Free to cross, expensive to stand on.
    ice      = { moveCost = 1, walkable = true,  sightCost = 0, tags = { "conductable" } },
    -- A lava flow: impassable, but UNLIKE an obstacle it does not block a line of sight. A wall you can
    -- shoot straight over and never cross -- the one barrier that separates two lines without also
    -- hiding them from each other.
    lava     = { moveCost = math.huge, walkable = false, sightCost = 0 },
    -- Sucking bog: it ties the mountain for the heaviest walkable floor and gives back nothing at all --
    -- no reach, no cover, no sight. The strictly-worse-than-high-ground tile, which is a real thing for
    -- a floor to be: it makes crossing expensive without ever being worth holding. Wet through, so it
    -- conducts.
    mire     = { moveCost = 3, walkable = true,  sightCost = 0, tags = { "conductable" } },
}

-- What a generated board scatters for a given biome. `Arena.generateLayout` makes exactly three
-- scatter calls (a fill, a rise, a blocker) and this only chooses WHICH tile each one lays down -- the
-- counts still come from the same rng draws in the same order, so every previously generated board
-- reproduces from its seed unchanged. A biome absent here falls back to the original three.
Arena.BIOME_TERRAIN = {
    default  = { fill = "forest", rise = "mountain", block = "obstacle" },
    desert   = { fill = "sand",   rise = "mountain", block = "obstacle" },
    tundra   = { fill = "ice",    rise = "mountain", block = "obstacle" },
    volcanic = { fill = "rough",  rise = "mountain", block = "lava" },
    swamp    = { fill = "mire",   rise = "forest",   block = "obstacle" },
}

-- The terrain palette for `biome`, always a complete table (see Arena.BIOME_TERRAIN).
function Arena.terrainFor(biome)
    return Arena.BIOME_TERRAIN[biome or "default"] or Arena.BIOME_TERRAIN.default
end

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

-- ---------------------------------------------------------------------------
-- The enemy ceiling
-- ---------------------------------------------------------------------------

-- The most bodies a fight may OPEN with, by the quest's authored difficulty.
--
-- Every objective in the game sizes its own enemy list with a formula off the player's prestige --
-- `2 + math.floor((ctx.prestige or 1) / 2)` and its neighbours, across 91 quest files -- and nothing
-- bounded the result. Prestige is a lifetime total that never resets and that New Game+ carries
-- forward (Player.newGamePlus), so the input grows without limit: the `/2` quests reach 71 bodies by
-- the campaign's ~138 prestige and 140 in a second run. That is not a difficulty curve, it is an
-- unbounded one that happens to start in the right place.
--
-- The head-count was the wrong axis to have reached for anyway, twice over. Enemies ALREADY scale --
-- Growth.ENEMY_LEVEL_LAG holds ordinary stock at 0.9x the player's level, so the fight keeps its edge
-- without another body being added -- and adding bodies is SUPER-linear difficulty besides, because
-- action economy compounds: four units against seventy eat seventy attacks a round and land four.
--
-- So the ceiling is small and flat. What a quest is allowed to grow is which enemies it fields and how
-- deep they are, not how many stand there.
Arena.ENEMY_CAP = { Easy = 6, Normal = 9, Hard = 12 }
Arena.DEFAULT_ENEMY_CAP = 9 -- an encounter with no quest behind it (a roadside fight) reads as Normal

function Arena.enemyCap(ctx)
    local quest = ctx and ctx.quest
    return (quest and Arena.ENEMY_CAP[quest.difficulty]) or Arena.DEFAULT_ENEMY_CAP
end

-- Cut `ids` down to `cap`, keeping the NAMED CAST first: one of every distinct id, in authored order,
-- before any repeated filler.
--
-- Preserving the named cast is a WINNABILITY rule, not a nicety. 43 quests win by
-- `type = "assassinate", target = "character_bandit_chief"`, and others name a `protect` ally; drop the
-- target and the objective cannot be completed at all -- a softlock, not a harder fight. Every
-- composition in the game happens to list its named unit first today, so a naive tail-truncation would
-- survive by luck; this makes it survive by construction, which is what the 93rd quest will need.
--
-- When the DISTINCT ids alone exceed the cap, the cap yields. An author who lists fourteen individually
-- named characters has made a deliberate choice about one fight; the ceiling exists to stop a prestige
-- FORMULA running away, and it should not silently overrule a hand-written cast list.
function Arena.clampComposition(ids, cap)
    ids = ids or {}
    if not cap or #ids <= cap then return ids end

    local kept, seenId, usedIndex = {}, {}, {}
    for i, id in ipairs(ids) do
        if not seenId[id] then
            seenId[id] = true
            usedIndex[i] = true
            kept[#kept + 1] = id
        end
    end
    -- The named cast is in; top up to the cap from the filler, in the order it was authored.
    for i, id in ipairs(ids) do
        if #kept >= cap then break end
        if not usedIndex[i] then kept[#kept + 1] = id end
    end
    return kept
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

-- How often (in ticks) a reach fight's synthesized endless reinforcement tops the board back up, and
-- how the trickle relates to the opening line (Arena.reachWaveFrom). A road you have to WALK across
-- can't be won by clearing the field, so fresh enemies keep coming until the escort actually arrives.
Arena.REACH_WAVE_PERIOD = 12

-- Build the endless reinforcement a reach objective fights against, drawn from the SAME roster the
-- opening line came from (`enemyIds`) so a demon road refills with demons and a forsworn ruin with
-- forsworn -- no per-encounter authoring, no hardcoded ids. `maxAlive` holds the recurrence at the
-- opening strength (it tops up toward that count rather than piling on), and the trickle is half the
-- opening line, rounded up, walking in from all sides so it threatens the column's flanks, not just
-- its front. Returns nil when there is no roster to draw from (nothing to reinforce with).
local function reachWave(enemyIds)
    if not enemyIds or #enemyIds == 0 then return nil end
    local trickle = {}
    for i = 1, math.max(1, math.ceil(#enemyIds / 2)) do trickle[i] = enemyIds[i] end
    return { every = Arena.REACH_WAVE_PERIOD, composition = trickle,
             from = "surround", maxAlive = #enemyIds }
end

-- Copy the objective and, for the tile-based win types, stamp the ground onto it. Copied rather
-- than mutated: `spec.objective` comes straight off an immutable quest blueprint, and writing
-- resolved tiles into it would leak one run's board into the next (tests/quest_spec.lua pins that).
-- `enemyIds` is the resolved opening composition, the roster a synthesized reach wave draws from.
local function normalizeObjective(obj, layout, enemyIds)
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
    -- A reach fight gets endless reinforcements unless it authored its own waves: crossing has to
    -- stay a race under pressure, never a stroll across a board you already emptied.
    if out.type == "reach" and not out.waves then
        local wave = reachWave(enemyIds)
        if wave then out.waves = { wave } end
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

-- The board cell a marching-grid slot maps to. Grid ROW 1 is the FRONT line -- it "faces the enemy"
-- (states/party_select.lua), and the enemy holds the FAR edge (low y) while the party lands on the near
-- rows -- so the front rank must sit one row TOWARD the enemy from the party's home edge, not on it:
-- front (row 1) -> rows-frows+1, back (row frows) -> rows (the home edge). Deeper grid rows step BACK
-- toward that edge. Grid columns spread across the full board width with the SAME even spacing
-- placeUnits uses. See models/player.lua for the grid the player edits.
local function formationCell(slot, fcols, frows, cols, rows)
    local x = math.floor(slot.col * (cols + 1) / (fcols + 1) + 0.5)
    x = math.max(1, math.min(cols, x))
    local y = math.max(1, math.min(rows, rows - frows + slot.row))
    return x, y
end

-- Seat a party by a marching grid (draft mode's -- see reseatByFormation). `slots` is a list ordered to
-- MATCH the party (entry i is member i's { col, row } grid cell, or nil for a member left unplaced), so
-- the spawns come back in the same order and Arena.build's bindUnits seats each member on their chosen
-- tile. A placed member takes its mapped board cell, nudged to the nearest free tile on a clash (a stale
-- slot from a differently-sized grid can otherwise collide); the unplaced remainder auto-spreads across
-- the near rows into whatever the placed members left free, so a half-arranged grid still seats everyone.
local function placePartyFormation(slots, fcols, frows, count, cols, rows, occupied, walkable)
    walkable = walkable or function() return true end
    local spawns = {}
    local unplaced = {}
    for i = 1, count do
        local slot = slots[i]
        if slot then
            local x, y = formationCell(slot, fcols, frows, cols, rows)
            -- On a clash OR an unwalkable tile, step along the near row and then to the back near row
            -- until a free walkable tile turns up: two members mapping to one cell never share it, and a
            -- curated board's near-row wall (a colosseum shoulder pillar) never buries a member.
            local guard = 0
            while (occupied[key(x, y)] or not walkable(x, y)) and guard < cols * 2 do
                guard = guard + 1
                x = (x % cols) + 1
                if x == 1 then y = (y == rows) and (rows - 1) or rows end
            end
            occupied[key(x, y)] = true
            spawns[i] = { x = x, y = y }
        else
            unplaced[#unplaced + 1] = i
        end
    end
    -- Everyone without a grid cell falls back to the even auto-spread, over the tiles the formation
    -- left open (placeUnits skips occupied cells).
    local filler = placeUnits({ rows, rows - 1 }, #unplaced, cols, occupied)
    for j, idx in ipairs(unplaced) do
        spawns[idx] = filler[j] or { x = 1, y = rows }
    end
    return spawns
end

-- Seat a party by a pre-resolved marching grid over a CURATED board's authored spawns -- the same grid
-- generateLayout honors on a procedural map, applied to hand-authored tiles (so the board's own near-row
-- walls get nudged around). Reseats in place; returns nothing.
--
-- The campaign no longer brings a marching grid at all: it decides placement per battle in the
-- deployment phase (docs/deployment.md). The one caller left is DRAFT mode, which keeps its own 4x2
-- formation in the shop UI (models/draft_run.lua) and passes it through as pre-resolved slots. Skipped
-- when the fight carries AI allies, whose seating is the authored board's job (bindAllies), not the grid's.
local function reseatByFormation(layout, formation, fcols, frows, partyCount)
    if not formation then return end
    local placed = false
    for i = 1, partyCount do if formation[i] then placed = true break end end
    if not placed then return end
    local function walkable(x, y) return walkableAt(layout, x, y) end
    layout.partySpawns = placePartyFormation(formation, fcols or 4, frows or 2, partyCount,
        layout.cols, layout.rows, {}, walkable)
end

-- The DEPLOY ZONE: the tiles the player may put a body on at the opening bell (states/battle.lua's
-- deployment phase), and the same ground a rotation and a reinforcement use later in the fight
-- (models/combat.lua). See docs/deployment.md.
--
-- It is deliberately WIDER than the party -- placement is only a decision if there are more tiles than
-- units -- and it is derived from the board rather than authored, so every map gets one for free:
--
--   1. an authored `deployZone` on a curated layout wins outright (a map that wants to say "you come in
--      through this gate" says so);
--   2. otherwise, every walkable tile on the ROWS THE PARTY SPAWNS OCCUPY, widened by one row TOWARD the
--      enemy. The spawn rows keep the zone where the board's author (or the generator) already decided
--      the party enters from; the extra row is what makes it a band rather than a line, so front-and-back
--      is a decision and not just left-and-right. See Arena.DEPLOY_DEPTH;
--   3. tiles another unit is authored onto (an escort, an enemy that spawned deep) are excluded, so the
--      phase can never offer a cell somebody is already standing in.
--
-- Falls back to the party spawns themselves if that yields fewer than `minTiles` cells: a cramped
-- authored board must never produce a phase with nowhere to stand.

-- How many rows deep the derived zone is, counting the party's own spawn row. Two: one to stand the line
-- on and one to stand behind it, which is exactly the front/back choice the old marching grid offered.
Arena.DEPLOY_DEPTH = 2

local function deployZoneFor(layout, taken, minTiles)
    local authored = layout.deployZone
    local zone = {}
    if authored and #authored > 0 then
        for _, t in ipairs(authored) do
            if walkableAt(layout, t.x, t.y) and not taken[key(t.x, t.y)] then
                zone[#zone + 1] = { x = t.x, y = t.y }
            end
        end
    else
        local rows, lo, hi = {}, nil, nil
        for _, sp in ipairs(layout.partySpawns or {}) do
            rows[sp.y] = true
            lo = math.min(lo or sp.y, sp.y)
            hi = math.max(hi or sp.y, sp.y)
        end
        -- Widen toward the enemy: the party lands on the near rows, so "toward the enemy" is whichever
        -- direction the far edge lies in. Measured off the spawns themselves rather than assumed to be
        -- upward, since a curated board is free to seat the party at the top.
        if lo then
            local towardTop = ((lo + hi) / 2) > (layout.rows / 2)
            for d = 1, (Arena.DEPLOY_DEPTH - 1) do
                local y = towardTop and (lo - d) or (hi + d)
                if y >= 1 and y <= layout.rows then rows[y] = true end
            end
        end
        local ordered = {}
        for y in pairs(rows) do ordered[#ordered + 1] = y end
        table.sort(ordered)
        for _, y in ipairs(ordered) do
            for x = 1, layout.cols do
                if walkableAt(layout, x, y) and not taken[key(x, y)] then
                    zone[#zone + 1] = { x = x, y = y }
                end
            end
        end
    end
    if #zone >= (minTiles or 1) then return zone end
    -- Too tight to choose on: hand back the authored spawns, which are guaranteed to be standable.
    local fallback = {}
    for _, sp in ipairs(layout.partySpawns or {}) do
        if not taken[key(sp.x, sp.y)] then fallback[#fallback + 1] = { x = sp.x, y = sp.y } end
    end
    return #fallback > 0 and fallback or zone
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
    -- The party seats by a marching grid when one was threaded through -- draft mode's, the only caller
    -- that still brings one (the campaign places per battle instead; see deployZoneFor). Curated boards
    -- apply the same grid later, in Arena.build, since their tiles aren't built here. Everything else
    -- takes the plain even auto-spread, which is also what seeds the deploy zone's rows.
    local partySpawns
    if params.formation then
        partySpawns = placePartyFormation(params.formation, params.formationCols or 4,
            params.formationRows or 2, params.party or 0, cols, rows, occupied)
    else
        partySpawns = placeUnits({ rows, rows - 1 }, params.party or 0, cols, occupied)
    end
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
    -- WHICH tile each scatter lays down is the biome's business; how MANY is not. The three rng draws
    -- below are unchanged in count and order from when every board scattered forest/mountain/obstacle,
    -- so a seed that produced a given board still produces it -- the tiles on it are simply made of
    -- whatever that biome is made of now. See Arena.BIOME_TERRAIN.
    local terrain = Arena.terrainFor(params.biome)
    scatter(terrain.fill, rng:random(2, 5))
    scatter(terrain.rise, rng:random(1, 3))
    scatter(terrain.block, rng:random(1, 3))

    -- Props (models/prop.lua): standing furniture -- a powder keg, a supply crate -- drawn from the
    -- biome's own pool, so a castle yard is littered with barrels and a forest trail with crates. Rolled
    -- LAST, after every terrain scatter above, so adding this never shifted the rng draws the terrain
    -- was already built from: a seed that produced a given board still produces that same board, now
    -- with objects on it.
    --
    -- Placed on the same neutral middle band the terrain uses (rows 3..rows-2) and never on a spawn or
    -- a tile that already holds something, so a prop can neither wall off a side nor bury a unit under
    -- an object at the opening bell. A roll that finds no free tile is simply dropped -- a board that
    -- happens to have no room for a barrel is a board with fewer barrels, not a retry loop.
    local props = {}
    for _, id in ipairs(Prop.roll(rng, params.biome, rng:random(Prop.SCATTER_MIN, Prop.SCATTER_MAX))) do
        local tries = 0
        while tries < 40 do
            tries = tries + 1
            local x, y = rng:random(1, cols), rng:random(3, rows - 2)
            if tiles[y][x] == "ground" and not occupied[key(x, y)] then
                occupied[key(x, y)] = true
                props[#props + 1] = { id = id, x = x, y = y }
                break
            end
        end
    end

    -- The biome's signature ground: a patch or two of quicksand in a desert, of fire on a volcanic
    -- floor. Rolled LAST for exactly the reason props are -- every draw above was already made when
    -- this pass did not exist, so a stored seed still reproduces the board it always did, now with the
    -- biome's own hazard on it. A biome declaring no `hazard` seeds nothing, which is every biome that
    -- shipped before this.
    --
    -- Placed on plain `ground` only. The scattered floor is where a board's character already is, and a
    -- hazard needs somewhere a unit can actually be caught: seeding onto lava (unwalkable) would put an
    -- effect where nothing can ever stand to trigger it.
    local hazards = {}
    local sig = Biome.hazardFor(params.biome)
    if sig then
        for _ = 1, rng:random(sig.min, sig.max) do
            local tries = 0
            while tries < 40 do
                tries = tries + 1
                local x, y = rng:random(1, cols), rng:random(3, rows - 2)
                if tiles[y][x] == "ground" and not occupied[key(x, y)] then
                    occupied[key(x, y)] = true
                    hazards[#hazards + 1] = { id = sig.id, x = x, y = y, duration = sig.duration }
                    break
                end
            end
        end
    end

    return {
        cols = cols, rows = rows, tiles = tiles,
        partySpawns = partySpawns, enemySpawns = enemySpawns,
        props = props,
        hazards = hazards,
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
        hazards = def.hazards or {}, -- authored hazards: { { id, x, y, side, duration }, ... } (Combat.new places them)
        props = def.props or {}, -- authored props: { { id, x, y }, ... } (barrels/crates a curated map stands)
        -- Optional: the tiles the deployment phase offers ({ { x, y }, ... }). A map that wants to say
        -- "you come in through this gate" says so here; otherwise the zone is derived from the rows the
        -- authored partySpawns sit on. See deployZoneFor and docs/deployment.md.
        deployZone = def.deployZone,
        biome = def.biome,
        curated = true, -- an authored board: its partySpawns seed the deploy zone (Arena.build)
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
            formation = spec.formation, formationCols = spec.formationCols,
            formationRows = spec.formationRows,
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
--
-- A spawn point names the unit's ANCHOR (top-left) cell, so a multi-tile body (a blueprint's
-- `footprint = { w, h }` -- see models/combat.lua) placed on an edge spawn would otherwise hang its
-- far cells off the board. `layout` supplies cols/rows so the anchor is pulled back just far enough
-- for the whole body to sit on the grid; a 1×1 unit, which is nearly all of them, never moves.
local function bindUnits(ids, spawns, offset, layout)
    local Character = require("models.character") -- lazily: character.lua never requires us back
    offset = offset or 0
    local units = {}
    for i, id in ipairs(ids) do
        local sp = spawns[i + offset]
        if not sp then break end
        local x, y = sp.x, sp.y
        local def = Character.defs and Character.defs[id]
        local fp = def and def.footprint
        if fp and layout and layout.cols and layout.rows then
            local w = math.max(1, math.floor((type(fp) == "number" and fp) or fp.w or 1))
            local h = math.max(1, math.floor((type(fp) == "number" and fp) or fp.h or 1))
            x = math.max(1, math.min(x, layout.cols - w + 1))
            y = math.max(1, math.min(y, layout.rows - h + 1))
        end
        units[i] = { id = id, x = x, y = y }
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
        return bindUnits(allyIds, layout.partySpawns, #party, layout)
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
    -- Seat the protected units from the middle of the region outward rather than from its left
    -- edge: a `rally`/`center` region resolves to a whole row (x = 1..cols) in board order, and
    -- taking them in order would jam the survivors into the corner. Order by distance from the
    -- region's own center column (ties resolve left-first for determinism) so a screened unit
    -- stands mid-line, where the party's spawns actually bracket it.
    local cx = 0
    for _, t in ipairs(anchorTiles) do cx = cx + t.x end
    cx = (#anchorTiles > 0) and (cx / #anchorTiles) or 0
    table.sort(anchorTiles, function(a, b)
        local da, db = math.abs(a.x - cx), math.abs(b.x - cx)
        if da ~= db then return da < db end
        return a.x < b.x
    end)

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
    -- The ceiling is applied HERE rather than inside resolveComposition, because that resolver also
    -- serves `allies` one line up -- and an escort is a hand-authored cast (usually one body a
    -- `protect` objective is pointed at), never a prestige formula, so it has nothing to be saved from.
    local enemyIds = Arena.clampComposition(
        Arena.resolveComposition(spec.composition, ctx), Arena.enemyCap(ctx))

    local layout = Arena.pickLayout(spec, #partyIds + #allyIds, #enemyIds)

    -- A curated layout may not have authored enough party spawns for the party *and* its
    -- escort. Dropping the escortee would instantly fail a `protect` objective, so fall
    -- back to a procedural layout sized for everyone. Only escort builds can trip this.
    if #allyIds > 0 and #layout.partySpawns < #partyIds + #allyIds then
        layout = Arena.generateLayout({
            biome = spec.biome, seed = spec.seed,
            party = #partyIds + #allyIds, enemies = #enemyIds,
            formation = spec.formation, formationCols = spec.formationCols,
            formationRows = spec.formationRows,
        })
    end

    -- Draft mode still brings a marching grid (models/draft_run.lua) and expects a curated board to
    -- honour it; a generated one already seated by it in generateLayout. The campaign passes no
    -- formation at all -- it places per battle in the deployment phase -- so this is a no-op there.
    if layout.curated and #allyIds == 0 then
        reseatByFormation(layout, spec.formation, spec.formationCols, spec.formationRows, #partyIds)
    end

    local party = bindUnits(partyIds, layout.partySpawns, 0, layout)
    local allies = bindAllies(allyIds, spec, layout)
    local enemies = bindUnits(enemyIds, layout.enemySpawns, 0, layout)

    -- The ground the deployment phase offers. Every body the BOARD itself seats is excluded -- an
    -- escorted survivor, an enemy authored deep in the party's half -- so the phase never offers a tile
    -- that is already somebody's. The party's own bound spawns are NOT excluded: those are exactly the
    -- tiles the player is choosing among (and they double as the phase's auto-fill).
    local taken = {}
    for _, u in ipairs(allies) do taken[key(u.x, u.y)] = true end
    for _, u in ipairs(enemies) do taken[key(u.x, u.y)] = true end
    for _, p in ipairs(layout.props or {}) do taken[key(p.x, p.y)] = true end

    return {
        cols = layout.cols, rows = layout.rows,
        tileSize = Arena.TILE_SIZE,
        biome = spec.biome or layout.biome,
        tiles = hydrateTiles(layout),
        party = party,
        allies = allies,
        enemies = enemies,
        -- Where the player may stand their company at the opening bell (and rotate/reinforce onto
        -- later). Sized against the FIELD cap rather than the company, since that is how many bodies
        -- ever need somewhere to be at once. See docs/deployment.md.
        deployZone = deployZoneFor(layout, taken, math.max(#partyIds, 1)),
        traps = layout.traps or {}, -- authored traps carried into combat (side defaults to enemy)
        hazards = layout.hazards or {}, -- authored hazards (fire/rain/sanctuary) carried into combat (Combat.new places them)
        props = layout.props or {}, -- scattered/authored props (barrels, crates) carried into combat (Combat.new places them)
        objective = normalizeObjective(spec.objective, layout, enemyIds),
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

    -- Props, if any: { id, x, y }. A generated board scatters these off its biome, so writing them out
    -- is what lets a lucky arrangement of barrels be CAPTURED and hand-edited into a curated map --
    -- the same reason the tiles themselves are serialized. Sideless, so there is nothing else to write.
    if arena.props and #arena.props > 0 then
        out[#out + 1] = "    props = {\n"
        for _, p in ipairs(arena.props) do
            out[#out + 1] = string.format("        { id = %q, x = %d, y = %d },\n", p.id, p.x, p.y)
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
