-- THE ONE TERRAIN TABLE. What ground is, for the map and for the board, because they are the same
-- ground: a fight is taken on an 8x8 window of the very tiles the company walked over (see
-- models/overworld.lua's Overworld.BOX and docs/overworld.md). A tile therefore has to answer both
-- layers' questions at once, and there can only be one answer.
--
-- Before this there were two tables and they disagreed. models/tileset.lua knew six overworld types and
-- one fact about each -- walkable or not. models/arena.lua's TILE_PROPS knew ten battle types and four
-- -- move cost, sight cost, tags, bonuses. Both survive as views onto this (Terrain.tilesetTypes and
-- Arena.TILE_PROPS), so every existing caller keeps working; what does not survive is the disagreement.
--
-- TWO NAMES COLLIDED, and both collisions were real rather than clerical -- the same word was doing two
-- different jobs, so each becomes two tiles:
--
--   forest   the map's fill was impassable dense wood; the board's was a tree you walk through slowly
--            for soft cover. Both are wanted, and a glade wants BOTH AT ONCE: `thicket` is the wall
--            that makes a trail a trail, `forest` is the cover scattered through the clearing that
--            makes it worth fighting in.
--   water    the map's was a barrier crossed at a bridge; the board's was a ford, wadeable at double
--            cost and carrying a charge. So `river` is the barrier and `water` stays the ford --
--            which means bridges keep being doors and the tundra keeps its conduction.
--
-- The properties, in full:
--   * moveCost   terrain-weighted enter cost (Dijkstra reach + the initiative timeline; models/combat)
--   * walkable   may a unit occupy the tile at all. On the map this is also what makes a maze a maze.
--   * sightCost  how much this tile obstructs a line of sight passing THROUGH it. Combat sums it
--     between shooter and target and blocks the line at Combat.SIGHT_BLOCK. 0 = transparent.
--   * bonus      positional modifiers granted to whoever STANDS here, e.g. { range = 1 } for high
--     ground. Aggregated with placed field objects by Combat.fieldBonus.
--   * tags       what the ground is MADE of, for effects that ask a tile a question rather than name a
--     type: "burnable" (fire creeps in), "conductable" (lightning arcs in). A hazard on the tile or a
--     status on whoever stands there can carry the same tags and Combat.tileHasTag answers across all
--     three -- so a Rain cloud, a Wet unit and a river are one thing to a lightning bolt.
--   * index/color  the DEFAULT art: a 1-based sheet index and a pre-art fallback colour. A biome's
--     tileset (data/tilesets/<id>.lua) may override either per type; it may never override behaviour.
--
-- Plain data, no love.* at require time, so it loads under the headless suite.

local Terrain = {}

local SOLID = math.huge

Terrain.TYPES = {
    -- ---- open ground -------------------------------------------------------
    -- Where a trail runs and where a fight is decided. `path` and `ground` are the same floor under two
    -- names the two layers each already had; kept apart only so a carved trail can still be told from
    -- the field around it when the renderer picks art.
    ground  = { moveCost = 1, walkable = true, sightCost = 0, index = 4, color = { 0.42, 0.30, 0.18 } },
    path    = { moveCost = 1, walkable = true, sightCost = 0, index = 4, color = { 0.42, 0.30, 0.18 } },
    -- A crossing. Walkable, and the only way over a river.
    bridge  = { moveCost = 1, walkable = true, sightCost = 0, index = 5, color = { 0.55, 0.40, 0.22 } },

    -- ---- cover and rises ---------------------------------------------------
    -- Trees you walk through: slow, soft cover, and they catch.
    forest  = { moveCost = 2, walkable = true, sightCost = 1, tags = { "burnable" },
                index = 1, color = { 0.10, 0.24, 0.12 } },
    -- Steep high ground: blocks the view behind it, but whoever holds it sees and strikes one further.
    mountain = { moveCost = 3, walkable = true, sightCost = 2, bonus = { range = 1 },
                index = 3, color = { 0.40, 0.38, 0.36 } },
    -- Legacy penalty floor, still named by curated arenas.
    rough   = { moveCost = 2, walkable = true, sightCost = 0, index = 3, color = { 0.34, 0.32, 0.30 } },

    -- ---- solid -------------------------------------------------------------
    -- Dense wood: the map's fill, the thing a trail is cut THROUGH. Blocks the tile and the view.
    thicket = { moveCost = SOLID, walkable = false, sightCost = SOLID, tags = { "burnable" },
                index = 1, color = { 0.10, 0.24, 0.12 } },
    -- Scrub and standing rock: the fill's two cosmetic variants, laid by noise (Overworld:decorate).
    -- Solid, as they have always been -- a maze whose walls had holes in them would not be a maze. When
    -- the layouts land these become the ground scattered INSIDE a clearing, and that is the pass that
    -- makes them walkable, not this one.
    grass   = { moveCost = SOLID, walkable = false, sightCost = SOLID, index = 2, color = { 0.16, 0.32, 0.16 } },
    rock    = { moveCost = SOLID, walkable = false, sightCost = SOLID, index = 3, color = { 0.34, 0.32, 0.30 } },
    -- Solid: blocks the tile and the sight through it.
    obstacle = { moveCost = SOLID, walkable = false, sightCost = SOLID, index = 3, color = { 0.30, 0.28, 0.26 } },
    -- A river: the map's barrier, crossed at a bridge. Impassable but sightCost 0 -- you can see the
    -- far bank perfectly well, you simply cannot get to it here.
    river   = { moveCost = SOLID, walkable = false, sightCost = 0, tags = { "conductable" },
                index = 6, color = { 0.18, 0.34, 0.55 } },
    -- A lava flow: impassable, and like the river it does not block a line. The one barrier that
    -- separates two lines without also hiding them from each other.
    lava    = { moveCost = SOLID, walkable = false, sightCost = 0, index = 6, color = { 0.72, 0.28, 0.12 } },

    -- ---- the biome floors --------------------------------------------------
    -- Each the deliberate inverse of one above, so a board built on them plays differently rather than
    -- merely looking different. None grants cover: all sightCost 0, because what makes a strange floor
    -- interesting is what it does to feet and to reach, not what it hides behind.

    -- A ford or shallow pool: wadeable but slow, and it carries a charge to whoever stands in it.
    water   = { moveCost = 2, walkable = true, sightCost = 0, tags = { "conductable" },
                index = 6, color = { 0.30, 0.50, 0.62 } },
    -- Loose sand: forest's cost without forest's cover, so a desert board is a long ranged exchange
    -- nobody can cross quickly or safely.
    sand    = { moveCost = 2, walkable = true, sightCost = 0, index = 2, color = { 0.78, 0.68, 0.44 } },
    -- Frozen ground: the ONLY terrain that does not tax a step. What it charges instead is conduction --
    -- a lightning line that would clip one body on grass sweeps a whole frozen front.
    ice     = { moveCost = 1, walkable = true, sightCost = 0, tags = { "conductable" },
                index = 2, color = { 0.80, 0.86, 0.90 } },
    -- Sucking bog: ties the mountain for the heaviest walkable floor and gives back nothing -- no reach,
    -- no cover, no sight. Expensive to cross and never worth holding. Wet through, so it conducts.
    mire    = { moveCost = 3, walkable = true, sightCost = 0, tags = { "conductable" },
                index = 1, color = { 0.28, 0.34, 0.22 } },
}

-- Behaviour for `type`, always a complete table. An unknown or nil type answers as solid rather than as
-- open field: a tile nobody can name is a hole in the data, and a hole that reads as walkable puts a
-- body inside a wall, where a hole that reads as solid merely puts a wall on the board.
function Terrain.get(t)
    return Terrain.TYPES[t] or Terrain.TYPES.obstacle
end

function Terrain.walkable(t)
    local def = Terrain.TYPES[t]
    return def ~= nil and def.walkable == true
end

-- The overworld tileset's view: walkability plus the default art, keyed by type. models/tileset.lua
-- merges a biome's `index`/`color` overrides onto this; behaviour is never overridden by a biome,
-- because a river the player can walk across in one country and not another is not a rule, it is a bug.
function Terrain.tilesetTypes()
    local out = {}
    for name, def in pairs(Terrain.TYPES) do
        out[name] = { index = def.index, walkable = def.walkable, color = def.color }
    end
    return out
end

return Terrain
