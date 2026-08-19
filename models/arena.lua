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
local Terrain = require("models.terrain") -- the one terrain table, shared with models/overworld.lua
local Biome = require("models.biome") -- signature ground a generated board seeds (Biome.hazardFor)

local Arena = {}

Arena.COLS = 8
Arena.ROWS = 8
Arena.TILE_SIZE = 64 -- logical pixels per cell (8*64 = 512, centered in 1280x720)

-- Arena tile palette. NO LONGER DISTINCT from the overworld's types -- both are views onto
-- models/terrain.lua, because a fight is taken on an 8x8 window of the map's own tiles and the two
-- layers cannot hold different opinions about the same ground (docs/overworld.md, one map). Kept under
-- this name because a dozen callers, four curated arenas and three specs read `Arena.TILE_PROPS`, and
-- the merge should not also be a rename of everything that consumed the merged thing.
--
-- The property documentation now lives with the table, in models/terrain.lua. In summary:
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
Arena.TILE_PROPS = Terrain.TYPES

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
    -- The bowl. Sand underfoot like the desert, but the rise is an `obstacle` rather than a mountain
    -- and so is the blocker: there is no high ground in an arena and no landform of any kind --
    -- everything standing on this floor was carried in and set down for the card.
    colosseum = { fill = "sand",  rise = "obstacle", block = "obstacle" },
}

-- The terrain palette for `biome`, always a complete table (see Arena.BIOME_TERRAIN).
function Arena.terrainFor(biome)
    return Arena.BIOME_TERRAIN[biome or "default"] or Arena.BIOME_TERRAIN.default
end

-- HOW THE GROUND A FIGHT IS TAKEN ON ARRANGES WHAT THE BIOME IS MADE OF -- deleted, because the
-- question stopped being asked.
--
-- There was a careful mechanism here for GUESSING what the ground was: Overworld:groundAt voted over a
-- 5x5 neighbourhood to name a tile a crossing or a rock field or open grass, and GROUND_PROFILES picked
-- scatter ranges so a rolled board would resemble it. A fight beside water got a channel down one flank;
-- a crossing got a channel across the middle with a single free ford.
--
-- A campaign fight is taken on the map's own tiles now (Arena.fromGrid), so the resemblance became the
-- thing: the channel down the flank IS the river, in the place it runs. What the profiles were for is
-- done by the terrain being where it is.
--
-- One guarantee genuinely died with them and was rehomed rather than lost: `band = "cross"` promised a
-- crossing exactly one free ford, tuned so the board could never be cut in half. That promise now
-- belongs to whichever layout lays the water -- models/layouts/floes.lua guarantees the fords when it
-- cuts the tundra's leads, which is the same rule made of real water.
--
-- The boardless callers -- a draft match, a duel, the menu's mock, the debug harness -- never passed a
-- ground at all, so they always drew the `path` ranges. Those ranges are inlined into generateLayout
-- below, and their boards are unchanged.

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

-- TWO FIGHT TIERS, and the ordinary one is small.
--
-- The caps above were sized when a run held eight or nine fights and every one of them was an event. A
-- descent holds ten or twelve stops per FLOOR, which only works if an ordinary fight is a two-minute
-- skirmish rather than a six-minute set-piece -- ten set-pieces is an evening, not a level. So the
-- ceiling now depends on WHAT KIND of stop this is:
--
--   skirmish   an ordinary road fight     2-4 bodies    the texture between the things that matter
--   set-piece  a guardian, a general,     6-12 bodies   the thing that matters
--              a quest objective
--
-- Keyed on the encounter's `kind`, which every encounter blueprint already declares and which
-- models/spoils.lua already keys its salvage table on (SALVAGE_CRAFT / SALVAGE_HOUSE) -- so this is the
-- existing vocabulary rather than a second one. A kind with no entry here (`objective`, and anything
-- authored later) falls through to the quest's difficulty exactly as before, which is what keeps every
-- campaign objective fighting at the size it was balanced at.
--
-- Difficulty for the skirmish tier comes from Growth.ENEMY_LEVEL_LAG and from what is standing there,
-- never from how many -- which is the argument the block above already makes, now actually applied to
-- the fights the player spends most of their time in.
Arena.SKIRMISH_CAP = 4
Arena.ELITE_CAP = 6
-- `pack` is the fight standing over a company's own dropped kit (models/descent.lua). Elite tier rather
-- than skirmish, because a big pile draws a full rival company and clamping that to four would cut the
-- anchors off the combo the draw is made of -- and rather than set-piece, because the fall-through for
-- an unnamed kind is the quest difficulty, which is the stair guardian's ceiling. Getting your bag back
-- is a hard fight; it is not a boss.
Arena.CAP_BY_KIND = { combat = Arena.SKIRMISH_CAP, elite = Arena.ELITE_CAP, pack = Arena.ELITE_CAP }

