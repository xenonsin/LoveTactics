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
local Layout = require("models.layout") -- which carve this ground uses (models/layouts/)
local Encounter = require("models.encounter") -- guaranteed stops resolve by kind off the blueprints (see guaranteedEntry)

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
-- and floored at a playable minimum.
--
-- THE CAP GREW BECAUSE A STOP GREW. It was 27x19 of play area, and the reasoning was sound for the
-- board it was written for: "a Dream Quest board is dense and readable, every tile a choice, not a
-- marathon warren to shuffle a token through". But a stop was a marker you stepped onto and the fight
-- happened somewhere else. A stop is a BATTLEFIELD now -- an 8x8 window of these tiles, walled and
-- fought over -- so a board seating four or five fights has to physically contain four or five rooms
-- big enough to fight in, with trail between them.
--
-- Measured, at the old cap: a forest board with clearings opened into it reached 37% fightable trail
-- and 0.55 arena sites against 4.6 fights, because 31x23 holds about thirty-five lattice nodes and
-- there is nowhere to put four rooms without eating the maze that connects them. The compactness rule
-- and the fightability floor were in direct conflict, and the rectangle was the thing that had to give.
--
-- It is still capped, and the walk is still sub-linear in content. What changed is the constant, and
-- what justifies it is that most of the added area is ROOM rather than corridor -- a glade is crossed
-- in three steps and is somewhere you stop, where thirty more tiles of 1-wide trail would have been
-- exactly the marathon the old cap was guarding against.
local DIM_MAX_COLS, DIM_MAX_ROWS = 37, 25
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
-- SIZED ON DENSITY, NOT ON SPACING. The reasoning above is right and its old proxy was wrong: what the
-- rule wants to know is how much of the rectangle ends up trail, and `spacing` is only a lattice's way
-- of saying that. A cave or an open plain has no spacing to report, and a board of rooms packs its floor
-- quite differently from a maze at any spacing. So a layout declares its own density and the lattice
-- ones answer 1/spacing -- arithmetically the old rule exactly, so no maze board moves by a tile.
--
-- `ends` is how many objectives the board carries beyond the first. A ground offering three quests has
-- to hold three dead ends far enough apart to read as three places, and sizing as if it held one is
-- what produces the crowded fallback in placeObjectiveAndGates -- the board runs out of spurs and an
-- objective lands on open trail. Counted like a key or a cache: it is one more stop to walk to.
local BASELINE_DENSITY = 1 / 4 -- the forest's, so it is the ground everything else is measured against
local function deriveDims(encounters, keyCount, cacheCount, density, ends)
    local content = (encounters or 0) + (keyCount or 0) + (cacheCount or 0)
        + math.max(0, (ends or 1) - 1)
    local tightness = math.sqrt(BASELINE_DENSITY / math.max(0.01, density or BASELINE_DENSITY))
    -- The coefficient rose with the cap, or the span would never reach it and every board would sit at
    -- the old size wearing a larger ceiling.
    local span = math.floor(6.5 * math.sqrt(content) * tightness) -- ~13 at content=4 (forest)
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

    -- WHICH CARVE, resolved here rather than at the carve itself: how much of a rectangle a layout turns
    -- into trail is the thing the sizing rule scales on, so the layout has to be known before the
    -- rectangle is. An unnamed or unknown biome falls back to the maze, so a half-written blueprint
    -- still produces the board the game has always had (models/layout.lua).
    self.braidRate = params.braid or Overworld.BRAID
    self.layoutId = params.layout or biomeDef.layout or "maze"
    local layout = Layout.get(self.layoutId)

    -- Play area: honour explicit cols/rows, otherwise scale with the encounters
    -- (and keys) so the map never sprawls into empty wandering. See deriveDims.
    local density = layout.density and layout.density(self) or nil
    local dCols, dRows = deriveDims(self.encounterTarget, params.keyCount, self.cacheTarget, density,
        params.objectives and #params.objectives or 1)
    local playCols = params.cols or dCols
    local playRows = params.rows or dRows
    -- The coastline is padding too, for exactly the margin's reason: weatherEdges eats a wandering
    -- couple of tiles off every side, and a play area sized to hold eight stops that then has a third of
    -- itself weathered away is not the play area the sizing rule asked for. So the surplus the coast
    -- will take is added first and eaten back, which is measurable: without it `. board-report` puts the
    -- desert's walkable share at 40% against the 55% it was built to hold, and the places a fight can
    -- actually go drop from 4.7 a board to 2.8.
    self.coast = layout.ownsEdge and 0 or Overworld.EDGE_SURPLUS
    self.cols = playCols + 2 * (self.margin + self.coast)
    self.rows = playRows + 2 * (self.margin + self.coast)
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
            self.cells[y][x] = { x = x, y = y, tile = "thicket" }
        end
    end

    -- The carve itself. Everything below it works on whatever walkable graph comes out.
    layout.carve(self)
    -- ...and then the frame it stopped against is weathered off, unless the ground means to be square
    -- (see weatherEdges and `ownsEdge`). Run first of the shared passes, so the rivers, the objective and
    -- every stop after them are placed on the coastline the board actually ends up with.
    if not layout.ownsEdge then self:weatherEdges() end

    local riverSpec = params.riverCount
    -- A layout that lays its own channels keeps them: the shared river pass assumes a lattice to run
    -- between, and thinBridges would demote a wide crossing back to trail. See docs/overworld.md's C2.
    if layout.ownsWater then riverSpec = 0 end
    if riverSpec == nil then riverSpec = biomeDef.rivers end
    self:placeRivers(resolveCount(riverSpec, self.rng))
    self:thinBridges() -- guarantee every bridge is exactly one tile
    self:decorate()
    self:placeObjectiveAndGates(params)
    self:placeCaches(params)    -- the rewards take the spur ends FIRST (see placeCaches)
    self:placeEncounters(params)-- then the fights fill the corridors between them
    self:guardBoons(params)     -- stand a fight in front of most of the rewards
    self:pruneDeadStubs()       -- trim barren spur-and-return corridors (no RNG)
    self:assignEncounterTiers() -- difficulty tell for the fog (drawn from rng LAST)
    self:placePatrols(params)  -- ...and the fights that walk lift off their cells onto beats
    self:placeSecrets(params)  -- ...ground the fog will not lift until somebody finds the door
    self:placeSecretRewards(params) -- ...and what is behind it, which is never one of the board's stops
    self:placeExit(params)     -- ...and, on a floor you can leave, the way back up you came in by

    -- The board is finished: no pass after this rewrites a tile, so the box lookups it will be asked for
    -- thousands of times over a run can be cached (see walkableSums).
    self.sealed = true

    return self
end

-- ---------------------------------------------------------------------------
-- Authored maps
-- ---------------------------------------------------------------------------

-- Char -> tile type for an authored map's ASCII `map`. The role chars (S / X / 1..9)
-- all stand on trail, so they are resolved to "path" below rather than listed here.
--
-- The lower-case half is WALKABLE ground, and it is here because a fight is now taken on an 8x8 window
-- of these tiles (models/arena.lua's Arena.fromGrid). Until that was true an authored map only ever had
-- to say where the trail went, and six solid fills said it; now the same characters have to describe a
-- battlefield -- cover to fight behind, high ground to shoot from, a floor that slows a crossing -- and
-- a map that can only spell "wall" can only author a corridor. See data/overworld/tutorial_flight.lua,
-- which is the first map to need them, and models/terrain.lua for what each one costs.
local LAYOUT_TILE = {
    ["#"] = "thicket", ["."] = "path", ["="] = "bridge", ["~"] = "river",
    [","] = "grass",  ["^"] = "rock",
    ["f"] = "forest", ["m"] = "mountain", ["w"] = "water", ["r"] = "rough",
}

-- Build a HAND-AUTHORED overworld from data/overworld/<id>.lua instead of carving a maze. The layout is
-- an ASCII `map` (rows of equal-length strings) plus a biome; see data/overworld/tutorial_flight.lua for
-- the legend. `S` fixes the start, `X` the objective, and each digit `1..9` is a route stop: the Nth
-- stop is handed the Nth `params.alwaysEncounters` entry, so the geometry fixes WHERE each stop sits
-- while the quest stays the single source of WHAT it is (id / loot / conversation).
--
-- A layout may also carry a `hazards` list -- { { id, x, y, duration }, ... } in MAP coordinates --
-- which is stamped onto the cells named. Whichever of them fall inside a locked window ride into that
-- fight (Arena.fromGrid), so an authored board can open in a state rather than merely on a shape: the
-- Champion's treeline is already burning when you reach it. This is the seam data/arenas/*.lua's own
-- `hazards` used to serve, restored on the side the fight is actually cut from now.
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
                -- An authored leg has exactly one end -- the geometry IS the choreography -- so it
                -- reports a one-entry list rather than opting out of the shape everything downstream
                -- now reads (states/game.lua's checklist walks self.objectives).
                local spec = (params.objectives and params.objectives[1]) or params.objective or {}
                self.objective = { x = x, y = y, questId = spec.questId }
                self.objectives = { self.objective }
                cell.encounter = { kind = "objective", name = spec.name or "Objective",
                    questId = spec.questId }
            elseif ch:match("%d") then
                routeCells[tonumber(ch)] = cell
            end
        end
    end

    assert(self.start, "authored layout has no start (S)")
    assert(self.objective, "authored layout has no objective (X)")

    -- WEATHER THE FILL, exactly as a rolled board's is. An authored layout skips the whole generation
    -- pipeline, and one pass of it was being missed rather than declined: Overworld:decorate, which lays
    -- the thicket's two cosmetic variants (scrub and standing rock) by noise. Without it every solid tile
    -- on the map is the one glyph the author typed, so the wood either side of the trail is a flat plane
    -- of a single colour -- which reads as a corridor cut through a fill rather than as country, and is
    -- the same thing docs/overworld.md's coastline argument says about a square frame.
    --
    -- Safe to run over an authored map BECAUSE IT ONLY EVER TOUCHES `thicket`, and thicket is what an
    -- author spells the fill with. Every tile inside a fight chamber is named outright (`.`/`f`/`^`/`w`/
    -- `m`), so nothing the layout composed as a battlefield is reachable from here; what it rewrites is
    -- solid before and solid after, at the same walkability and the same sight cost. The noise is
    -- unseeded and deterministic, so the trail wears the same weather every run.
    self:decorate()

    -- The authored opening state, stamped onto the cells it names (see the header). Out-of-bounds
    -- entries are dropped rather than asserted on: a hazard is decoration on the fight it lands in, and
    -- a typo in one must not take the whole leg down with it.
    for _, h in ipairs(layout.hazards or {}) do
        local cell = self:inBounds(h.x, h.y) and self.cells[h.y][h.x]
        if cell then cell.hazard = { id = h.id, duration = h.duration } end
    end

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

-- ---------------------------------------------------------------------------
-- Weathering the edge
-- ---------------------------------------------------------------------------
--
-- A carve fills the rectangle it is handed and stops at the margin, so every board came out framed by a
-- wall of exactly even thickness with four right angles in it. On a plain that frame is the most
-- prominent thing on the screen, and what it says is ARCHITECTURE -- somebody built this, and squarely.
-- Six of the seven grounds mean the opposite: ground ends where it happens to end.
--
-- So the frame is given a COASTLINE: the wall's inner face wanders in and out along its whole length,
-- in headlands and bays, and the four corners stop being corners. THE TILES STAY SQUARE -- what stops
-- being square is the line they make.
--
-- The wander is a walk rather than noise, and that is the whole of why it reads as landform. The first
-- version of this pass was the cavern carve's own rule -- fill the band with noise, smooth it with the
-- 5-neighbour test -- and on a plain it ate the entire band and handed back a smaller rectangle. Noise
-- smoothed against a straight wall does not make a coast; it makes the wall thicker, because every tile
-- against the frame already has three solid neighbours before the noise says anything. A depth that
-- walks up and down carries its own history instead, so the wall is two thick here and five there and
-- neither is where the last one was.
--
-- NOTHING IS EVER CUT OFF, which is what lets one pass run over every layout instead of seven. A bite is
-- taken only where the trail can still get around it, so the same rule reads as a deep bay on a plain
-- (where almost every border tile is spare) and as barely a nibble in a maze (where a 1-wide corridor is
-- all cut vertices). A dead end is spared outright: it is the thing a boon sits on, and the pass is here
-- to eat redundancy and nothing else.
--
-- Skipped by a layout that means its outline -- see `ownsEdge`. A fortress wall was built square.

-- How many tiles out of the play area the coast takes, at its shallowest and at its deepest. It never
-- takes NONE: a stretch at depth 0 is a stretch of the original frame, straight and square and exactly
-- as long as the walk happened to hold there, which is the one shape this pass exists to prevent.
local EDGE_SHALLOW, EDGE_DEEPEST = 1, 4
local EDGE_RUN = 6     -- how many tiles it holds one depth before it may step again: the size of a headland
local EDGE_NICK = 0.16 -- chance a single tile is taken one deeper than the run it sits in
-- What the coast costs a side, on average, and therefore what generate() adds to the rectangle before
-- handing it to the carve so the pass can eat it back (see the sizing in Overworld.generate, and
-- `grid.coast`, which is this or 0 for a ground that keeps its square outline). A field rather than a
-- local because it is read up there, where a local declared down here would be a nil global. Measured
-- off `. board-report`, not derived: the walk's mean depth is a shade over two.
Overworld.EDGE_SURPLUS = 2
-- Which way the next step goes. Weighted shallow, or a walk that is free to climb spends most of its
-- length at the deep end and the pass becomes a uniform trim again -- which is the rectangle it is here
-- to get rid of, one ring further in.
local EDGE_INWARD = 0.36   -- chance the coast steps one deeper
local EDGE_OUTWARD = 0.46  -- chance it steps one back toward the frame (the rest holds)
-- How far a detour may run for a bite to count as safe. Connectivity is checked in a window rather than
-- over the whole board because this is asked a few hundred times per map: a route found inside the
-- window is a real route, so the check is conservative in the only direction that matters -- a tile the
-- trail can only get around by a longer way than this is left alone rather than wrongly eaten.
local EDGE_REACH = 5

-- Can (x, y) be filled in without stranding anything? Its walkable neighbours have to still reach each
-- other with it gone, looked for inside a EDGE_REACH window.
function Overworld:biteSafe(x, y)
    local from = self:pathNeighbors(x, y)
    if #from < 2 then return false end -- a dead end (or an island): never eaten, see above
    local blocked = self:cellKey(x, y)
    local seen = { [blocked] = true, [self:cellKey(from[1].x, from[1].y)] = true }
    local q, qi, found = { from[1] }, 1, 1
    while qi <= #q do
        local cur = q[qi]; qi = qi + 1
        for _, n in ipairs(self:pathNeighbors(cur.x, cur.y)) do
            local k = self:cellKey(n.x, n.y)
            if not seen[k] and math.abs(n.x - x) <= EDGE_REACH and math.abs(n.y - y) <= EDGE_REACH then
                seen[k] = true
                q[#q + 1] = n
                for i = 2, #from do
                    if n == from[i] then found = found + 1 end
                end
                if found == #from then return true end
            end
        end
    end
    return false
end

-- One side's coastline: how many tiles of ground the wall takes at each step along its length. Two
-- scales at once, because one alone is not a landform:
--
--   the WALK    a depth that holds for a run of tiles and then steps, which is the headland-and-bay
--               shape, and the reason the wall is two thick here and five there;
--   the NICK    a single tile taken here and there off whatever the walk said, which is what keeps a
--               long run from arriving as a drawn straight line.
function Overworld:coastDepths(len)
    local out = {}
    local d = self.rng:random(EDGE_SHALLOW, EDGE_DEEPEST)
    local run = 0
    for i = 1, len do
        if run <= 0 then
            local roll = self.rng:random()
            if roll < EDGE_INWARD then
                d = math.min(EDGE_DEEPEST, d + 1)
            elseif roll < EDGE_INWARD + EDGE_OUTWARD then
                d = math.max(EDGE_SHALLOW, d - 1)
            end
            run = self.rng:random(2, EDGE_RUN)
        end
        run = run - 1
        out[i] = (self.rng:random() < EDGE_NICK) and math.min(EDGE_DEEPEST, d + 1) or d
    end
    return out
end

function Overworld:weatherEdges()
    local m = self.margin
    local x0, x1 = 1 + m, self.cols - m
    local y0, y1 = 1 + m, self.rows - m
    -- A play area with no middle left is not weathered: the coast would meet itself.
    if x1 - x0 < EDGE_DEEPEST * 2 + 2 or y1 - y0 < EDGE_DEEPEST * 2 + 2 then return end

    -- Fill in one tile of coast, unless the trail needs it (see biteSafe).
    local function bite(x, y)
        if self:typeWalkable(self.cells[y][x].tile) and self:biteSafe(x, y) then
            self.cells[y][x].tile = "thicket"
        end
    end

    -- Each side eats inward from the frame, so a bite is always taken from ground that has wall already
    -- against it and the coast recedes rather than opening holes behind itself. The corners are where two
    -- of these walks overlap, which is exactly why they stop reading as corners.
    local top, bottom = self:coastDepths(x1 - x0 + 1), self:coastDepths(x1 - x0 + 1)
    for x = x0, x1 do
        for k = 0, top[x - x0 + 1] - 1 do bite(x, y0 + k) end
        for k = 0, bottom[x - x0 + 1] - 1 do bite(x, y1 - k) end
    end
    local left, right = self:coastDepths(y1 - y0 + 1), self:coastDepths(y1 - y0 + 1)
    for y = y0, y1 do
        for k = 0, left[y - y0 + 1] - 1 do bite(x0 + k, y) end
        for k = 0, right[y - y0 + 1] - 1 do bite(x1 - k, y) end
    end
end

-- Maze nodes sit on a lattice inset from the map edge by `margin` and spaced
-- `spacing` apart, so no corridor endpoint (and thus no path) ever lands in the
-- buffer ring. A method rather than a file-local because the lattice layouts live
-- outside this file now (models/layouts/) and carve through this API.
function Overworld:isNode(x, y)
    local m = self.margin
    return x >= 1 + m and y >= 1 + m
        and x <= self.cols - m and y <= self.rows - m
        and (x - (1 + m)) % self.spacing == 0
        and (y - (1 + m)) % self.spacing == 0
end

-- Stable integer key for a position, exposed for the same reason: a layout wants a set of visited
-- nodes and should not have to know how this file indexes cells.
function Overworld:cellKey(x, y) return y * 100000 + x end

-- Open a rough disc of `tile` around (cx, cy). The clearing primitive: a maze carves corridors, and a
-- ground that means to hold a battle carves rooms. Jittered off the grid's own rng so a clearing has a
-- ragged edge rather than reading as a stamped circle -- and so it stays reproducible from the seed.
function Overworld:carveBlob(cx, cy, radius, tile)
    tile = tile or "path"
    for dy = -radius, radius do
        for dx = -radius, radius do
            if dx * dx + dy * dy <= radius * radius + self.rng:random() * radius then
                local c = self.cells[cy + dy] and self.cells[cy + dy][cx + dx]
                if c and cx + dx > self.margin and cy + dy > self.margin
                    and cx + dx <= self.cols - self.margin and cy + dy <= self.rows - self.margin then
                    c.tile = tile
                end
            end
        end
    end
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
-- Carve an L from (ax, ay) to (bx, by): along x, then along y. THE STRAIGHT-LINE VERSION BELOW IS NOT
-- SAFE FOR ARBITRARY PAIRS -- it steps both axes at once and only stops when both match, so a pair that
-- is not axis-aligned walks off the grid diagonally and indexes nil. That was fine while the only caller
-- was a lattice maze joining neighbouring nodes; it is not fine for a layout stitching two pockets
-- together, which is exactly how the volcanic ground first failed (and failed as an apparent HANG,
-- because LÖVE draws the error and waits for a window that a headless tool never shows).
function Overworld:carveElbow(ax, ay, bx, by)
    self:carveCorridor(ax, ay, bx, ay)
    self:carveCorridor(bx, ay, bx, by)
end

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

-- How much of a dead-end lattice gets a loop carved back through it. Lives here rather than in
-- models/layouts/maze.lua because docs/overworld.md names it as the board's most load-bearing constant
-- and every lattice layout is tuned against the same value; the maze reads it off the grid as
-- `braidRate`. See that file's header for the measurement behind 0.20 and why raising it is expensive.
Overworld.BRAID = 0.20

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

-- A CHANNEL LAID ACROSS WALKABLE GROUND IS A CROSSING, whatever that ground is made of. The test used to
-- name the two tiles a carve was known to lay a trail out of, `path` and `bridge`, and that was the same
-- statement while those were the only walkable types a map ever held. The swamp broke it: drowned trail
-- stands under shallows (models/layouts/drowned.lua lays `water`, wadeable at double cost), so a river
-- crossing a pool fell through to the else and turned a walkable tile into an impassable one. It is the
-- wettest ground in the game -- two to four rivers over a third of the trail flooded -- and EVERY swamp
-- board came out in pieces, four in ten of its walkable tiles stranded behind water that should have been
-- a plank. Asking walkability instead says the rule the comment above always claimed, and changes nothing
-- anywhere else: no other layout that runs the shared river pass lays a walkable tile that is not trail.
function Overworld:markRiver(x, y)
    local c = self.cells[y] and self.cells[y][x]
    if not c then return end
    c.river = true
    if self:typeWalkable(c.tile) then
        c.tile = "bridge"
        c.bridge = true
    else
        c.tile = "river"
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
            if c.tile == "thicket" then
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

-- Manhattan distance between two cells. Used to keep a board's several ends apart; the walking
-- distance would be truer and costs a BFS per candidate, and what this is guarding against -- two
-- objectives on adjacent spurs off the same corridor -- is a thing straight-line distance already sees.
local function apart(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

-- Objectives (usually bosses) + the lock/key chain that gates the deepest of them. Keys are placed
-- strictly inside the region reachable *before* the first gate, so they are
-- always collectible in order and the objective is always reachable once held.
--
-- A BOARD CARRIES AS MANY ENDS AS THE DAY HAS WORK IN IT. `params.objectives` is a list -- one entry
-- per quest the ground is offering (models/quest.lua's Quest.trip) -- and a lone `params.objective` is
-- read as a one-entry list, which is what every authored leg and every descent floor still passes.
--
-- Each end takes its own strict dead end, deepest first and spread apart, because a dead end is what
-- makes an objective gateable and what stops it being stumbled over on the way somewhere else. Two
-- objectives on neighbouring spurs would read as one place with two doors.
function Overworld:placeObjectiveAndGates(params)
    -- A layout may name both ends itself (see models/layout.lua's `anchors`). The rules below find them
    -- by shape, which is the right question on ground you are crossing and the wrong one in a room.
    local named, namedObjective
    local layout = Layout.get(self.layoutId)
    if layout.anchors then named, namedObjective = layout.anchors(self) end

    local start = named or self:computeStart()
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
    -- ...AND THE END HAS TO BE SOMEWHERE THE FIGHT CAN HAPPEN, which for a long time it did not have to
    -- be. Every rule above and below this one is about GATEABILITY -- a strict dead end is what makes an
    -- objective lockable and what stops it being stumbled over -- and gateability was allowed to be the
    -- only question asked. It is the wrong only question now that a fight is taken on these very tiles:
    -- a spur tip is the least arena-shaped tile a board has, and the one fight the player cannot decline
    -- was being seated on the worst of them by rule. Rolled boards, before this: the objectives of a
    -- forest board stood on 3.5 tiles of open ground out of 64, a swamp's on 4.5, against a floor of 16.
    -- That is a floor guardian fought in a defile, four bodies deep in a queue, and it is what the
    -- fightability ledger could not see because it was counting combat and elite only.
    --
    -- So room is a FILTER over the candidates and not a new scoring term. The distance rules keep their
    -- exact meaning -- the band on a ground, the peak on a climb -- they just run over the ends that can
    -- hold the fight rather than over all of them.
    --
    -- AND THE FALLBACK IS GRADED, because "fall back to all of them" is not one behaviour, it is the old
    -- one. A tight board would hand the distance rule the whole spur list again and it would happily
    -- return a pocket of twelve crossable tiles on a board carrying a hundred and ten open ones, which is
    -- worse than anything the filter was written to prevent. Three tiers, each a strictly weaker claim
    -- than the one above:
    --
    --   1  clears both floors -- an arena. The distance rule decides among them.
    --   2  clears the space floor only -- room to stand, if not to flank. Distance decides again.
    --   3  neither: take the roomiest spur on the board outright, ties to the deeper one. Distance stops
    --      being a preference here because there is nothing left to prefer it over -- every candidate is
    --      a bad board and the only question is which is least bad.
    local sums, openSums = self:walkableSums(), self:openSums()
    local roomy, standable = {}, {}
    for _, e in ipairs(deadEnds) do
        local ok, cross = self:seatsFight(e.cell.x, e.cell.y, sums, openSums)
        if ok then roomy[#roomy + 1] = e end
        if cross >= Overworld.BOX_OK then standable[#standable + 1] = e end
    end
    -- On an ASCENT map the objective is the PEAK: the farthest dead-end there is, not a comfortable
    -- one in the top band. The marathon this band exists to avoid is exactly what a climb is for --
    -- the road has to run out, and the thing at the end of it has to be the last thing.
    local pick, pickScore
    local ends = (#roomy > 0 and roomy) or (#standable > 0 and standable) or deadEnds
    -- Tier 3: nothing on this board can hold a fight, so distance stops deciding and room decides
    -- outright. Sorted rather than filtered, so every rule below -- the band, the peak, the farthest
    -- fallback, the spread the extra ends are held at -- reads the same list in the same order.
    if #roomy == 0 and #standable == 0 then
        local score = {}
        for _, e in ipairs(ends) do
            local cross, open = self:roomAt(e.cell.x, e.cell.y, sums, openSums)
            score[e] = open * 100 + cross
        end
        table.sort(ends, function(a, b)
            if score[a] ~= score[b] then return score[a] > score[b] end
            if a.d ~= b.d then return a.d > b.d end
            if a.cell.y ~= b.cell.y then return a.cell.y < b.cell.y end
            return a.cell.x < b.cell.x
        end)
        pick = ends[1] and ends[1].cell
    end
    if pick then -- decided above; the distance rules have nothing left to choose between
    elseif params.ascent then
        for _, e in ipairs(ends) do -- score is distance: take the highest
            if not pickScore or e.d > pickScore then pickScore = e.d; pick = e.cell end
        end
    else
        local band, want = maxDist * 0.7, maxDist * 0.8
        for _, e in ipairs(ends) do -- score is error against the band: take the lowest
            if e.d >= band then
                local err = math.abs(e.d - want)
                if not pickScore or err < pickScore then pickScore = err; pick = e.cell end
            end
        end
        -- The band is measured against the WHOLE board and `ends` is a subset of it, so a board whose
        -- only arenas sit nearer than 70% of the reach clears the filter and then finds nothing inside
        -- the band. Take the deepest one there is rather than falling through to a defile at the right
        -- distance: how far the objective sits is a preference, whether it can be fought is not.
        if not pick then
            for _, e in ipairs(ends) do
                if not pickScore or e.d > pickScore then pickScore = e.d; pick = e.cell end
            end
        end
    end
    -- The objective MUST land on a strict dead-end, or its spine gate can simply be walked around (a
    -- degree-2 tile has a second route the gate never covers). On a compact, braided board the top
    -- distance band can hold no dead-end at all; when it doesn't, fall back to the FARTHEST dead-end
    -- there is rather than a plain far tile, and only accept a non-dead-end if the map has none.
    local farDeadEnd, farDeadD
    for _, e in ipairs(ends) do -- the roomy ones when there are any, exactly as above
        if not farDeadD or e.d > farDeadD then farDeadD = e.d; farDeadEnd = e.cell end
    end
    objective = namedObjective or pick or farDeadEnd or objective

    -- THE ENDS TO PLACE. One spec per piece of work on this ground; the single-objective callers
    -- (every authored leg, every descent floor) come through here as a list of one, so the deepest end
    -- is chosen by exactly the rule above and nothing about those boards moves.
    local specs = params.objectives
    if not (specs and #specs > 0) then specs = { params.objective or {} } end

    local chosen, claimed = { objective }, { [cellKey(objective)] = true }

    -- The rest, in descending depth, each held away from the ends already placed. The spread starts at
    -- a quarter of the board's reach and halves until something qualifies -- a relaxing threshold
    -- rather than a fixed one, because a compact braided board may genuinely have no far-apart pair and
    -- a crowded end still beats no end at all.
    --
    -- Room relaxes LAST, after the spread has run all the way down. Every end on this board is a fight
    -- somebody has to take, so a second one seated in a defile is the same failure as the first; the
    -- order says a crowded pair of arenas beats a well-spread pair of corridors.
    for i = 2, #specs do
        local best, bestD
        local wantRoom = #ends < #deadEnds -- only a real narrowing is worth relaxing back out of
        local spread = maxDist * 0.25
        while not best and spread >= 1 do
            for _, e in ipairs(wantRoom and ends or deadEnds) do
                if not claimed[cellKey(e.cell)] then
                    local ok = true
                    for _, c in ipairs(chosen) do
                        if apart(e.cell, c) < spread then ok = false break end
                    end
                    if ok and (not bestD or e.d > bestD) then best, bestD = e.cell, e.d end
                end
            end
            spread = spread / 2
            if not best and spread < 1 and wantRoom then
                wantRoom, spread = false, maxDist * 0.25 -- out of arenas: take a spur anywhere
            end
        end
        -- NO DEAD END LEFT. Rather than dropping the quest -- a piece of work the player travelled for,
        -- silently absent from the board -- it takes the farthest unclaimed walkable tile there is, and
        -- says so: `. board-report` counts these, because a board that keeps doing it is a board whose
        -- sizing rule has stopped keeping up with what a ground can hold (see deriveDims).
        if not best then
            self.crowdedEnds = (self.crowdedEnds or 0) + 1
            local farD
            for y = 1, self.rows do
                for x = 1, self.cols do
                    local c = self.cells[y][x]
                    local d = dist[cellKey(c)]
                    if self:typeWalkable(c.tile) and d and not claimed[cellKey(c)]
                        and c ~= start and (not farD or d > farD) then
                        farD, best = d, c
                    end
                end
            end
        end
        if best then
            chosen[#chosen + 1] = best
            claimed[cellKey(best)] = true
        end
    end

    -- Stamp them. The cell carries the quest ID and nothing else of the spec: a spec may hold a
    -- composition FUNCTION (the finale sizes itself by how many generals are still standing) and the
    -- board is serialized whole into the save, which has to stay plain data. states/game.lua looks the
    -- spec back up by this id when the tile is engaged.
    self.objectives = {}
    for i, cell in ipairs(chosen) do
        local spec = specs[i] or {}
        cell.encounter = { kind = "objective", name = spec.name or "Objective", questId = spec.questId }
        self.objectives[i] = { x = cell.x, y = cell.y, questId = spec.questId }
    end
    -- The deepest end, still under its old name. Everything that wants "the far end of this board" as a
    -- single tile -- the camera's opening pan, the report tools, an authored layout's own anchor --
    -- reads this, and on a one-quest board it is the only end there is.
    self.objective = self.objectives[1]

    -- Spine: each objective -> ... -> start (via BFS parents) = the critical paths, unioned. Persisted
    -- as a set of cell keys so encounter placement can keep skippable combats OFF them -- a wounded
    -- party must always be able to route around to any of the ends. Built unconditionally, even with no
    -- keys. The road home is a road NETWORK now, and the rule reads the same across all of it.
    local spine = {}
    self.spineKeys = {}
    for i, endCell in ipairs(chosen) do
        local path = {}
        local cur = endCell
        while cur do
            path[#path + 1] = cur
            self.spineKeys[cellKey(cur)] = true
            cur = parent[cellKey(cur)]
        end
        -- The deepest end's own path is the one an ascent measures itself along (below), so it is the
        -- one kept ordered.
        if i == 1 then spine = path end
    end

    -- The deepest path as an ORDERED walk, start -> objective: `spineKeys` answers "is this tile on the
    -- road", which is all the skippable-combat rule needs, but an ascent has to answer "how far ALONG
    -- the road is this" to space a climb out over its length (see placeEncounters' ascent branch). An
    -- ascent is a climb to ONE peak by construction, so the deepest end is the right one to measure.
    self.spineCells = {}
    for i = #spine, 1, -1 do self.spineCells[#self.spineCells + 1] = spine[i] end

    local K = params.keyCount or 0
    if K <= 0 then return end
    -- A GATE ON OPEN GROUND IS NOT A GATE. The objective is meant to land on a strict dead end so the
    -- tiles before it genuinely lock it, and the fallbacks above will accept a through-tile rather than
    -- fail -- on a board that has no dead end at all, or on one whose layout names its own objective and
    -- puts it in the middle of the floor (models/layouts/sands.lua). Locking a tile you can walk around
    -- there costs the player a key hunt and gates nothing, so the chain is skipped instead. The board
    -- keeps its spine, its caches and its guards; what it does not get is a door that is not one.
    if #self:pathNeighbors(objective.x, objective.y) > 1 then return end

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

-- ---------------------------------------------------------------------------
-- Secret doors: ground the fog does not lift by being walked past
-- ---------------------------------------------------------------------------

-- HOW MANY a floor hides.
--
-- Small. A secret is worth having because finding one is a surprise; a floor with six of them is a floor
-- where searching is a chore you perform against every wall, which is the failure mode Wizardry's own
-- later entries fell into. Two or three is enough that a player learns the floor MIGHT be hiding
-- something and never enough that hunting becomes the game.
Overworld.SECRETS = { min = 2, max = 3 }

-- HOW DEEP THE HIDDEN GROUND RUNS, and it is not a constant -- it is whatever the WALL will hold.
--
-- This was a constant (3 to 5 tiles) and it produced no secrets at all, on any seed, for a reason worth
-- writing down: a lattice carve leaves walls exactly `spacing - 1` tiles thick, so on the descent's
-- original spacing of 2 there was ONE tile of rock between every pair of corridors and nowhere to put a
-- corridor of three. The dig always broke through into ground the player had already walked, which the
-- solidity check correctly refused, every time.
--
-- So the depth is derived: dig into the wall and stop one tile short of whatever is on the far side.
-- At spacing 3 that is a single sealed tile -- an alcove -- and at 4 or 5 it is a short corridor. Both
-- are secrets; what neither can be is a shortcut, which is the property that actually matters (see
-- placeSecrets on why a door joining two known corridors is a different, lesser thing).
function Overworld:secretDepth()
    return math.max(0, (self.spacing or 4) - 2)
end

-- Hide a few spurs behind a door that reads as wall until it is found.
--
-- WHAT A SECRET DOOR IS HERE. One tile, carved walkable and marked `secret` -- and while it is secret,
-- Overworld:reveal refuses to light it OR anything beyond it, so the corridor it opens onto stays black
-- however close the company walks. Finding it (Overworld:findSecrets) clears the mark and the fog lifts
-- through it like any other ground.
--
-- CARVED INTO DEAD WALL, never onto the existing trail. The door is dug from a spur end outward into
-- fill, so the ground behind it exists nowhere else on the board -- which is the whole difference
-- between a secret and a shortcut. A door that joined two corridors the player had already walked would
-- be a discovery about the map's topology; this is a discovery about what is ON it.
--
-- Deliberately AFTER the encounters and the caches are placed, so the hidden ground is empty when it is
-- dug and gets its reward from Overworld:placeSecretRewards below rather than by competing for the
-- board's own stops -- a secret that hid an ordinary fight would be a fight the player never found.
function Overworld:placeSecrets(params)
    if not params.secrets then return end
    local depth = self:secretDepth()
    -- A board whose walls are one tile thick has nowhere to hide anything. Refused outright rather than
    -- digging a door that opens onto a corridor the player already walked, which is a shortcut wearing a
    -- secret's clothes -- and worse than no secret, because it teaches that looking is pointless.
    if depth < 1 then return end
    local n = resolveCount(Overworld.SECRETS, self.rng)

    -- Spur ends, which is where a door can be dug without cutting into the road network.
    local ends = {}
    for y = 1 + self.margin, self.rows - self.margin do
        for x = 1 + self.margin, self.cols - self.margin do
            local c = self.cells[y][x]
            if self:typeWalkable(c.tile) and not c.encounter and #self:pathNeighbors(x, y) == 1 then
                ends[#ends + 1] = c
            end
        end
    end
    for i = #ends, 2, -1 do
        local j = self.rng:random(i)
        ends[i], ends[j] = ends[j], ends[i]
    end

    self.secretCells = {}
    for _, from in ipairs(ends) do
        if #self.secretCells >= n then break end
        -- Dig AWAY from the spur's own corridor: the one open neighbour is where it came from, so the
        -- opposite direction is the wall the door goes into.
        local back = self:pathNeighbors(from.x, from.y)[1]
        local dx, dy = from.x - back.x, from.y - back.y

        -- Check the whole run is solid fill before cutting any of it. A half-dug secret that broke into
        -- an existing corridor would be a door onto ground the player has already seen.
        local ok, run = true, {}
        for step = 1, depth do
            local c = self:get(from.x + dx * step, from.y + dy * step)
            if not c or c.tile ~= "thicket"
                or from.x + dx * step <= self.margin or from.y + dy * step <= self.margin
                or from.x + dx * step > self.cols - self.margin
                or from.y + dy * step > self.rows - self.margin then
                ok = false
                break
            end
            run[#run + 1] = c
        end
        if ok and #run >= depth then
            for i, c in ipairs(run) do
                c.tile = "path"
                -- Only the FIRST tile is the door. The rest is ordinary corridor that simply cannot be
                -- reached or seen until the door is open.
                if i == 1 then c.secret = true end
            end
            self.secretCells[#self.secretCells + 1] = run[1]
            run[#run].secretEnd = true
        end
    end
end

-- What is at the end of a hidden spur. A cache, always, and a fat one.
--
-- A CACHE RATHER THAN A STOP, and it matters. Every other kind on the board is a thing that opens a
-- panel and asks something -- a fight, a shelf, a slate of relics -- and a hidden one would be content
-- the player is likely never to see, which is content wasted. A cache PAYS, immediately, on a tile
-- nobody had to be persuaded onto: it is the reward for having looked, and its whole job is to make the
-- next dead end worth walking down.
--
-- Paid at the TOP of the cache band rather than scaled by detour like the board's own (placeCaches).
-- The ordinary rule prices a cache by how far off the road it sits, which is a proxy for what it cost
-- you to reach; a secret's real cost is not distance but having looked at all, and distance cannot see
-- that. So the payout is flat and generous, and the reason it can be is that there are only two or three
-- of them and they are the one thing on the floor a player can walk past forever.
Overworld.SECRET_CRAFT = 6
Overworld.SECRET_HOUSE = 5

function Overworld:placeSecretRewards(params)
    if not self.secretCells or #self.secretCells == 0 then return end

    local grades = Material.craftGrades()
    local houses = params.houseMaterials
    if not houses or #houses == 0 then
        houses = params.houseMaterial and { params.houseMaterial } or {}
    end

    -- One sweep over the board: every tile a secret run marked as its end takes a cache and drops the
    -- mark. `secretEnd` is generation-only scaffolding and is deliberately not in CELL_FIELDS, so it
    -- never reaches a save either way -- clearing it here keeps a re-generated board honest all the same.
    local i = 0
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            if c.secretEnd then
                c.secretEnd = nil
                if not c.cache then
                    i = i + 1
                    local materials = {}
                    -- The deepest craft grade the board deals, since this is the deepest thing on it.
                    materials[grades[#grades]] = Overworld.SECRET_CRAFT
                    local house = houses[((i - 1) % math.max(1, #houses)) + 1]
                    if house then
                        materials[house] = (materials[house] or 0) + Overworld.SECRET_HOUSE
                    end
                    c.cache = { materials = materials, house = house }
                end
            end
        end
    end
end

-- Is (x, y) sealed behind a secret door the party has not found? Read by reveal, so hidden ground stays
-- black; movement is NOT gated on it, because the door tile is solid-looking wall the player has no
-- reason to walk into until they have found it -- and once found, it is ordinary trail.
function Overworld:isHidden(cell)
    return cell ~= nil and cell.secret == true
end

-- Search the ground around (cx, cy) for a door. Returns the cell found, or nil.
--
-- ADJACENCY, NOT A ROLL. Wizardry makes you stand at a wall and press Search, sometimes for several
-- turns, and the turns are the cost. There is no turn economy on this board to spend -- so the cost is
-- being THERE: a door is found by having walked to the tile beside it, and a company that never goes
-- down the dead end never finds it. That makes exploring the reward rather than a dice roll, which is
-- also what stops it becoming a chore performed on every wall.
function Overworld:findSecrets(cx, cy, radius)
    radius = radius or 1
    local found
    for y = cy - radius, cy + radius do
        for x = cx - radius, cx + radius do
            local c = self:get(x, y)
            if c and c.secret then
                c.secret = nil
                found = found or c
            end
        end
    end
    return found
end

-- THE WAY BACK UP, standing on the tile the party walked in on.
--
-- A campaign ground has no such thing and does not want one: a quest is left by pressing Back, the
-- company goes home with everything it picked up, and the day is the only thing spent (states/game.lua's
-- toHub). Leaving is free, so a tile that offered it would be a tile that offered nothing.
--
-- A DESCENT FLOOR IS THE OTHER CASE, and this is the whole of Wizardry's pacing engine. There, an
-- expedition ends by WALKING BACK to the stair you came down by -- so how deep you push is bounded by
-- how far you are willing to be from the way out, and the return trip is real ground you have to have
-- something left for. Abandoning from where you stand is still possible and still costs the company;
-- what this tile adds is the ending that does not.
--
-- Seated as an `encounter` on the start cell rather than as a field of its own, and the reason is the
-- whole pipeline it buys: the marker draws, the fog hides and reveals it, walking onto it engages
-- through the same seam every other stop uses, and the run save carries it in `cells` with the rest.
-- A field would have needed all four written again.
--
-- Placed LAST, after every other pass, so it cannot displace a stop or be counted as one: the encounter
-- budget, the combat share and the tier pass have all finished by the time this runs. The start tile is
-- kept clear of stops by placeEncounters anyway, so there is nothing here to overwrite.
function Overworld:placeExit(params)
    if not params.exitAtStart then return end
    local start = self:startCell()
    if not start or start.encounter then return end
    start.encounter = { kind = "ascent", name = "The Way Up" }
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

-- Scatter material caches onto the dead ends, FIRST -- before placeEncounters, so the rewards get their
-- pick of the spur ends and the fights fill the corridors leading to them (see guardBoons).
--
-- This order used to be the other way round, and the reasoning it carried was the opposite one: an
-- encounter was "the better payoff for a spur", and caches paid out the dead ends nothing else claimed.
-- That made a fight and a reward ALTERNATIVES competing for the same tile. They are a pair now -- the
-- boon at the end, the fight in the way -- which only works if the boon is placed where a corridor can
-- gate it. Still runs BEFORE pruneDeadStubs, which treats a cache as reason enough to keep a corridor
-- alive.
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

    -- A BOON PREFERS GROUND THAT CAN BE GATED.
    --
    -- The shuffle alone was right while every board was a maze, because there a boon's home is a spur end
    -- and the dead-end list did all the work. A board of rooms has NO degree-1 tiles at all -- the castle
    -- measures 0.00 dead ends -- so every cache comes out of this list, and a flat shuffle drops most of
    -- them in whichever chamber the road already runs through, where nothing gates them. Measured: 18.3%
    -- of the castle's boons guarded, on a carve that offers a doorway for every one of them.
    --
    -- Depth off the critical path is the cheap proxy for "behind something", and it is already computed
    -- for the payout scale, which wants the same thing: the far chamber is the one you reach through a
    -- door. The shuffle survives as the tie-break, so boons at equal depth still move between seeds.
    --
    -- Not to be confused with an earlier attempt at this that made things WORSE (6.1%): that one ran while
    -- a guard could only be seated within eight tiles of what it protected, so pushing caches deeper
    -- pushed them out of every guard's reach. The reach is a room-crossing now and depth is free to help.
    local spineDist = self:spineDistances()
    local shuffled = {}
    for i, c in ipairs(spare) do shuffled[c] = i end
    table.sort(spare, function(a, b)
        local da, db = spineDist[cellKey(a)] or 0, spineDist[cellKey(b)] or 0
        if da ~= db then return da > db end
        return shuffled[a] < shuffled[b]
    end)

    -- ...AND, AMONG THE SPURS, THE ONES WHOSE DOOR IS A ROOM.
    --
    -- The same argument as the sort above, carried one step further, and it became necessary the moment
    -- a guard had to be able to FIGHT where it stands (Overworld.BOX_OPEN). Every dead end can be gated
    -- -- that is what a dead end is -- so "prefers ground that can be gated" no longer separates
    -- anything, and the question that decides whether this cache ends up behind a fight is now whether
    -- the tile that gates it is an arena or a hallway. A maze has plenty of both and the shuffle was
    -- picking between them blind: forest guarded 96% of its boons on paper and 16% in fact.
    --
    -- The dead end's single neighbour is the proxy, not the answer -- guardBoons re-asks the real
    -- question, exactly, and may walk further back for a better door. A proxy is the right instrument
    -- here anyway: this pass runs before the fights exist, so it is choosing where a pairing COULD
    -- happen, and being right about most of them is what the ordering is for.
    --
    -- Stable within each group, so a spur's position still comes off the shuffle and a seed reproduces
    -- its board.
    local roomy, tight = {}, {}
    do
        local sums, opens = self:walkableSums(), self:openSums()
        for _, c in ipairs(deadEnds) do
            local n = self:pathNeighbors(c.x, c.y)[1]
            if n and self:seatsFight(n.x, n.y, sums, opens) then
                roomy[#roomy + 1] = c
            else
                tight[#tight + 1] = c
            end
        end
    end

    -- Dead ends first, then off-spine tiles: a board that braided all its spurs away still pays, it
    -- just pays somewhere the player was more likely to pass anyway.
    local cands = {}
    for _, c in ipairs(roomy) do cands[#cands + 1] = c end
    for _, c in ipairs(tight) do cands[#cands + 1] = c end
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

    -- WHOSE STOCK THE CACHES CARRY. One house, or several, and the several is the interesting case.
    --
    -- `houseMaterial` was a single id -- the sponsoring house of the one quest being run. A day can now
    -- carry requests from several houses at once (models/request.lua), and this is where that becomes a
    -- decision rather than a list: the caches are DEALT ROUND-ROBIN across the houses asking, over the
    -- caches the board already has.
    --
    -- The board does not grow to fit them. That is the whole tension. Three houses against four or five
    -- caches means no single trip fills every quota, so "which spur do I still have the health for" is
    -- a real question with several partial answers -- which is what the deadline needed and what one
    -- house per board could never produce.
    --
    -- Dealt in cache order, and the caches are already sorted by detour depth (dead ends first, then
    -- off-spine), so the houses take turns at the near ones and the far ones alike rather than one
    -- house owning the easy end of the board.
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
-- Guarded boons
-- ---------------------------------------------------------------------------

-- What share of a board's boons stand behind a fight. Not all of them, deliberately: an unbroken "every
-- reward has a guard" rule turns the map into a checklist and teaches the player to read markers instead
-- of the board. The loose remainder is what keeps a find on the road feeling like a find.
local GUARDED_BOON_SHARE = 0.8

-- How far back from a boon a guard may stand and still read as guarding it. Generous enough to cross a
-- chamber, because on a board of rooms the gate is the DOOR and a cache in the far corner of a hall is
-- ten tiles from it -- and you can see the door from there, which is what makes it an offer. Short of a
-- room-crossing it stops being one: a cut vertex twenty tiles back is just a fight somewhere else.
local GUARD_REACH = 16

-- What can be guarded: the FINDS, never the services. A shop behind a fight is friction rather than
-- tension, and a rest is the pressure valve the attrition model needs -- gating the one stop that gives
-- resources back would compound exactly the wrong way. A `cache` is a tile property, not an encounter,
-- so it is checked separately below.
local GUARDABLE_KINDS = { treasure = true, relic_cache = true }

-- What a guarded cache pays on top of what the detour already earned it, so the fight in the way is a
-- PRICE and not a tax. Capped by the same ceilings the detour scale honours (see placeCaches).
local GUARD_CRAFT_BONUS, GUARD_HOUSE_BONUS = 1, 1

-- The board's difficulty arc, as two rules. Applied in placeEncounters' fill loop, and RESPECTED again
-- by guardBoons below, which is free to pick a seated fight up and put it down somewhere else.
--
-- ELITE_SHARE is to rank what `combatShare` is to kind: a ceiling the pool's weights cannot argue with.
-- It exists because a blueprint weight is authored per encounter with no view of the others, so one
-- entry written as "grows with prestige" silently became 76% of every board's fights.
--
-- ELITE_MIN_DEPTH is the arc itself: an elite is a thing you meet once the road has gone on a while.
-- Half is deliberately not two-thirds -- the deep half of a board is only two or three stops, and a
-- rule that fires on one tile is a coin flip rather than a curve.
--
-- Declared HERE, above the first function that reads them, and not beside GUARANTEE where the rest of
-- the placement knobs live. A file-local declared further down would be invisible to guardBoons and
-- would resolve to a nil global instead -- which compiles, loads, and only fails on the board where
-- the branch is finally taken.
local ELITE_SHARE = 0.25
local ELITE_MIN_DEPTH = 0.5

-- Stand a fight in front of the reward, so a spur is one offer made of two tiles rather than a fight OR
-- a payout. This is the tile-level shape of the whole overworld decision: the objective is the only
-- fight the player MUST take, every other fight is optional, and an optional fight should be attached to
-- something worth having.
--
-- Re-seats encounters that are ALREADY PLACED rather than adding any, so the encounter count the map was
-- sized around (deriveDims) does not move and the quest's authored pool is still exactly what it asked
-- for. Runs after placeEncounters and placeCaches -- both have had their pick of the board -- and before
-- pruneDeadStubs, which reads the final positions to decide which corridors earned their keep.
--
-- THE GATE IS FREE. A boon sits at the end of a degree-1 spur, so the tile you must cross to reach it is
-- a cut vertex: standing a fight there makes the boon genuinely unreachable without clearing it, with no
-- pathfinding beyond "which neighbour is closer to the spine". A boon hanging directly off the critical
-- path has its approach ON the spine and is left alone -- a wounded party must always be able to walk to
-- the objective, which is the rule that lets every other fight be optional in the first place.
--
-- ASCENT MAPS OPT OUT, as they do for the spine rule: there combat IS the route, so a fight standing in
-- front of a reward is not an offer, it is the road.
--
-- ...AND A DESCENT FLOOR OPTS BACK IN (`params.guardBoons`), because `ascent` turned out to be two
-- claims wearing one name. A floor sets it to get the FIRST -- the objective goes on the farthest dead
-- end there is, so the stair is the end of the road rather than a tile you stumble over
-- (placeObjectiveAndGates) -- and inherited the second by accident. Measured with `. board-report
-- descent`: not one reward on a descent floor was guarded, against 69% on a campaign ground, while the
-- report showed nine loose fights and three quarters of the boons standing on a gateable tile. The
-- supply and the geometry were both there and this early return was throwing them away.
--
-- A floor is not a climb. Its fights are optional stops around a stair, which is the exact shape the
-- guarded-boon rule exists for -- so the flag says so rather than the descent giving up the dead-end
-- objective to get its guards back.
function Overworld:guardBoons(params)
    if params and params.ascent and not params.guardBoons then return end
    if not self.spineKeys then return end
    local spineDist = self:spineDistances()
    -- Depth from the start, on the same scale placeEncounters seated by and assignEncounterTiers will
    -- report with, so all three passes agree about where the deep half of the road begins.
    local startDist, startParent = self:bfsDistances(self:startCell())
    local farthest = 1
    for _, d in pairs(startDist) do if d > farthest then farthest = d end end

    local function shuffle(t)
        for i = #t, 2, -1 do
            local j = self.rng:random(i)
            t[i], t[j] = t[j], t[i]
        end
    end

    -- Walked in a stable grid order first, then shuffled, so the run of boons left unguarded is not
    -- always the same corner of the board while the draw stays reproducible from the seed.
    local boons, guards = {}, {}
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            if self:typeWalkable(c.tile) then
                if c.cache or (c.encounter and GUARDABLE_KINDS[c.encounter.kind]) then
                    boons[#boons + 1] = c
                elseif c.encounter and (c.encounter.kind == "combat" or c.encounter.kind == "elite") then
                    guards[#guards + 1] = c
                end
            end
        end
    end
    shuffle(boons)
    shuffle(guards)

    -- Can the party still reach `goal` from the start with `blocked` treated as impassable? A guard is
    -- only a guard if the answer is no.
    --
    -- Checked EXACTLY, by walking the board, rather than inferred from the tile's shape. The tempting
    -- shortcut -- "take the neighbour closest to the critical path" -- silently assumes every boon sits
    -- at the end of a degree-1 spur, and that is not true: caches fall back to through-tiles once the
    -- dead ends run out, and a treasure or reliquary comes off the encounter pool onto whatever corridor
    -- it was dealt. On a braided board that shortcut produces a "guard" the player simply walks around,
    -- which is the worst outcome available -- the fight looks like a price and is not one. Boards are
    -- small and boons are few, so a handful of floods at generation time costs nothing.
    local function reachableWithout(goal, blocked)
        local start = self:startCell()
        if not start then return true end
        if start == goal then return true end
        local seen = { [cellKey(start)] = true }
        local q, qi = { start }, 1
        while qi <= #q do
            local c = q[qi]; qi = qi + 1
            for _, n in ipairs(self:pathNeighbors(c.x, c.y)) do
                if n == goal then return true end
                local k = cellKey(n)
                if not seen[k] and n ~= blocked then
                    seen[k] = true
                    q[#q + 1] = n
                end
            end
        end
        return false
    end

    local function seatable(c)
        return c and self:typeWalkable(c.tile) and not c.gate and not c.key and not c.cache
            and not self.spineKeys[cellKey(c)]
            and not (self.start.x == c.x and self.start.y == c.y)
            and not (self.objective and self.objective.x == c.x and self.objective.y == c.y)
    end

    -- A guarded cache reads above a loose one. The detour scale already pays the far spur best, which
    -- correlates with being guarded but is not the same thing -- so the guard is priced explicitly.
    local function payGuarded(c)
        if not c.cache or not c.cache.materials then return end
        local grades = Material.craftGrades()
        for _, g in ipairs(grades) do
            if c.cache.materials[g] then
                c.cache.materials[g] = math.min(CACHE_CRAFT_MAX, c.cache.materials[g] + GUARD_CRAFT_BONUS)
                break
            end
        end
        -- Whichever house's stock this cache carries, read off the cache rather than off `params`.
        -- With several houses dealt across a board (placeCaches) there is no single "the" house here,
        -- and asking params for one would have paid the bonus to a cache that does not hold it.
        local house = c.cache.house
        if house and c.cache.materials[house] then
            c.cache.materials[house] = math.min(CACHE_HOUSE_MAX, c.cache.materials[house] + GUARD_HOUSE_BONUS)
        end
    end

    -- Which neighbour of `boon` genuinely gates it. Adjacency is a legibility rule, not a correctness
    -- one -- any cut vertex on the corridor would do -- but standing the fight right beside what it
    -- guards is what makes the offer readable from the mouth of the spur. Ties are broken in grid order
    -- so a seed still reproduces its board exactly.
    -- Where several tiles all gate the boon, take the one with the most room to fight on. Gating is the
    -- requirement and is checked exactly; among tiles that all satisfy it, the box score is what decides,
    -- because a guard is a fight and a fight now happens where it stands. Grid order still breaks a true
    -- tie, so a seed reproduces its board.
    --
    -- Ranked on OPEN ground first and crossable ground second, which is the order the two floors are
    -- written in (Overworld.BOX_OPEN). A spur mouth is the likeliest tile on the board to be a corridor,
    -- so the choice between two doors is almost always a choice between a room and a hallway, and the
    -- walkable count cannot tell them apart -- it was picking hallways at the same rate as rooms while
    -- reading as though it had preferred something.
    --
    -- ...AND A DOOR TOO NARROW TO FIGHT IN IS NOT AN APPROACH AT ALL. This pass turned out to be where
    -- nearly all of a board's corridor fights came from, and by a wide margin: a one-end forest board
    -- put 92% of its fights on guard, so whatever care placeEncounters took choosing clearings was
    -- undone one pass later by lifting those same fights into doorways. Measured, 3.9 of 4.5 fights a
    -- board were seated under the shape floor and only 0.4 of them were the objective.
    --
    -- So the floor applies HERE TOO, and unlike placeEncounters there is no case for an escape hatch.
    -- Demoting there empties a board, because the alternative to a thin fight is no fight; refusing
    -- here costs nothing, because the fight is not created by this pass -- it already stands somewhere
    -- placeEncounters chose, and declining to move it leaves it in a clearing. An unguarded cache is a
    -- free pickup. A guarded one the player has to fight for in a hallway is the thing being fixed.
    --
    -- This is the same trade the rank rule below already makes in the same loop ("Leaving the boon open
    -- is also not a loss to the pass"), applied to the other half of what makes a guard a guard.
    local boxSums, openSums = self:walkableSums(), self:openSums()
    local function approachTo(boon)
        local best, bestOpen, bestCross
        for _, n in ipairs(self:pathNeighbors(boon.x, boon.y)) do
            if seatable(n) and not n.guards and not reachableWithout(boon, n)
                and self:seatsFight(n.x, n.y, boxSums, openSums) then
                local cross, open = self:roomAt(n.x, n.y, boxSums, openSums)
                if not best or open > bestOpen
                    or (open == bestOpen and cross > bestCross)
                    or (open == bestOpen and cross == bestCross
                        and (n.y < best.y or (n.y == best.y and n.x < best.x))) then
                    best, bestOpen, bestCross = n, open, cross
                end
            end
        end
        if best then return best end

        -- ON A BOARD OF ROOMS THE GATE IS THE DOOR, and a door is rarely adjacent to what it protects.
        -- Adjacency was only ever a legibility preference -- the original note said as much, "any cut
        -- vertex on the corridor would do" -- and it silently assumed every boon sits at the end of a
        -- 1-wide spur. It does on a maze. It does not in a chamber: a cache in the middle of a hall has
        -- four open neighbours and none of them gates anything, so the castle's first measured board
        -- guarded 1.6% of its boons while offering a doorway for every single one.
        --
        -- So walk back toward the start and take the FIRST tile that genuinely gates the boon AND can
        -- hold the fight. Nearest first, so the guard still stands as close to what it protects as the
        -- geometry allows -- and a corridor stretch between the boon and the room that gates it is
        -- walked past rather than stood in.
        local steps, cur = 0, startParent[cellKey(boon)]
        while cur and steps < GUARD_REACH do
            if seatable(cur) and not cur.guards and not reachableWithout(boon, cur)
                and self:seatsFight(cur.x, cur.y, boxSums, openSums) then return cur end
            cur = startParent[cellKey(cur)]
            steps = steps + 1
        end
        return nil
    end

    local target = math.floor(#boons * GUARDED_BOON_SHARE + 0.5)
    local placed, next_ = 0, 1
    for _, boon in ipairs(boons) do
        if placed >= target then break end
        local app = approachTo(boon)
        if app then
            if app.encounter then
                -- Something already stands here. If it is a fight, it was ALREADY guarding this boon by
                -- accident of placement -- name it as one and count it, rather than shuffling the board
                -- to arrange what the board arranged for itself. A non-combat stop is left alone.
                if app.encounter.kind == "combat" or app.encounter.kind == "elite" then
                    app.guards = { x = boon.x, y = boon.y }
                    payGuarded(boon)
                    placed = placed + 1
                end
            else
                -- Walk the shuffled supply for a fight that is not already guarding something, and move
                -- it here. Moving rather than minting is what keeps the encounter count honest.
                --
                -- RANK IS RESPECTED WHILE MOVING, or this pass quietly undoes the board's arc: an elite
                -- seated on the deep half by placeEncounters' depth rule can be picked up here and set
                -- down beside a boon on the doorstep, which is the exact placement that rule exists to
                -- prevent. So a shallow approach takes an ORDINARY fight, and if the loose supply has
                -- none left it takes NOTHING -- this boon is left in the open and the next one is tried,
                -- because the elite may well be exactly the right guard for a deeper reward further on.
                --
                -- That last clause was a fallback to "whatever is left" once, on the argument that a
                -- guard of the wrong rank beats a reward with nothing in front of it. It is the wrong
                -- trade and only ever fired on the boards where it did most harm: an unguarded cache
                -- costs the player nothing but a free pickup, while a tier-3 elite four steps from the
                -- start is the doorstep wall ELITE_MIN_DEPTH exists to forbid. Leaving the boon open is
                -- also not a loss to the pass -- the fight stays in the supply for the boon after it.
                local shallow = ((startDist[cellKey(app)] or 0) / farthest) < ELITE_MIN_DEPTH
                local src
                for j = next_, #guards do
                    local g = guards[j]
                    if g.encounter and not g.guards
                        and not (shallow and g.encounter.kind == "elite") then
                        src = g
                        break
                    end
                end
                if src then
                    app.encounter = src.encounter
                    src.encounter = nil
                    while next_ <= #guards and (guards[next_].guards or not guards[next_].encounter) do
                        next_ = next_ + 1
                    end
                    app.guards = { x = boon.x, y = boon.y }
                    payGuarded(boon)
                    placed = placed + 1
                end
            end
        end
    end
    self.guardedBoons = placed
end

-- ---------------------------------------------------------------------------
-- Patrols
-- ---------------------------------------------------------------------------

-- What share of a board's fights walk a beat rather than standing still. A board of nothing but movers
-- is as uniform as a board of nothing but statues, and the still ones are what make the moving ones
-- read. Tuned against `. board-report`, like everything else here.
local PATROL_SHARE = 0.6

-- How long a loose patrol's beat may be. Short: a beat you cannot hold in your head is not a schedule,
-- it is noise, and the whole point of drawing it is that the player can time it.
local BEAT_MAX = 6

-- LIFT THE FIGHTS THAT MOVE OFF THEIR CELLS AND ONTO BEATS.
--
-- Runs last, after every placement pass has had its say -- so what patrols is exactly what the board
-- decided to seat, and the counts the map was sized around do not move. A patrol carries its encounter
-- away with it; the cell keeps only what genuinely stays put (Patrol's header on why).
--
-- TWO RULES DECIDE A BEAT, and both are the offer rule wearing different hats:
--
--   A GUARD'S BEAT IS ITS CUT SET. guardBoons seats a fight on a tile that provably gates a reward,
--   checked by flooding the board with that tile blocked. Let that fight wander and the guarantee
--   evaporates -- it strolls two tiles down the corridor and the reward is free. So a guard's beat is
--   exactly the set of tiles that gate its boon: a long corridor gives it a real beat and it is
--   genuinely pacing what it protects, and a single-tile cut set gives a sentry that stands still. The
--   invariant survives BY CONSTRUCTION rather than by tuning.
--
--   A LOOSE PATROL'S BEAT NEVER TOUCHES THE SPINE. Combat is kept off the objective road so a wounded
--   company can always route to the boss; a patrol that wandered onto it would undo that silently.
--   Alert is allowed to cross it -- a patrol that has SEEN you may step onto the road to reach you --
--   because you can outwalk it, and a chase that stops at an invisible line is worse than no chase.
--
-- Ascent maps opt out, as they do for every spine rule: there combat is the route.
-- OPT-IN, and deliberately so. Lifting a fight off its cell changes what `cell.encounter` means, and a
-- great many specs read exactly that field to assert what PLACEMENT did -- how many stops were seated,
-- whether guards were moved rather than minted, that an ascent's climb runs in order. Those specs are
-- testing the pass upstream of this one and are right to count cells; switching this on underneath them
-- would have every one of them read low, which is a change in the instrument rather than in the board.
--
-- So the campaign board asks for patrols (states/game.lua), the report asks for them, and a spec that
-- means to exercise them asks too (tests/patrol_spec.lua). Everything else generates the board it
-- always generated.
function Overworld:placePatrols(params)
    self.patrols = {}
    if not (params and params.patrols) then return end

    local Patrol = require("models.patrol")
    local spine = self.spineKeys or {}

    -- Which tiles gate `boon`: exactly the ones whose removal puts it out of reach. This is the same
    -- question guardBoons asked to seat the guard, asked again over a neighbourhood to grow its beat.
    local function gatesBoon(boon, tile)
        local start = self:startCell()
        if not start or start == boon or tile == boon then return false end
        local seen = { [cellKey(start)] = true }
        local q, qi = { start }, 1
        while qi <= #q do
            local c = q[qi]; qi = qi + 1
            for _, n in ipairs(self:pathNeighbors(c.x, c.y)) do
                if n == boon then return false end
                if not seen[cellKey(n)] and n ~= tile then
                    seen[cellKey(n)] = true
                    q[#q + 1] = n
                end
            end
        end
        return true
    end

    -- Grow a beat outward from `cell` by breadth-first walk, taking only tiles `accept` allows, up to
    -- BEAT_MAX. Walked in a fixed order so a seed reproduces its beats.
    local function growBeat(cell, accept)
        local beat = { { x = cell.x, y = cell.y } }
        local seen = { [cellKey(cell)] = true }
        local q, qi = { cell }, 1
        while qi <= #q and #beat < BEAT_MAX do
            local c = q[qi]; qi = qi + 1
            for _, n in ipairs(self:pathNeighbors(c.x, c.y)) do
                if #beat >= BEAT_MAX then break end
                if not seen[cellKey(n)] and accept(n) then
                    seen[cellKey(n)] = true
                    beat[#beat + 1] = { x = n.x, y = n.y }
                    q[#q + 1] = n
                end
            end
        end
        return beat
    end

    local movers, seated = 0, {}
    for y = 1, self.rows do
        for x = 1, self.cols do
            local c = self.cells[y][x]
            local e = c.encounter
            if e and (e.kind == "combat" or e.kind == "elite") then seated[#seated + 1] = c end
        end
    end

    local target = math.floor(#seated * PATROL_SHARE + 0.5)
    for _, c in ipairs(seated) do
        if movers >= target then break end
        local kind = c.encounter and c.encounter.kind
        local beat
        if c.guards then
            local boon = self:get(c.guards.x, c.guards.y)
            -- Only the tiles that still gate it. On a 1-wide corridor this grows along the corridor; at
            -- a spur mouth it is one tile and the guard stands.
            beat = boon and growBeat(c, function(n) return gatesBoon(boon, n) end) or { { x = c.x, y = c.y } }
        elseif not (params and params.ascent) then
            beat = growBeat(c, function(n)
                return not spine[cellKey(n)] and not n.encounter and not n.cache and not n.gate and not n.key
            end)
        else
            beat = growBeat(c, function(n) return not n.encounter end)
        end
        if #beat > 1 then
            self.patrols[#self.patrols + 1] = Patrol.new(c, beat, { kind = kind, guards = c.guards })
            c.encounter = nil -- the fight walks now; the cell keeps nothing
            c.guards = nil
            movers = movers + 1
        end
    end
end

-- ---------------------------------------------------------------------------
-- Guaranteed stops
-- ---------------------------------------------------------------------------

-- The guarantee's knobs, per kind. A kind absent here is seated exactly ONCE, wherever the candidate
-- order offers first -- which is what "at least one Reliquary" has always meant, and still does.
--
-- REST is the only entry, and it needs all of them. It is the run's single refund: everything else on the
-- board spends the party's carried health and nothing else gives it back (models/player.lua), so how many
-- rests a board holds has to track how LONG the run is rather than being a flat one. And a refund twenty
-- tiles down a spur is not a pressure valve, it is one more boon to earn, so it is seated within `spine`
-- tiles of the critical path.
--
--   per     one per this many stops -- a DENSITY, which is the right unit when the board is the run
--   count   exactly this many, whatever the stop count -- a STRUCTURE, for a board that is one segment
--           of a longer run and so cannot read its own length off its own size (see below)
--   spine   seated within this many tiles of the critical path
local GUARANTEE = {
    rest = { per = 6, spine = 1 }, -- one rest per 6 stops, on or beside the road
}

-- The knobs a particular map is placing under: the default above, OVERLAID with whatever
-- `params.guarantee` names for that kind rather than replaced by it. A map that wants a different number
-- of rests is saying nothing about whether a rest belongs beside the road, and a wholesale replacement
-- would drop `spine` on the floor without a word -- the same trap `params.guaranteeKinds` carries, where
-- naming a third kind replaces the list instead of adding to it.
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
-- The pool is preferred, so a quest supplying its own encounter list still decides what its Reliquary is.
-- But the pool is WEIGHT-FILTERED -- Encounter.pool drops non-positive weights -- and some texture kinds
-- are deliberately weight 0: a Rest is authored-only precisely so it never turns up at random or in
-- clusters. Reading the guarantee off the pool therefore asked the wrong table. It made a DENSITY floor
-- depend on a RANDOM-DRAW weight, and the two disagreed silently: the rest guarantee no-opped on every
-- rolled board, which is why a run's attrition was one-way and no board ever offered a refund.
--
-- So fall back to the blueprint registry, by kind. Walked in sorted id order because `pairs` over the
-- registry is unspecified and this pick has to reproduce from a seed like everything else in here.
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
            -- `not c.cache` matters now that caches are placed FIRST: a stop dropped onto a cache tile
            -- would bury the reward under it and leave nothing for a guard to stand in front of.
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

    -- ASCENT maps (`params.ascent`): the guaranteed encounters are a ROUTE, not a set. Seated ALONG THE
    -- ROAD in authored order, so `always = { pickets, pickets, line, line, breach }` is met
    -- bottom-to-top -- the outer ring first, the thing leaning on the gate last, and the objective
    -- beyond all of them at the end of the climb (see placeObjectiveAndGates).
    --
    -- Off by default: ordinary maps want their guaranteed encounters scattered, and a fixed running
    -- order would make every quest that uses `always` read as a corridor.
    --
    -- Spacing is a FRACTION OF THE ROAD, not a fixed gap: marker k of n sits at k/(n+1) of the way up
    -- the spine, so a five-stop climb is met at roughly a sixth, a third, half, two thirds, five
    -- sixths. The previous rule -- walk every tile outward from the start and take the first one at
    -- least 3 tiles from the last marker -- measured the gap between MARKERS while walking by distance
    -- from the START, and those are not the same axis on a braided maze: tiles one and two steps out
    -- sit on different branches of the same fork, so they clear a 3-tile gap trivially and the whole
    -- climb was satisfied within six steps of the doorstep while forty tiles of road ran empty.
    --
    -- Seating on the spine also puts the fights where an ascent says they are -- across the road, not
    -- down a side spur the climb never passes.
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

        -- Which spine tiles this pass may actually use: everything placeEncounters already vetted
        -- (walkable, no gate/key/cache/encounter, not the start), keyed for lookup by position.
        local open = {}
        for _, c in ipairs(byDist) do open[cellKey(c)] = c end

        -- spineCells runs start -> objective along a BFS shortest path, so index j is exactly j-1 steps
        -- from the start. That makes "how far up the road" and "how far from the start" the same
        -- number here, which is what keeps the climb monotonic without a separate check.
        local spine = self.spineCells or {}
        local n, L = #always, #spine
        local lastIdx, lastDist = 1, -1

        for k, e in ipairs(always) do
            local chosen
            if L > 2 then
                local ideal = math.max(lastIdx + 1, math.floor(k / (n + 1) * (L - 1) + 0.5) + 1)
                -- Forward first (the climb should keep climbing), then back toward the last marker if
                -- the stretch above the ideal point is all gate or already spoken for.
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
                if chosen then lastDist = lastIdx - 1 end
            end
            -- Off-spine fallback: a short or heavily gated road still gets every authored encounter
            -- rather than silently dropping the top of the climb -- placed on the nearest tile that is
            -- no closer than the marker before it, so the order survives even here.
            if not chosen then
                for _, c in ipairs(byDist) do
                    if not c.encounter and (dist[cellKey(c)] or 0) >= lastDist then
                        chosen, lastDist = c, dist[cellKey(c)] or 0
                        break
                    end
                end
            end
            if chosen then
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

    -- Guaranteed VARIETY (density + mix): a rolled board must never be a wall of fights. Seat the texture
    -- kinds -- a Reliquary to stock the run's relics, a Rest to heal -- that `always` didn't already, all
    -- non-combat so the objective spine stays walkable. HOW MANY of each, and whether it wants to sit near
    -- the road, is per kind (see GUARANTEE above); the roster of kinds is tunable via params.guaranteeKinds
    -- and the per-kind knobs via params.guarantee, and their defaults are what the roguelike inner loop
    -- needs to feel like one (see models/relic.lua).

    -- How far off the critical path each walkable tile lies, computed only if some kind asks (the BFS is
    -- cheap but this runs at generation for every board, and most guarantees don't care where they land).
    local spineDist
    local function withinSpine(c, radius)
        spineDist = spineDist or self:spineDistances()
        return (spineDist[cellKey(c)] or math.huge) <= radius
    end

    -- The next free candidate, preferring one that satisfies `prefer`. Falls back to the first free tile
    -- of any kind, the same silent partial fallback placeKeys and placeCaches take on a cramped board --
    -- a guarantee that cannot be honoured exactly is still better honoured somewhere than dropped.
    --
    -- A preferred pick can come from ANYWHERE in the list, not just the front, so `next_` is re-seated to
    -- the first free candidate afterwards rather than blindly incremented. Taking a cell out of the middle
    -- is safe: it now carries an encounter, and the fill loop below skips it on its own spacing rule
    -- (a placed cell reads distance 0 to itself).
    local function takeCandidate(prefer)
        local pick
        if prefer then
            for _, c in ipairs(cands) do
                if not c.encounter and prefer(c) then pick = c; break end
            end
        end
        if not pick then
            for _, c in ipairs(cands) do
                if not c.encounter then pick = c; break end
            end
        end
        return pick
    end

    for _, kind in ipairs(params.guaranteeKinds or { "relic_cache", "rest" }) do
        local g = guaranteeFor(params, kind)
        -- A flat `count` wins over a density: it is the more specific statement, and a map that names one
        -- is saying its own length is not readable from its own stop count.
        local want = (g and g.count)
            or ((g and g.per) and math.max(1, math.ceil((count or 0) / g.per)))
            or 1
        local have = 0
        for _, p in ipairs(placed) do if p.encounter.kind == kind then have = have + 1 end end
        local entry = (have < want) and guaranteedEntry(pool, kind) or nil
        local prefer = (g and g.spine) and function(c) return withinSpine(c, g.spine) end or nil
        while entry and have < want do
            local c = takeCandidate(prefer)
            if not c then break end -- board is full: it simply holds fewer, as everywhere else here
            c.encounter = { kind = entry.kind, id = entry.id, name = entry.name }
            placed[#placed + 1] = c
            have = have + 1
            while cands[next_] and cands[next_].encounter do next_ = next_ + 1 end
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

    -- THE BOARD'S ARC LIVES HERE, not in assignEncounterTiers. That pass runs after every placement and
    -- only stamps a number on what is already down, so for as long as elites were seated uniformly the
    -- "difficulty ramp" was a label on a flat board -- an elite was as likely on the doorstep as at the
    -- gate, and measured mean tier by fifth ran 2.66 / 2.62 / 2.50 / 2.70 / 2.85, which is noise.
    --
    -- Two rules, both expressed as a DEMOTION so the encounter count and the quest's own pool are
    -- untouched (the same move the spine and combat-share rules already make):
    --   depth  an elite on the near half of the road is re-seated as an ordinary fight. The far half is
    --          measured from the START rather than off the spine, because this is about how deep the
    --          player has walked, not how far they strayed -- caches already own the other axis.
    --   share  elites are capped as a fraction of the stops, so no pool weight can make them the
    --          ordinary case again however a blueprint is authored (see encounter_elite.lua).
    local eliteCap = math.floor(target * (params.eliteShare or ELITE_SHARE))
    local elitePlaced = 0
    for _, p in ipairs(placed) do if p.encounter.kind == "elite" then elitePlaced = elitePlaced + 1 end end
    -- Depth is normalised against the far corner, the same denominator assignEncounterTiers uses, so
    -- "the deep half" means the same thing to the seating rule and to the pips that report it.
    local startDist, startParent = self:bfsDistances(self:startCell())
    local farthest = 1
    for _, d in pairs(startDist) do if d > farthest then farthest = d end end

    -- Built once for the whole fill: every candidate asks whether there is room to fight here, and the
    -- integral image makes each answer a handful of lookups instead of a 64-tile count. Both tables,
    -- because room is a pair -- see Overworld.BOX_OPEN for what the second one buys.
    local boxSums, openSums = self:walkableSums(), self:openSums()

    -- ...and whether this board has ANY ground worth fighting on. A DEMOTION THAT EMPTIES THE BOARD IS
    -- WORSE THAN A THIN FIGHT: on a ground whose carve offers nothing above the floor, refusing every
    -- seat does not produce careful placement, it produces a board with no fights on it at all. That is
    -- not hypothetical -- it is what the desert and the tundra did the first time this rule ran, and the
    -- report read `seat 0.0` across both rows before anyone had to play one.
    --
    -- So the floor governs CHOICE, and only where there is a choice to make. A ground that cannot clear
    -- it is a layout that has not been written yet, and it says so in the report's `under` column rather
    -- than by quietly serving an empty run.
    -- Scored ONCE per candidate, into a table keyed by cell. The look-ahead below scans forward through
    -- the candidate list for open ground, so asking bestBox inside it made the pass quadratic and each
    -- of those steps cost 64 window lookups -- board generation went from imperceptible to several
    -- seconds a board, which is a stall at the start of every quest. The scores do not change while this
    -- loop runs, so there is no reason to ask twice.
    local seats = {}
    local anyFightable = false
    for _, c in ipairs(cands) do
        local ok = self:seatsFight(c.x, c.y, boxSums, openSums)
        seats[c] = ok
        if ok then anyFightable = true end
    end

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
            -- A FIGHT IS NEVER SEATED WHERE A FIGHT CANNOT HAPPEN. The board locks an 8x8 window of
            -- these tiles and walls it, so a stop dealt onto a 1-wide corridor is not a hard fight, it
            -- is four bodies in a queue. Demoted like the two rules beside it rather than moved, so the
            -- stop count and the quest's authored pool are untouched -- the tile keeps its marker and
            -- the marker stops being a fight.
            --
            -- Corridor contact is still perfectly legal: a patrol that catches the party mid-hall gets
            -- exactly that fight, and it should. This rule only governs what the GENERATOR chooses to
            -- put somewhere, which is a different question from what the player walks into.
            local thin = anyFightable and not seats[c]
            local onSpine = self.spineKeys and not params.ascent and self.spineKeys[cellKey(c)]

            -- LOOK FOR ROOM BEFORE GIVING UP THE FIGHT. Demoting outright was tried and it bought
            -- almost nothing at a real price: thin seats fell 0.88 -> 0.70 a board while the fights
            -- themselves fell 4.3 -> 3.9, because most thin seats are guardBoons standing a guard in a
            -- spur mouth later, not this loop. So a fight dealt onto a corridor goes looking for a
            -- clearing among the candidates still free, and only demotes if the board has none.
            if isFight(pick.kind) and thin and not onSpine then
                for j = i + 1, #cands do
                    local alt = cands[j]
                    if not alt.encounter
                        and not (self.spineKeys and not params.ascent and self.spineKeys[cellKey(alt)])
                        and seats[alt] then
                        local spaced = true
                        for _, p in ipairs(placed) do
                            if math.abs(p.x - alt.x) + math.abs(p.y - alt.y) < 2 then spaced = false; break end
                        end
                        if spaced then c, thin = alt, false; break end
                    end
                end
            end

            if isFight(pick.kind) and (onSpine or thin or combatPlaced >= combatCap) then
                pick = self:pickNonCombat(pool) or pick
            end
            -- Then the rank rule, after the kind rule: a stop demoted to texture above is no longer a
            -- fight and must not spend the elite budget on its way past.
            if pick.kind == "elite" then
                local depth = (startDist[cellKey(c)] or 0) / farthest
                if depth < ELITE_MIN_DEPTH or elitePlaced >= eliteCap then
                    pick = self:pickOrdinaryCombat(pool) or pick
                end
            end
            if pick.kind == "elite" then elitePlaced = elitePlaced + 1 end
            -- NOTE: steering spur ends toward rewards was tried here and removed. It reads well -- a
            -- find belongs at the end of a corridor -- but placeCaches already claims the dead ends one
            -- pass earlier, so the only thing left for the steer to do was convert fights into boons. On
            -- a board where boons already outnumber fights, that spends the guards it was meant to
            -- create. What limits guarding is the SUPPLY OF FIGHTS, not where the rewards sit.
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

-- Weighted pick restricted to ORDINARY fights, or nil if the pool has none. The demotion partner to
-- pickNonCombat: an elite rolled onto shallow ground is re-seated as a plain fight rather than dropped,
-- so the board keeps the fight and loses only its rank.
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
                    c.tile = "thicket"
                    c.river = nil
                    changed = true
                end
            end
        end
    end
end

-- How often a fight reads one pip above what its depth and rank earn it. Low on purpose: the spike is
-- meant to stop the arc being perfectly predictable, and at the old 0.25 it was as strong as the depth
-- term it was decorating -- a third of the board's fights carried a tier their position did not explain,
-- which is not a surprise, it is a fog.
local TIER_SPIKE = 0.12

-- Difficulty tell for the fog: every combat/elite encounter gets a `tier` (1..3) the renderer shows as
-- pips so the player can read a fight's danger BEFORE committing to the tile (reveal-then-choose), and
-- #5 scales its reward by the same tier. Deeper on the board reads tougher. Drawn from self.rng LAST --
-- after every placement pass -- so it never shifts the seeded geometry, yet stays deterministic. Walked
-- in a stable grid order so the rng draws reproduce. Non-combat stops (treasure/rest/event) get no tier.
--
-- DEPTH IS THE WHOLE SCALE NOW, and rank rides on top of it. It used to be the other way round: `base`
-- was 3 for an elite and 1 for a fight, so an elite clamped to 3 wherever it stood and an ordinary
-- fight could only ever read 1 or 2. Rank was the tier and depth was a rounding error on it. That was
-- survivable only while elites were rare; once one blueprint's weight made them 76% of all fights the
-- board reported a flat 2.6 everywhere, which is the same as reporting nothing.
--
-- Reading depth in THIRDS gives all three pips to position, so a fight's mark says where on the road it
-- stands, and an elite is that plus one -- the deep-half seating rule (ELITE_MIN_DEPTH) means an elite
-- therefore lands on 3 nearly always, which is what an elite should be. Same denominator as the seating
-- rule, so the pips and the placement agree about where the deep half starts.
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
                -- corner, and floor(1.0 * 3) is 3, which would put the whole last tile in a fourth band.
                local t = 1 + math.min(2, math.floor(depth * 3))
                if e.kind == "elite" then t = t + 1 end
                if self.rng:random() < TIER_SPIKE then t = t + 1 end
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
-- `guards` is the {x,y} of the boon a fight stands in front of (see guardBoons): plain data, and it must
-- ride along or a resumed run would stop revealing rewards past their guard.
-- `secret` rides out because it is RUN STATE, not geometry: a door found on the third trip down must
-- still be open on the fourth, and a descent keeps its floors (models/descent.lua's Descent.keepFloor)
-- precisely so that discovery persists. `secretEnd` deliberately does NOT -- it is generation-only
-- scaffolding, consumed by placeSecretRewards before the board is ever saved.
local CELL_FIELDS = { "tile", "river", "bridge", "seen", "cleared", "picked", "encounter", "gate", "key", "cache", "guards", "secret" }

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
    -- THE FIGHTS THAT WALK, and where they had got to. A patrol is an actor rather than a property of a
    -- cell (models/patrol.lua), so it does not ride out in `cells` with everything else -- and a resumed
    -- run that forgot them would put every patrolling fight back on the tile it was generated on, which
    -- is not where the player left it. Plain data throughout: ids, names, tiers, a beat of {x,y}.
    local patrols = {}
    for _, p in ipairs(self.patrols or {}) do
        patrols[#patrols + 1] = {
            encounter = p.encounter, x = p.x, y = p.y, beat = p.beat,
            i = p.i, dir = p.dir, tick = p.tick, state = p.state, alert = p.alert,
            home = p.home, guards = p.guards, pace = p.pace, sight = p.sight,
            leash = p.leash, cleared = p.cleared,
        }
    end

    return {
        cols = self.cols, rows = self.rows, size = self.size,
        margin = self.margin, spacing = self.spacing,
        patrols = patrols,
        tilesetId = self.tilesetId, biome = self.biome,
        originX = self.originX, originY = self.originY,
        visionRadius = self.visionRadius,
        start = { x = self.start.x, y = self.start.y },
        objective = self.objective and { x = self.objective.x, y = self.objective.y } or nil,
        -- EVERY end this board carries, with the quest each belongs to. The cells already hold the same
        -- ids on their encounters; this is the index the checklist reads, and without it a resumed trip
        -- would come back with an empty list of work and no way to tick anything off.
        objectives = self.objectives,
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
    -- A save written before a board could have several ends restores with just the one it had, so an
    -- expedition in flight at upgrade time finishes rather than resuming onto a board with no work on it.
    self.objectives = data.objectives or (self.objective and { self.objective }) or {}
    self.keyIds = data.keyIds or {}
    self.gateCells = {}
    -- A save written before patrols existed restores with none and plays exactly as it did.
    self.patrols = data.patrols or {}
    self.sealed = true -- a restored board is finished by definition
    self.cells = {}
    for y = 1, self.rows do
        self.cells[y] = {}
        local row = (data.cells and data.cells[y]) or {}
        for x = 1, self.cols do
            local src = row[x] or {}
            local cell = { x = x, y = y, tile = src.tile or "thicket" }
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
    local uncovered
    for y = cy - radius, cy + radius do
        for x = cx - radius, cx + radius do
            if self:inVision(cx, cy, x, y, radius) then
                local c = self:get(x, y)
                -- A SECRET DOOR STOPS THE LIGHT. While the mark is on it the tile stays black, and so
                -- does everything past it -- the fog is what hides the corridor behind it, and lighting
                -- the door alone would put a lit stub of nothing in the middle of a wall, which is a
                -- worse tell than no secret at all. Cleared by Overworld:findSecrets, after which this
                -- is ordinary trail and lights like any other (Overworld:isHidden).
                if c and not c.seen and not self:isHidden(c) then
                    c.seen = true
                    found = found + 1
                    if c.guards then uncovered = uncovered or {}; uncovered[#uncovered + 1] = c end
                end
            end
        end
    end

    -- SEEING THE FIGHT MEANS SEEING WHAT IT IS FOR. A guarded reward sits one tile past its guard, which
    -- is often one tile past the vision disc -- so without this the player meets a fight blocking a
    -- corridor and has no idea anything is behind it. That is not an offer, it is just a fight, and the
    -- whole push-or-press-on decision depends on the offer being legible from outside it. Handled here
    -- rather than at the walking seam so every way of lifting fog gets it: a step, a rest's Study,
    -- Gyeom's Ledger, the Cartographer's Eye. Counted in `found` because it IS a discovery -- the
    -- explore-paying hooks (Kaya's forage, Poacher's Map) should read it as one.
    for _, guard in ipairs(uncovered or {}) do
        local boon = self:get(guard.guards.x, guard.guards.y)
        if boon and not boon.seen then
            boon.seen = true
            found = found + 1
        end
    end
    return found
end

function Overworld:startCell() return self:get(self.start.x, self.start.y) end
function Overworld:objectiveCell() return self:get(self.objective.x, self.objective.y) end

-- ---------------------------------------------------------------------------
-- The arena box
-- ---------------------------------------------------------------------------

-- A FIGHT IS TAKEN ON THIS MAP. When one begins the board locks a window of these very tiles, walls its
-- ring and doubles the camera; the company unfurls onto ground that was already there. So the window is
-- 8x8 because models/arena.lua is 8x8 (Arena.COLS/ROWS) and the two grids are the same grid at 2x -- 32
-- logical pixels a cell here, 64 there -- which is the coincidence that lets a lock be a camera
-- transform rather than a second board.
--
-- The generator therefore has to answer a question it never had to before: IS THERE A BATTLE HERE. It
-- answers by counting walkable ground inside the window, which is all "can four bodies deploy and still
-- have somewhere to go" reduces to on a grid.
Overworld.BOX = 8

-- What a window has to hold, in walkable tiles out of BOX*BOX:
--
--   BOX_OK   an encounter is never SEATED below this. Half the box is where a fight stops being a fight
--            and becomes a queue: four bodies, a front, and room to go round it.
--   BOX_MIN  the floor for a fight that happens ANYWAY -- a patrol catching the party mid-corridor. That
--            is a real consequence of a real mistake and it should hurt, but below this there is nowhere
--            to stand at all, which is not a hard fight, it is an unplayable one.
--
-- Both are read by the report before they are read by anything else: do not tune them from here, roll
-- the boards (`. board-report 200 all`) and read what they say.
--
-- Counted in CROSSABLE tiles, not walkable ones -- see Overworld:boxReach.
Overworld.BOX_OK = 32
Overworld.BOX_MIN = 20

-- ...AND THE SHAPE FLOOR, which is a different question from the space floor and was carried for a
-- whole pass as though the first one covered it. BOX_OK counts tiles; BOX_OPEN counts OPEN tiles --
-- ones with a full 3x3 of trail around them (Overworld:isOpen) -- so it is the number that separates an
-- arena from a warren of the same area.
--
-- The gap was not theoretical and it was not small. models/layouts/glades.lua carves five to fourteen
-- clearings a board FOR THIS EXACT PURPOSE, and says so in its own header: "every few junctions there is
-- somewhere a fight can actually happen, and the placement pass seats fights there". The placement pass
-- was scoring windows by walkable count, on which a lattice of 1-wide corridors ties a clearing -- so it
-- could not tell the two apart and seated fights in the corridors as readily as in the rooms it had been
-- given. Rolled boards, `. board-report 200 all`: forest seated its fights at 40 walkable tiles and
-- TWELVE open ones, swamp at 10.6, the colosseum -- an oval of bare sand -- at 14.5. The layouts had
-- built the arenas and nothing was reading them.
--
-- 16 of 64 is a quarter of the window, which is the interior of one radius-3 blob: the smallest clearing
-- glades will carve, and by its own note the smallest disc that has an interior at all. Below that a
-- board has walkable ground and no room to make a decision on it.
--
-- Same rule as the two above: do not tune it from here, roll the boards and read the `open` column.
Overworld.BOX_OPEN = 16

-- Summed-area table over walkable tiles, returned as a closure answering any window in constant time.
--
-- Built FRESH on each call rather than memoized onto the grid, deliberately. Tiles are still being
-- carved while the placement passes run -- pruneDeadStubs rewrites them after placeEncounters -- so a
-- cached integral image would silently disagree with the board it describes, and that disagreement
-- surfaces six passes later as a wrong number in a report rather than as a crash.
-- `pred(cell)` chooses what is being counted; it defaults to walkable ground. The generalisation exists
-- because COUNTING WALKABLE TILES IS NOT THE SAME AS ASKING WHETHER THERE IS A BATTLE HERE, and the
-- boards said so the first time they were rolled: a tight warren scores 34 of 64 while being a lattice
-- of 1-wide corridors with no line, no flank and nothing to stand behind, and a real chamber scores the
-- same. So a second measure counts OPEN ground (see Overworld.isOpen) over the same machinery.
function Overworld:walkableSums(pred)
    local B = Overworld.BOX
    -- CACHED ONCE THE BOARD IS FINISHED, and never before. While generation is running the tiles are
    -- still being carved -- pruneDeadStubs rewrites them after placeEncounters -- and a cached integral
    -- image would silently describe a board that no longer exists. Once `sealed` is set nothing mutates
    -- a tile again, so the table can be kept.
    --
    -- It is kept because the cost turned out to be real rather than theoretical: every fight asks for
    -- the box twice (once to size the opposition, once to cut the board) and every marker asks again to
    -- price itself, and rebuilding a rows x cols table of tables each time took the headless suite from
    -- about a minute to several. Only the default predicate is cached; a caller asking a different
    -- question is rare and pays for it.
    if pred == nil and self.sealed and self._sums then return self._sums end
    pred = pred or function(cell) return self:typeWalkable(cell.tile) end
    local sum = {}
    for y = 0, self.rows do
        sum[y] = {}
        sum[y][0] = 0
    end
    for x = 0, self.cols do sum[0][x] = 0 end
    for y = 1, self.rows do
        for x = 1, self.cols do
            local w = pred(self.cells[y][x], x, y) and 1 or 0
            sum[y][x] = w + sum[y - 1][x] + sum[y][x - 1] - sum[y - 1][x - 1]
        end
    end
    -- Walkable count of the BOX x BOX window whose top-left corner is (x, y), 1-indexed.
    local query = function(x, y)
        local x2, y2 = x + B - 1, y + B - 1
        if x < 1 or y < 1 or x2 > self.cols or y2 > self.rows then return 0 end
        return sum[y2][x2] - sum[y - 1][x2] - sum[y2][x - 1] + sum[y - 1][x - 1]
    end
    if pred == nil and self.sealed then self._sums = query end
    return query
end

-- IS THIS TILE OPEN GROUND, meaning its whole 3x3 neighbourhood is walkable. A corridor tile is not,
-- however long the corridor; a junction is not; only the interior of something at least three wide is.
--
-- This is the shape measure the plain walkable count cannot be. Rolled boards say a spacing-2 warren
-- holds 34 walkable tiles in an 8x8 window -- comfortably past the floor -- with ZERO open tiles in it,
-- because every tile it holds is a corridor with wall on both sides. A board like that has room for four
-- bodies and no room for a decision: nothing can be flanked, nothing has a line, and the fight resolves
-- as whoever is at the front of the queue. So a seat wants both numbers, and the second one is the one
-- that says "room" rather than "space".
function Overworld:isOpen(x, y)
    for dy = -1, 1 do
        for dx = -1, 1 do
            local c = self:get(x + dx, y + dy)
            if not (c and self:typeWalkable(c.tile)) then return false end
        end
    end
    return true
end

-- The same summed-area machinery over OPEN ground rather than walkable ground, memoized on the finished
-- board like its walkable twin. Built through walkableSums' predicate hook, which is what that hook was
-- generalised for -- so the two tables can never be two different opinions about the same window.
function Overworld:openSums()
    if self.sealed and self._openSums then return self._openSums end
    local query = self:walkableSums(function(_, x, y) return self:isOpen(x, y) end)
    if self.sealed then self._openSums = query end
    return query
end

-- IS THERE AN ARENA HERE. The one question every pass that CHOOSES where to put a fight has to ask, and
-- the reason it is a function rather than two comparisons at four call sites: the answer is a pair --
-- crossable ground and open ground -- and a caller that reads only one of them is the bug this exists to
-- stop being written again.
--
-- Returns `cross, open, ox, oy` for the window a fight at (x, y) would actually be fought in, which is
-- the window bestBox chooses and not a window centred here. `sums`/`openSums` are optional and exist for
-- callers asking about many tiles in a loop; build them once and hand them in.
--
-- Open ground is counted over the WHOLE window rather than only the part reachable from (x, y). The
-- crossable count already carries the reachability question, and a second flood per candidate would
-- double the cost of every placement pass to refine a number that is a floor, not a score.
function Overworld:roomAt(x, y, sums, openSums)
    sums = sums or self:walkableSums()
    openSums = openSums or self:openSums()
    local ox, oy, cross = self:bestBox(x, y, sums)
    return cross, openSums(ox, oy), ox, oy
end

-- Can the generator SEAT a fight on (x, y)? Both floors, together: room for four bodies (BOX_OK) and
-- room to make a decision with them (BOX_OPEN). See the constants for why one of them was not enough.
function Overworld:seatsFight(x, y, sums, openSums)
    local cross, open = self:roomAt(x, y, sums, openSums)
    return cross >= Overworld.BOX_OK and open >= Overworld.BOX_OPEN, cross, open
end

-- HOW MUCH OF A WINDOW YOU CAN ACTUALLY CROSS, standing on (x, y): the walkable tiles of the BOX x BOX
-- window at (ox, oy) reachable from that tile WITHOUT LEAVING THE WINDOW. Returns the count, and fills
-- `out` (optional) with a set of cell keys, so a caller that wants to know WHICH tiles those are does
-- not walk the window twice.
--
-- THE WINDOW'S RING IS THE WALL. Once the lock closes there is no board outside the box (models/arena.lua's
-- Arena.fromGrid), so a pocket of ground that joins the rest of this window only by a path running
-- OUTSIDE it is not ground the fight has. Counting it was wrong twice over: it priced the opposition off
-- floor nobody could stand on, and -- worse -- it let a window be CHOSEN for tiles that would turn out to
-- be behind a wall, which is how a board ended up with a boar on one side of a ridge and the company on
-- the other, neither able to reach the other for the whole fight.
--
-- Walkability is the tileset's, which is models/terrain.lua's, which is the battle board's: the seal
-- Arena.fromGrid lays cannot disagree with the count priced here.
local reachSeen, reachQueue = {}, {}
function Overworld:boxReach(ox, oy, x, y, out)
    local B = Overworld.BOX
    if out then for k in pairs(out) do out[k] = nil end end
    if x < ox or x >= ox + B or y < oy or y >= oy + B then return 0 end
    local cells = self.cells
    -- Scratch arrays indexed 1..B*B within the window, reused between calls: this runs once per
    -- candidate window per query and a fresh table each time was the whole cost.
    for i = 1, B * B do reachSeen[i] = false end
    local function idx(cx, cy) return (cy - oy) * B + (cx - ox) + 1 end
    local function open(cx, cy)
        if cx < ox or cx >= ox + B or cy < oy or cy >= oy + B then return false end
        local row = cells[cy]
        local c = row and row[cx]
        return c ~= nil and self:typeWalkable(c.tile)
    end
    if not open(x, y) then return 0 end

    reachSeen[idx(x, y)] = true
    reachQueue[1], reachQueue[2] = x, y
    local head, tail, n = 1, 3, 0
    while head < tail do
        local cx, cy = reachQueue[head], reachQueue[head + 1]
        head = head + 2
        n = n + 1
        if out then out[cy * 100000 + cx] = true end
        for _, d in ipairs(DIRS) do
            local nx, ny = cx + d[1], cy + d[2]
            if open(nx, ny) then
                local i = idx(nx, ny)
                if not reachSeen[i] then
                    reachSeen[i] = true
                    reachQueue[tail], reachQueue[tail + 1] = nx, ny
                    tail = tail + 2
                end
            end
        end
    end
    return n
end

-- THE WINDOW A FIGHT AT (x, y) WOULD BE FOUGHT IN: of every window CONTAINING that tile, the one holding
-- the most ground you can cross FROM that tile (Overworld:boxReach). Returns its top-left (ox, oy) and
-- that score.
--
-- Chosen rather than centred, and that is the whole rule. Meet something at the mouth of a clearing and
-- the box pulls into the clearing, so you fight in the room and not in the doorway. Get cornered in a
-- true corridor and it stays a corridor, because there was nothing better within reach -- which is the
-- price of having walked in there, not a failure of the generator.
--
-- CROSSABLE rather than merely walkable, because the box's own ring cuts the map: a window can sit across
-- a ridge and score 44 while holding two pockets of 26 and 18 that have nothing to do with each other.
-- Whichever pocket you are standing in IS the board, so that is what the window is chosen for and what
-- the score reports. What the count leaves out, Arena.fromGrid then walls (a board in pieces has to read
-- as the small board it is, not as a big one with a bug in it).
--
-- The plain walkable count is still the SIEVE: it bounds the reachable one from above, so candidates are
-- walked in descending walkable order and the flood fill stops as soon as no remaining window could beat
-- what has been found. On open ground that is one fill; the boards say two to seven where the ground is
-- broken (desert is the worst of them), never the sixty-four the naive version would pay.
--
-- Ties break toward the window that WALLS LESS -- the same crossable ground with less of it sealed off is
-- the same fight on a board that agrees with the map -- and then toward the top-left, so a seed
-- reproduces its lock exactly.
--
-- `sums` is optional and exists for callers asking about many tiles (the report walks every cell on the
-- board): build it once with walkableSums() and hand it in, or pay for one per query.
function Overworld:bestBox(x, y, sums)
    sums = sums or self:walkableSums()
    local B = Overworld.BOX
    local cand, maxWalk = {}, -1
    for oy = math.max(1, y - B + 1), math.min(self.rows - B + 1, y) do
        for ox = math.max(1, x - B + 1), math.min(self.cols - B + 1, x) do
            local s = sums(ox, oy)
            cand[#cand + 1] = { ox = ox, oy = oy, walk = s }
            if s > maxWalk then maxWalk = s end
        end
    end
    -- A board smaller than the box in either axis has no window at all. Clamp rather than return nil:
    -- every caller here wants a rectangle to draw or to count, and a degenerate map is a test fixture,
    -- not a state the campaign can reach.
    if #cand == 0 then return 1, 1, 0 end

    -- Asked about a tile nothing can stand on -- a report walking every cell, a marker on solid ground.
    -- There is nothing to be reachable FROM, so the question falls back to the plain count.
    local here = self:get(x, y)
    if not (here and self:typeWalkable(here.tile)) then
        local b = cand[1]
        for _, c in ipairs(cand) do if c.walk > b.walk then b = c end end
        return b.ox, b.oy, math.max(0, b.walk)
    end

    table.sort(cand, function(a, b)
        if a.walk ~= b.walk then return a.walk > b.walk end
        if a.oy ~= b.oy then return a.oy < b.oy end
        return a.ox < b.ox
    end)

    local bx, by, best, bestSealed = cand[1].ox, cand[1].oy, -1, math.huge
    for _, c in ipairs(cand) do
        if c.walk < best then break end -- nothing left can hold more crossable ground than this
        local reach = self:boxReach(c.ox, c.oy, x, y)
        local sealed = c.walk - reach
        if reach > best or (reach == best and sealed < bestSealed) then
            bx, by, best, bestSealed = c.ox, c.oy, reach, sealed
        end
        if bestSealed == 0 and best == maxWalk then break end -- a whole window, and the fullest there is
    end
    return bx, by, math.max(0, best)
end

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