-- How many tiles of standing room one enemy is worth. The board a fight is now taken on is a window of
-- the map rather than a fixed rectangle, so a defile and a hall no longer field the same number: this
-- converts the walkable ground the box actually holds into a ceiling. Floored at 2, because an encounter
-- that resolves to a single body is not a fight the player can lose, and a board too thin to hold two is
-- a board the generator was told not to seat a fight on anyway (Overworld.BOX_OK).
local TILES_PER_ENEMY = 6
local MIN_CAP_ON_THIN_GROUND = 2

function Arena.enemyCap(ctx, usable)
    -- The kind wins where it has an opinion. Read off ctx rather than off a blueprint so the two
    -- callers that must agree -- the real fight (Arena.build) and the rating the overworld marker is
    -- drawn from (Muster.encounter) -- cannot drift: a marker that priced a nine-body fight the player
    -- then meets as four is worse than no marker at all.
    local byKind = ctx and ctx.encounterKind and Arena.CAP_BY_KIND[ctx.encounterKind]
    local quest = ctx and ctx.quest
    local cap = byKind or (quest and Arena.ENEMY_CAP[quest.difficulty]) or Arena.DEFAULT_ENEMY_CAP
    -- `usable` is nil for every caller with no map under it, which keeps their cap exactly what it was.
    if usable then
        cap = math.min(cap, math.max(MIN_CAP_ON_THIN_GROUND, math.floor(usable / TILES_PER_ENEMY)))
    end
    return cap
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

-- How often (in ticks) a synthesized endless reinforcement tops the board back up, and how the trickle
-- relates to the opening line (pressureWave below). Two objectives are handed one, for the same reason:
-- a road you have to WALK across can't be won by clearing the field, and neither can a clock you have
-- to OUTLAST. Fresh enemies keep coming until the escort arrives or the duration runs out.
Arena.PRESSURE_WAVE_PERIOD = 12

-- Build the endless reinforcement a reach or survive objective fights against, drawn from the SAME
-- roster the opening line came from (`enemyIds`) so a demon road refills with demons and a forsworn ruin
-- with forsworn -- no per-encounter authoring, no hardcoded ids. `maxAlive` holds the recurrence at the
-- opening strength (it tops up toward that count rather than piling on), and the trickle is half the
-- opening line, rounded up, walking in from all sides so it threatens the column's flanks, not just
-- its front. Returns nil when there is no roster to draw from (nothing to reinforce with).
local function pressureWave(enemyIds)
    if not enemyIds or #enemyIds == 0 then return nil end
    local trickle = {}
    for i = 1, math.max(1, math.ceil(#enemyIds / 2)) do trickle[i] = enemyIds[i] end
    return { every = Arena.PRESSURE_WAVE_PERIOD, composition = trickle,
             from = "surround", maxAlive = #enemyIds }
end

-- Copy the objective and, for the tile-based win types, stamp the ground onto it. Copied rather
-- than mutated: `spec.objective` comes straight off an immutable quest blueprint, and writing
-- resolved tiles into it would leak one run's board into the next (tests/quest_spec.lua pins that).
-- `enemyIds` is the resolved opening composition, the roster a synthesized pressure wave draws from.
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
    -- A `reach` or a `survive` fight gets endless reinforcements unless it authored its own waves.
    -- Crossing has to stay a race under pressure, never a stroll across a board you already emptied --
    -- and outlasting has to stay a HOLD-OUT. A survive whose opening line can simply be killed is not a
    -- survive at all: it is a killAll wearing a stopwatch, and the wood that nearly swallowed you is a
    -- wood you cleared in nine ticks. The tide is what the duration is a duration OF.
    --
    -- An author who wants a finite one says so with an explicit `waves` list (even an empty one), and
    -- then clearing the last of them ends the fight rather than running the clock out on bare ground
    -- (Combat.outcomeFor's survive branch).
    if (out.type == "reach" or out.type == "survive") and not out.waves then
        local wave = pressureWave(enemyIds)
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

-- The board cell a marching-grid slot maps to. Only the DRAFT has such a grid now (the campaign places
-- per battle, in the deployment phase); see DraftRun.FORMATION. Grid ROW 1 is the FRONT line -- it
-- faces the enemy, and the enemy holds the FAR edge (low y) while the party lands on the near rows --
-- so the front rank must sit one row TOWARD the enemy from the party's home edge, not on it:
-- front (row 1) -> rows-frows+1, back (row frows) -> rows (the home edge). Deeper grid rows step BACK
-- toward that edge. Grid columns spread across the full board width with the SAME even spacing
-- placeUnits uses.
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
-- It is deliberately WIDER than the field -- placement is only a decision if there are more tiles than
-- bodies -- and where a map does not say otherwise it is a FIXED BLOCK, so every board offers the same
-- shape of choice and the phase reads identically fight to fight:
--
--   1. an authored `deployZone` on a curated layout wins outright (a map that wants to say "you come in
--      through this gate" says so);
--   2. otherwise, the eight tiles at the BOTTOM CENTRE of the board -- DEPLOY_COLS wide, DEPLOY_DEPTH
--      deep, against the party's own home edge. Four bodies over eight tiles is a real placement, and
--      two rows make front-and-back a decision and not just left-and-right. The block is not derived
--      from where the spawns happen to have landed: the generator spreads those across the full width,
--      which lit up the whole bottom of the board and made "the zone" indistinguishable from "the near
--      half";
--   3. tiles another unit is authored onto (an escort, an enemy that spawned deep) are excluded, so the
--      phase can never offer a cell somebody is already standing in.
--
-- Falls back to the party spawns themselves if that yields fewer than `minTiles` cells: a cramped
-- authored board must never produce a phase with nowhere to stand.
--
-- BOTTOM is the party's edge everywhere in this file -- enemies muster on the low rows (placeUnits),
-- the marching grid's front rank faces them (formationCell) -- so a board that wants the party coming in
-- from anywhere else authors its own zone rather than being guessed at.

-- How many rows deep the block is: one to stand the line on and one to stand behind it, which is exactly
-- the front/back choice the old marching grid offered.
Arena.DEPLOY_DEPTH = 2
-- How wide, in columns. Four by two is eight tiles -- the same shape the draft's marching grid keeps
-- (DraftRun.FORMATION_COLS/ROWS), and twice the field cap.
Arena.DEPLOY_COLS = 4
-- The fewest tiles a zone may offer before it is treated as too cramped to choose on. The field cap:
-- four bodies ever need somewhere to be at once. Mirrored here rather than reached for out of
-- models/combat.lua, the same way Combat.MAX_FIELD mirrors Player.MAX_FIELD.
Arena.DEPLOY_MIN = 4

-- The default block, before walkability and occupancy are applied: DEPLOY_COLS x DEPLOY_DEPTH, centred
-- on the board's width and flush with its bottom edge. Clamped to the board, so a board narrower or
-- shallower than the block still gets whatever of it fits.
local function defaultZoneBlock(layout)
    local w = math.min(Arena.DEPLOY_COLS, layout.cols)
    local d = math.min(Arena.DEPLOY_DEPTH, layout.rows)
    -- Left-biased on an odd remainder (cols 3..6 of eight), matching how placeUnits centres a line.
    local x0 = math.floor((layout.cols - w) / 2) + 1
    local block = {}
    for y = layout.rows - d + 1, layout.rows do
        for x = x0, x0 + w - 1 do block[#block + 1] = { x = x, y = y } end
    end
    return block
end

local function deployZoneFor(layout, taken, minTiles)
    local authored = layout.deployZone
    local offered = (authored and #authored > 0) and authored or defaultZoneBlock(layout)
    local zone = {}
    for _, t in ipairs(offered) do
        if walkableAt(layout, t.x, t.y) and not taken[key(t.x, t.y)] then
            zone[#zone + 1] = { x = t.x, y = t.y }
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

-- ---------------------------------------------------------------------------
-- The board carved out of the map
-- ---------------------------------------------------------------------------

-- WHICH SIDE OF THE BOARD IS YOURS. The party deploys on the edge it arrived from, which a rolled board
-- could never say because a rolled board has no outside.
--
-- Read as a DIRECTION -- where the company came FROM, relative to where it met the fight -- and not as a
-- distance to the box's edges. The distance version was written first and it is subtly wrong: the window
-- is chosen for the ground it holds, not centred on the contact tile, so it can sit hard against the
-- approach and leave "the edge you came in by" measuring nearer to some other side. The direction is
-- unambiguous and is what the player experienced.
--
-- The dominant axis wins, so a diagonal approach (which the 4-neighbour grid never actually produces,
-- but a scripted fight might hand over) still resolves to one side. Ties go to the vertical, which is
-- the home edge a board has always used.
local function entryEdge(at, from)
    if not from then return "bottom" end -- nothing recorded: the board's old home edge
    local dx, dy = at.x - from.x, at.y - from.y
    if math.abs(dx) > math.abs(dy) then
        return dx > 0 and "left" or "right"
    end
    if dy ~= 0 then return dy > 0 and "top" or "bottom" end
    return "bottom"
end

local function oppositeEdge(e)
    if e == "top" then return "bottom" end
    if e == "bottom" then return "top" end
    if e == "left" then return "right" end
    return "left"
end

-- The tiles of a band `depth` deep along one edge, walkable only, ordered from the middle of the band
-- outwards -- so a short line seats centred, exactly as placeUnits does on a rolled board.
local function bandTiles(tiles, cols, rows, edge, depth, occupied)
    local out = {}
    local function add(x, y)
        if x < 1 or y < 1 or x > cols or y > rows then return end
        local p = Arena.TILE_PROPS[tiles[y][x]]
        if not (p and p.walkable) then return end
        if occupied and occupied[key(x, y)] then return end
        out[#out + 1] = { x = x, y = y }
    end
    for d = 0, depth - 1 do
        if edge == "bottom" then
            for x = 1, cols do add(x, rows - d) end
        elseif edge == "top" then
            for x = 1, cols do add(x, 1 + d) end
        elseif edge == "left" then
            for y = 1, rows do add(1 + d, y) end
        else
            for y = 1, rows do add(cols - d, y) end
        end
    end
    -- Middle-out, so four bodies on a wide band stand together rather than at the corners.
    local mid = (edge == "left" or edge == "right") and (rows + 1) / 2 or (cols + 1) / 2
    table.sort(out, function(a, b)
        local ka = (edge == "left" or edge == "right") and a.y or a.x
        local kb = (edge == "left" or edge == "right") and b.y or b.x
        local da, db = math.abs(ka - mid), math.abs(kb - mid)
        if da ~= db then return da < db end
        return ka < kb
    end)
    return out
end

-- How much ground the board a fight at (x, y) would lock actually holds, of COLS*ROWS. Read before the
-- opposition is resolved, because the cap on how many bodies a fight fields has to know how much floor
-- there is to field them on (Arena.enemyCap).
--
-- CROSSABLE floor, not walkable floor: the ring the lock draws can cut a window in two, and the far
-- pocket is walled by Arena.fromGrid rather than fought over. Pricing a fight off tiles that are about to
-- become wall is how a defile ends up fielding a hall's worth of bodies.
function Arena.boxUsable(grid, x, y)
    if not (grid and grid.bestBox) then return nil end
    return select(3, grid:bestBox(x, y))
end

-- THE BOARD IS A WINDOW ON THE MAP. Given the overworld grid and the tile a fight began on, cut the
-- COLS x ROWS window the lock would close around and hand it back as an ordinary layout -- same shape
-- Arena.generateLayout returns, so nothing downstream of here learns anything new.
--
-- The window is CHOSEN, not centred: of every window containing the contact tile, the one holding the
-- most ground you can cross from it (Overworld:bestBox). Meet something at the mouth of a clearing and
-- the board pulls into the clearing; get cornered in a corridor and it stays a corridor, because there
-- was nothing better within reach.
--
-- Tiles carry over VERBATIM. That is the whole point of merging the two terrain tables
-- (models/terrain.lua): the thicket that walled the trail is the thicket you fight around, the river is
-- the river, and the biome floor the layout scattered is the floor underfoot. No profile, no scatter,
-- no resemblance -- the ground you chose to walk onto is the ground you fight on.
--
-- The box's edge is the wall, so nothing has to be drawn to make one: outside the window there is no
-- board. What the ring looks like is the renderer's business.
--
-- ...and because that ring is a wall, the window is CLOSED over ground that was open. A box laid across a
-- ridge, a river bend or the outside of a switchback holds two pockets that on the map are joined by a
-- path running round the outside -- and inside the lock that path does not exist. The board would open
-- with a boar on one side of a wall and the company on the other, neither able to reach the other for the
-- whole fight, and a killAll it cannot finish. So the tiles the fight cannot get to are WALLED: see
-- sealUnreachable. Overworld:bestBox chooses the window by the same measure, so the board is the biggest
-- crossable piece of ground within reach and not the biggest pile of tiles.
function Arena.fromGrid(grid, opts)
    opts = opts or {}
    local cols, rows = Arena.COLS, Arena.ROWS
    local ox, oy = grid:bestBox(opts.x, opts.y)
    -- The ground reachable from the tile the fight began on, in MAP keys. Read off the grid rather than
    -- recomputed over the cut tiles so the seal and the score a fight was priced from (Arena.boxUsable,
    -- which is the same call) can never be two different opinions about the same window.
    local reachable = {}
    local reach = grid:boxReach(ox, oy, opts.x, opts.y, reachable)

    local tiles = {}
    -- What is already burning (or blessed, or falling) on this ground when the lock closes. A map cell
    -- may carry an authored `hazard` (models/overworld.lua's fromLayout), and the ones inside the window
    -- are the ones this fight opens with -- rebased to board coordinates, since nothing past here knows
    -- where on the map it is standing. The same list an authored arena hands over, on the side a
    -- campaign fight is actually cut from now.
    local hazards = {}
    for j = 1, rows do
        tiles[j] = {}
        for i = 1, cols do
            local c = grid:get(ox + i - 1, oy + j - 1)
            -- Off the map reads as solid rather than as open field: a board that runs off the edge of
            -- the world should be walled by it, not floored by it.
            tiles[j][i] = (c and c.tile) or "obstacle"
            -- ...and so does open ground the lock cut off from the rest of the board. A tile behind the
            -- ring is not somewhere the fight can go, and drawing it as floor is the worse of the two
            -- lies: the player reads a board twice the size it is, walks a unit at a pocket it can never
            -- enter, and watches an enemy stand in one it will never leave. Walled with the plain
            -- `obstacle` -- the board's own word for "not through here", and what the ring outside the
            -- window already is -- rather than with the biome's scatter blocker, because this is the edge
            -- of the board arriving early, not a landform.
            --
            -- `reach == 0` means the fight began somewhere nothing can stand (a fixture, never a real
            -- contact tile); seal nothing rather than wall the whole board.
            if reach > 0 and c and grid:typeWalkable(c.tile)
                and not reachable[(oy + j - 1) * 100000 + (ox + i - 1)] then
                tiles[j][i] = "obstacle"
            elseif c and c.hazard then
                hazards[#hazards + 1] = { id = c.hazard.id, x = i, y = j, duration = c.hazard.duration }
            end
        end
    end

    local occupied = {}
    local entry = entryEdge({ x = opts.x, y = opts.y }, opts.from)

    -- WHICH SIDE THE ENEMY COMES IN ON. Opposite the company by default, which is what a fight the
    -- player walked into looks like: two lines facing each other.
    --
    -- `foeFrom` overrides it with the tile the enemy actually arrived from, and that is the whole payoff
    -- of the patrol layer (P10). Let something catch you while you are deep in a spur and it comes in on
    -- the side you were walking back toward -- between the company and the way out. Same composition, at
    -- the same tier, as a completely different problem, decided by how the approach was handled rather
    -- than by a roll.
    --
    -- Falls back to opposite when the two resolve to the same edge, or the two lines would open the
    -- fight standing on each other.
    local far = oppositeEdge(entry)
    if opts.foeFrom then
        local side = entryEdge({ x = opts.x, y = opts.y }, opts.foeFrom)
        if side ~= entry then far = side end
    end

    -- The party takes the edge it walked in from; whatever it met takes the far side. When patrols land,
    -- the far side becomes the side the patrol touched from -- walk into something head-on and you meet
    -- it head-on, let it catch you in a spur and it is between you and the way out.
    local partyBand = bandTiles(tiles, cols, rows, entry, Arena.DEPLOY_DEPTH, occupied)
    local partySpawns = {}
    for i = 1, math.min(opts.party or 0, #partyBand) do
        partySpawns[#partySpawns + 1] = partyBand[i]
        occupied[key(partyBand[i].x, partyBand[i].y)] = true
    end

    local enemyBand = bandTiles(tiles, cols, rows, far, Arena.DEPLOY_DEPTH, occupied)
    local enemySpawns = {}
    for i = 1, math.min(opts.enemies or 0, #enemyBand) do
        enemySpawns[#enemySpawns + 1] = enemyBand[i]
        occupied[key(enemyBand[i].x, enemyBand[i].y)] = true
    end

    -- A cramped board may not have offered enough standing room on either band. Spill onto any walkable
    -- tile rather than fielding fewer bodies than the fight was priced for -- the same graceful partial
    -- every placement pass on the map takes.
    local function spill(list, want)
        if #list >= want then return end
        for y = 1, rows do
            for x = 1, cols do
                if #list >= want then return end
                local p = Arena.TILE_PROPS[tiles[y][x]]
                if p and p.walkable and not occupied[key(x, y)] then
                    list[#list + 1] = { x = x, y = y }
                    occupied[key(x, y)] = true
                end
            end
        end
    end
    spill(partySpawns, opts.party or 0)
    spill(enemySpawns, opts.enemies or 0)

    -- YOUR SIDE OF THE BOARD, AND IT HAS TO BE BIG ENOUGH TO BE A SIDE. Two rows of the arrival edge is
    -- the shape (Arena.DEPLOY_DEPTH), and on a cut board those two rows are whatever the map put there:
    -- a window can clear both fightability floors and still be walled along the one edge the company
    -- happens to come in by. Measured across 180 seated fights, a quarter of them offered fewer than
    -- eight of the sixteen band tiles and four offered NONE, at which point deployZoneFor falls all the
    -- way back to the spawn spill -- which is the scattered smear of lit tiles down a wall that this
    -- reads as in the game.
    --
    -- So the band DEEPENS rather than the zone giving up: it takes another row of your own side until it
    -- holds a company, which keeps every claim the zone makes ("the edge you arrived from", contiguous
    -- with where you walked in) and gives up only the fixed depth, which was never a promise to anybody.
    -- Half the board is the cap, past which "your side" has stopped meaning anything and the fallback is
    -- the honest answer.
    local deployZone = bandTiles(tiles, cols, rows, entry, Arena.DEPLOY_DEPTH, nil)
    local depth = Arena.DEPLOY_DEPTH
    local maxDepth = math.floor(((entry == "left" or entry == "right") and cols or rows) / 2)
    while #deployZone < Arena.DEPLOY_MIN and depth < maxDepth do
        depth = depth + 1
        deployZone = bandTiles(tiles, cols, rows, entry, depth, nil)
    end

    return {
        cols = cols, rows = rows, tiles = tiles,
        partySpawns = partySpawns, enemySpawns = enemySpawns,
        props = {}, hazards = hazards, traps = {},
        biome = opts.biome,
        -- Authored, so deployZoneFor uses it outright: the eight tiles of the edge you arrived on,
        -- which is what docs/deployment.md's fixed block becomes once the board has an outside.
        deployZone = deployZone,
        -- Where on the map this board was cut from, so the renderer can put the camera over it and the
        -- run's save can restore the same eight tiles (docs/overworld.md, C5).
        box = { x = ox, y = oy, w = cols, h = rows, entry = entry },
    }
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

    -- Which occupied tiles are SPAWNS, captured before any terrain is laid (at this point `occupied` holds
    -- nothing else). The channel below cuts through whatever the scatters put down -- a river runs over a
    -- boulder rather than politely around it, and flowing around them leaves a dotted line instead of a
    -- channel -- but it must never open the fight with somebody already standing in the water.
    local spawnKeys = {}
    for k in pairs(occupied) do spawnKeys[k] = true end

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
    -- WHICH tile each scatter lays down is the biome's business; how MANY is fixed. The three rng draws
    -- below are unchanged in COUNT and ORDER from the day this generator was written, so every seed that
    -- ever produced a given board still produces it -- the tiles on it are simply made of whatever that
    -- biome is made of. The ranges are the ones the old `path` profile carried, which is what every
    -- caller that reaches this function has always drawn (see the note on GROUND_PROFILES above).
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
    -- A curated board keeps its authored geometry, ground or no ground: a hand-placed colosseum does not
    -- grow a river because the marker outside happened to sit by one. Ground shapes generated boards only.
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

-- The w×h block a blueprint's body covers, read from the id alone -- no instance needed. Both places
-- that care (seating a body on the board, and marking the ground it takes up) go through the one
-- normalizer, so they can never disagree about how big an ogre is.
local function footprintOf(id)
    local Character = require("models.character") -- lazily: character.lua never requires us back
    local def = Character.defs and Character.defs[id]
    local fp = Character.normalizeFootprint(def and def.footprint)
    return fp.w, fp.h
end

-- Mark the w×h block anchored at (x, y) as somebody's. The one way a body's ground is written down,
-- so "what is already claimed" is always the whole footprint and never just the corner.
local function claimCells(taken, x, y, w, h)
    for j = 0, (h or 1) - 1 do
        for i = 0, (w or 1) - 1 do taken[key(x + i, y + j)] = true end
    end
end

-- Whether a w×h body could stand anchored at (x, y): every cell of it on the board, walkable, and
-- nobody else's.
local function anchorFree(layout, taken, w, h, x, y)
    if x < 1 or y < 1 or x + w - 1 > layout.cols or y + h - 1 > layout.rows then return false end
    for j = 0, h - 1 do
        for i = 0, w - 1 do
            local cx, cy = x + i, y + j
            if taken[key(cx, cy)] then return false end
            local t = (layout.tiles and layout.tiles[cy] and layout.tiles[cy][cx]) or "ground"
            local p = Arena.TILE_PROPS[t] or Arena.TILE_PROPS.ground
            if not p.walkable then return false end
        end
    end
    return true
end

-- The nearest anchor to (x, y) a w×h body actually fits on, searched outward in rings so a body
-- pushed off its spawn point stays with the line it was seated in. Nil only when the whole board
-- has no room for it, which leaves the caller with its spawn point as it stood.
local function nearestAnchor(layout, taken, w, h, x, y)
    if anchorFree(layout, taken, w, h, x, y) then return x, y end
    for r = 1, math.max(layout.cols, layout.rows) do
        for dy = -r, r do
            for dx = -r, r do
                if math.max(math.abs(dx), math.abs(dy)) == r
                    and anchorFree(layout, taken, w, h, x + dx, y + dy) then
                    return x + dx, y + dy
                end
            end
        end
    end
end

-- Bind unit id lists onto a layout's spawn points (zipping to the shorter length).
-- `offset` skips spawn points already claimed by an earlier bind.
--
-- A spawn point names the unit's ANCHOR (top-left) cell, so a multi-tile body (a blueprint's
-- `footprint = { w, h }` -- see models/combat.lua) placed on an edge spawn would otherwise hang its
-- far cells off the board. `layout` supplies cols/rows so the anchor is pulled back just far enough
-- for the whole body to sit on the grid; a 1×1 unit, which is nearly all of them, never moves.
--
-- A spawn list hands out ONE POINT PER BODY, which is a fair description of the board only while
-- every body is 1x1. An ogre anchored on a band tile covers the three beside it -- points its own
-- escort was seated on -- and the fight opened with bandits standing inside the brute. So the block
-- each body takes is claimed in `taken` (shared across every bind of one board, and seeded with the
-- props already standing), and a body whose spawn is somebody else's is walked out to the nearest
-- ground it fits on.
local function bindUnits(ids, spawns, offset, layout, taken)
    offset = offset or 0
    taken = taken or {}
    local units = {}
    for i, id in ipairs(ids) do
        local sp = spawns[i + offset]
        if not sp then break end
        local x, y = sp.x, sp.y
        if layout and layout.cols and layout.rows then
            local w, h = footprintOf(id)
            x = math.max(1, math.min(x, layout.cols - w + 1))
            y = math.max(1, math.min(y, layout.rows - h + 1))
            local fx, fy = nearestAnchor(layout, taken, w, h, x, y)
            x, y = fx or x, fy or y
            claimCells(taken, x, y, w, h)
        else
            claimCells(taken, x, y, 1, 1)
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
local function bindAllies(allyIds, spec, layout, taken)
    local party = spec.party or {}
    local obj = spec.objective
    local anchor = obj and obj.anchor
    local protectId = obj and obj.protect
    if not (anchor and protectId) then
        return bindUnits(allyIds, layout.partySpawns, #party, layout, taken)
    end

    -- Region tiles that no unit already stands on, so an anchored survivor never shares a cell.
    -- `taken` already holds the party (and the props), claimed a footprint at a time by the bind
    -- above -- there is nothing left for this pass to work out for itself.
    taken = taken or {}
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

    -- Seating claims the whole block each body stands on, and walks a body out to the nearest ground
    -- it fits when its tile is somebody's -- an escorted survivor is as capable of being a 2x2 as an
    -- ogre is, and two of them seated a tile apart would otherwise stand in each other.
    local units, anchored, rest = {}, 0, 0
    local function seat(id, x, y)
        local w, h = footprintOf(id)
        local fx, fy = nearestAnchor(layout, taken, w, h, x, y)
        x, y = fx or x, fy or y
        claimCells(taken, x, y, w, h)
        units[#units + 1] = { id = id, x = x, y = y }
    end
    for _, id in ipairs(allyIds) do
        if id == protectId and anchorTiles[anchored + 1] then
            anchored = anchored + 1
            local t = anchorTiles[anchored]
            seat(id, t.x, t.y)
        else
            rest = rest + 1
            local sp = layout.partySpawns[#party + rest]
            if sp then seat(id, sp.x, sp.y) end
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
    -- HOW MUCH FLOOR THERE IS TO FIELD THEM ON, read before the opposition is resolved. A rolled board
    -- was always the same 64 tiles of mostly-open ground, so a fixed cap was a fair description of it. A
    -- board carved out of the map might be 55 tiles in a hall or 24 in a defile, and eight bodies in a
    -- defile is not a hard fight, it is a queue. Nil for every caller without a map (draft, duel, the
    -- menu's mock), which keeps their cap exactly what it has always been.
    local usable = spec.grid and spec.at and Arena.boxUsable(spec.grid, spec.at.x, spec.at.y) or nil
    local enemyIds = Arena.clampComposition(
        Arena.resolveComposition(spec.composition, ctx), Arena.enemyCap(ctx, usable))

    -- THE BOARD IS THE MAP, where there is a map. A campaign fight and a descent floor carve their 8x8
    -- out of the tiles the company walked over; a draft match, a duel, the menu's mock and the debug
    -- harness have no overworld under them and still roll one (Arena.pickLayout).
    local layout
    if spec.grid and spec.at then
        layout = Arena.fromGrid(spec.grid, {
            x = spec.at.x, y = spec.at.y, from = spec.from, foeFrom = spec.foeFrom,
            party = #partyIds + #allyIds, enemies = #enemyIds,
            biome = spec.biome,
        })
    else
        layout = Arena.pickLayout(spec, #partyIds + #allyIds, #enemyIds)
    end

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

    -- ONE occupancy set across all three binds, seeded with the furniture already standing. A spawn
    -- list has one point per body and no idea how big any of them is, so without this an ogre's 2x2
    -- block simply covered the points its own escort was seated on (see bindUnits).
    local seated = {}
    for _, p in ipairs(layout.props or {}) do claimCells(seated, p.x, p.y, 1, 1) end
    local party = bindUnits(partyIds, layout.partySpawns, 0, layout, seated)
    local allies = bindAllies(allyIds, spec, layout, seated)
    local enemies = bindUnits(enemyIds, layout.enemySpawns, 0, layout, seated)

    -- The ground the deployment phase offers. Every body the BOARD itself seats is excluded -- an
    -- escorted survivor, an enemy authored deep in the party's half -- so the phase never offers a tile
    -- that is already somebody's. The party's own bound spawns are NOT excluded: those are exactly the
    -- tiles the player is choosing among (and they double as the phase's auto-fill).
    --
    -- A body is excluded by its whole FOOTPRINT, not by its anchor cell: an ogre is a 2x2 block, and
    -- marking only the corner it is anchored on offered the player the other three -- which is exactly
    -- how a knight ended up standing inside one.
    local taken = {}
    local function claim(x, y, w, h)
        for j = 0, (h or 1) - 1 do
            for i = 0, (w or 1) - 1 do taken[key(x + i, y + j)] = true end
        end
    end
    for _, u in ipairs(allies) do claim(u.x, u.y, footprintOf(u.id)) end
    for _, u in ipairs(enemies) do claim(u.x, u.y, footprintOf(u.id)) end
    for _, p in ipairs(layout.props or {}) do claim(p.x, p.y, 1, 1) end

    return {
        cols = layout.cols, rows = layout.rows,
        tileSize = Arena.TILE_SIZE,
        biome = spec.biome or layout.biome,
        tiles = hydrateTiles(layout),
        party = party,
        allies = allies,
        enemies = enemies,
        -- Where the player may stand their company at the opening bell (and rotate/reinforce onto
        -- later). The floor it must clear is the FIELD cap, not the company: `partyIds` is the whole
        -- marching roster (states/game.lua hands over `player.roster` entire), and only four of them
        -- ever stand at once -- a nine-strong company must not be what makes an eight-tile block read
        -- as "too cramped". See docs/deployment.md.
        deployZone = deployZoneFor(layout, taken, math.min(math.max(#partyIds, 1), Arena.DEPLOY_MIN)),
        -- WHERE ON THE MAP THIS BOARD WAS CUT FROM: { x, y, w, h, entry }, or nil for a rolled board
        -- that was cut from nowhere. The camera needs it to put the fight over the ground it belongs to,
        -- and a resumed run needs it to lock the same eight tiles it locked before (docs/overworld.md,
        -- U4 and C5) -- so it has to survive Arena.build rather than stopping at the layout.
        box = layout.box,
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
