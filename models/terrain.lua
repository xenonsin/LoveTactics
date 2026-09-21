-- THE ONE TERRAIN TABLE. What ground is, for the map and for the board alike. It was written when a
-- fight was taken on an 8x8 window of the very tiles the company walked over, which made one answer
-- mandatory; the board is built for the fight again (models/arena.lua) and the single table stays,
-- because a river meaning one thing on both surfaces is worth having on its own and two tables drifting
-- apart was never the good version.
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
-- AND ONE NAME WAS WRONG TWICE OVER. `mountain` was the walkable rise -- three move, +1 reach, the tile
-- you fight for -- and `obstacle` was the anonymous solid beside it, which is a word for a role and not
-- for a thing. A mountain you stroll up is not a mountain, and "obstacle" tells the player nothing
-- about what is in front of them. So the rise is a `hill` and the solid is the `mountain`, which is the
-- reading anyone already had: the small rise is the one you take, the rock face is the one you go
-- around -- unless you are flying, and then the mountain is the one thing on the board a pair of
-- Zephyr Striders is genuinely FOR.
--
-- The properties, in full:
--   * moveCost   terrain-weighted enter cost (Dijkstra reach + the initiative timeline; models/combat)
--   * walkable   may a unit occupy the tile at all. On the map this is also what makes a maze a maze.
--   * sightCost  how much this tile obstructs a line of sight passing THROUGH it. Combat sums it
--     between shooter and target and blocks the line at Combat.SIGHT_BLOCK. 0 = transparent.
--   * bonus      positional modifiers granted to whoever STANDS here, e.g. { range = 1 } for high
--     ground. Aggregated with placed field objects by Combat.fieldBonus. The legal keys are DECLARED
--     (Terrain.BONUS_KEYS, below) and that declaration is the whole of what stops this field lying.
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

-- ---------------------------------------------------------------------------
-- WHAT A TILE IS ALLOWED TO PROMISE
-- ---------------------------------------------------------------------------
--
-- The `bonus` bag is generic by design -- Combat.fieldBonus sums whatever keys it finds -- and for a
-- long time that genericity was one-directional in the worst way: the bag accepted every key and
-- exactly TWO of them were ever read. ui/tile_tooltip.lua meanwhile carried its own hard-coded list of
-- seven and printed any that were non-zero, so a tile authored `bonus = { defense = 2 }` displayed
-- "+2 Defense bonus" to the player and moved no number in the fight. Nothing had gone wrong yet only
-- because nothing authored those keys.
--
-- So the set is DECLARED here, and it names its own read site. A key in this table is a promise some
-- function keeps; a key absent from it is a typo. The tooltip iterates THIS rather than a copy, and
-- tests/field_bonus_spec.lua fails the build in both directions -- a bonus key no read site honours,
-- and a declared key no tile could ever get a number out of.
--
-- ORDERED, and one list rather than a set plus a display order. Two ledgers of the same set drift the
-- moment somebody adds to one of them, and the drift is silent: the readout would simply stop
-- mentioning the newest key while every spec about the SET stayed green.
Terrain.BONUS_KEYS = {
    { key = "avoid",        read = "Combat.terrainAvoid -- comes straight off an attacker's hit chance" },
    { key = "range",        read = "Combat.fieldRangeBonus -- SIGHTED abilities only, never a swing" },
    { key = "defense",      read = "Combat.flatStat, via the stamp Combat.stampField lays on arrival" },
    { key = "magicDefense", read = "Combat.flatStat, via the stamp Combat.stampField lays on arrival" },
}

-- Is `key` something a tile may promise? The lookup over the list above, built once.
local BONUS_SET = {}
for _, entry in ipairs(Terrain.BONUS_KEYS) do BONUS_SET[entry.key] = entry.read end
function Terrain.readsBonus(key)
    return BONUS_SET[key]
end

-- THE CEILING ON TERRAIN ARMOUR, and the reason it is not Fire Emblem's number. A fort there gives +2
-- against a Defence stat that runs 0-20; ours runs 3-6 across the whole roster (docs/balance.md), so
-- the same +2 is a third to two thirds of a body's entire mitigation -- far heavier than the forest's
-- +20 avoid, which comes off a hit chance already sitting at 61-91%. Terrain armour is therefore
-- capped at ONE point and belongs to exactly one tile in the table; a second tile wanting it is a
-- re-tier, and a re-tier obliges a rebalance. Pinned by tests/terrain_spec.lua.
Terrain.DEFENSE_CEILING = 1

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
    -- Trees you walk through: slow, soft cover, and they catch. The `avoid` makes the cover mean the
    -- same thing to a swing that it already meant to a sightline -- until accuracy existed, "soft
    -- cover" was a claim this tile only half kept.
    forest  = { moveCost = 2, walkable = true, sightCost = 1, tags = { "burnable" },
                bonus = { avoid = 20 },
                index = 1, color = { 0.10, 0.24, 0.12 } },
    -- A hill: steep high ground you can actually take. Blocks the view behind it, but whoever holds it
    -- sees and strikes one further. The best tile on the board and priced like it: three move to
    -- enter, and it pays twice. Named `hill` and not `mountain` because a mountain is the thing you
    -- cannot climb (below) -- one word per shape, and the rise you fight for is the smaller one.
    -- GREEN, and the stone it used to be painted in has gone to the tiles nobody can enter. Colour is
    -- not this board's identity channel -- the mark is (ui/terrain_art.lua) -- but it is doing one job
    -- now: GREY MEANS YOU CANNOT GO THERE. The hill is the heaviest floor there is and it was drawn in
    -- the same rock tone as the mountain that stops you dead, which is the one confusion a tile this
    -- valuable cannot afford. It is a grassy slope, so it is green like the rest of the ground you may
    -- stand on, and the cost is said by the wash and the mark instead.
    hill    = { moveCost = 3, walkable = true, sightCost = 2, bonus = { range = 1, avoid = 30 },
                index = 2, color = { 0.28, 0.42, 0.22 } },
    -- Legacy penalty floor, still named by curated arenas. Broken ground: a modest edge to whoever is
    -- willing to pick their way across it.
    rough   = { moveCost = 2, walkable = true, sightCost = 0, bonus = { avoid = 10 },
                index = 3, color = { 0.34, 0.32, 0.30 } },
    -- A fort: a low work of piled stone, the one tile on the board built by hands rather than laid
    -- down by weather. THE TILE THIS WHOLE TABLE WAS MISSING. Fire Emblem's terrain design has an
    -- anchor and it is not the forest -- it is the fort: the square a defender takes and an attacker
    -- has to dig them out of. Every cover tile we had paid in EVASION, which is an answer for a body
    -- that would rather not be hit at all; nothing on the board rewarded a body whose entire plan is to
    -- be hit and stand there, which is a strange hole in a game with a knight house.
    --
    -- So it is priced against the hill and deliberately opposite to it. Cheaper to reach (two, not
    -- three), worth far less to a shooter (no reach at all, and sightCost 0 -- you can see out of a
    -- thing you stand BEHIND, which is the whole point of a parapet), and the only ground in the game
    -- that thickens a body's armour. The hill is the archer's tile; this is the wall's.
    --
    -- It also RENEWS, and that half is not written here: models/arena.lua seeds an unowned renewal zone
    -- onto every fort it lays (Arena.FORT_HAZARD). Healing ground is a hazard in this codebase and
    -- has been since long before this tile existed -- one word per mechanic -- and an unowned zone
    -- reads as allied to BOTH sides (Hazard.allied), which is the correct reading of a fort: it belongs
    -- to whoever got there first.
    fort    = { moveCost = 2, walkable = true, sightCost = 0,
                bonus = { avoid = 10, defense = 1 },
                index = 3, color = { 0.46, 0.42, 0.36 } },

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
    -- A mountain: sheer rock face. Impassable and it blocks the sight through it, so it is the tile
    -- a room is given sides with and the tile a board is given a wall with. A FLIER CROSSES IT --
    -- nothing special is written here for that, because `walkable = false` is exactly what
    -- Combat.isFlying overrides (models/combat.lua's moveGraph and route validator); a mountain bars
    -- the way by being poor footing on a grand scale, which is the argument the Zephyr Striders
    -- decline. What a flier still cannot cross is a WALL (models/wall.lua), which is an object.
    mountain = { moveCost = SOLID, walkable = false, sightCost = SOLID, index = 3, color = { 0.30, 0.28, 0.26 } },
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
    -- `swim` is the OTHER half of that sentence and is new: a body at home in water crosses this at a
    -- flat 1 whatever it costs everybody else (Combat.isAquatic, read in stepTerrainCost). The ford is
    -- the tile a naga and a knight both stand on and do not both pay the same for.
    --
    -- It also SOAKS now. models/arena.lua stands an unowned hazard_shallows on every one of these
    -- (Arena.TERRAIN_ZONES), granting Wet -- which lingers, so you walk out of the water still wet and
    -- dry on the status's own clock. Ground that does something to you is a hazard in this codebase and
    -- has been since long before this tile; the fort renews and the mire bogs by exactly this seam.
    water   = { moveCost = 2, walkable = true, sightCost = 0, tags = { "conductable" }, swim = true,
                index = 6, color = { 0.30, 0.50, 0.62 } },
    -- DEEP WATER: the black channel. Unwalkable, and it DROWNS what is put into it.
    --
    -- THE LOAD-BEARING DECISION IS `walkable = false`, and it is what keeps this tile from being a
    -- catastrophe. Every generator carve, every connectivity guard, every deployment filter and every
    -- enemy path already reads unwalkable correctly -- so a rolled channel can never cut a company off
    -- from the stair, and no player can ever walk into it by misclicking the move overlay. The
    -- alternative that was considered and rejected -- walkable in the table, closed per-unit at
    -- moveGraph -- would have made every one of those guards lie, silently, on exactly the boards where
    -- it mattered. This is `river` with one new field on it, not a new kind of thing.
    --
    -- SO WHO EVER MEETS IT? Two bodies. A swimmer (`swim`, above) opens it and stops in it the way a
    -- flier opens a mountain -- one tag, one predicate, the same two chokepoints. And ANYTHING THAT IS
    -- FORCED IN: a shove, a throw, a pull. footprintCanShift refuses unwalkable terrain because a body
    -- cannot STAND there, and water is the one landform a body can FALL into, so that refusal has one
    -- exception and this field is it. That is the whole mechanic: deep water is a threat somebody else
    -- delivers, never a button you press on yourself.
    --
    -- The drowning itself is NOT here. It is hazard_deep_water, stood on every one of these tiles by
    -- Arena.terrainZones -- one word per mechanic, and ground that kills is not the exception to the
    -- rule that says ground that heals and ground that bogs are hazards.
    --
    -- THE MOVE COST IS SOLID, like every other unwalkable tile's, and the swimmer's 1 is a SUBSTITUTION
    -- made at the price rather than a number written here. That is not a dodge around the invariant --
    -- it is the invariant kept. Unwalkable ground costs the earth so that nothing can route a body
    -- through a wall it may never stand on (tests/terrain_spec.lua), and a swimmer is not an exception
    -- to that: it is a body for which this ground is not a wall, and stepTerrainCost swaps the cost for
    -- exactly the bodies moveGraph has already admitted. A finite cost written HERE would be a hole
    -- every reach search in the game could fall into, for the sake of one that does not need it.
    --
    -- sightCost 0: you see across water and you shoot across it, which is the counterplay to a body
    -- standing in the middle of it. Conducts, like every other water in the table -- and that is the
    -- answer to a pack of nagas sharing one channel, which is the best reason the tile has to exist.
    deep    = { moveCost = SOLID, walkable = false, sightCost = 0, tags = { "conductable" },
                swim = true, drowns = true,
                index = 6, color = { 0.10, 0.20, 0.30 } },
    -- Loose sand: forest's cost without forest's cover, so a desert board is a long ranged exchange
    -- nobody can cross quickly or safely.
    sand    = { moveCost = 2, walkable = true, sightCost = 0, index = 2, color = { 0.78, 0.68, 0.44 } },

    -- ---- the cover each country grows -------------------------------------
    -- THE PARITY PAIR, and the one place in this table where sameness is the point rather than a
    -- failure of imagination. Every floor above is the deliberate inverse of another so a board plays
    -- differently for being made of it; these two are deliberate COPIES of the forest, because the
    -- thing they are fixing is that half the biomes had no cover at all.
    --
    -- Measured before they were written: a rolled board scatters a fill (2-5 tiles), a rise (1-3) and a
    -- blocker (1-3), and only the fill is ever cover. The default biome fills with forest and gets 3-8
    -- cover tiles; the desert filled with sand and the tundra with ice, both worth nothing, leaving
    -- 1-3 hills on 64 squares. Terrain is the positional decision this game took INSTEAD of facing
    -- (docs/accuracy.md), so a tundra board was a board with no positional decision on it.
    --
    -- Same numbers as the forest, then -- two to enter, +20 avoid, and enough bulk to break a sightline
    -- -- and the difference is the TAG, which is what a floor is made of rather than what it is worth.
    -- A dune neither burns nor conducts: it is the one piece of cover in the game that is inert, which
    -- is its whole character on a board where fire spreads through wood.
    dune    = { moveCost = 2, walkable = true, sightCost = 1,
                bonus = { avoid = 20 },
                index = 2, color = { 0.86, 0.74, 0.48 } },
    -- A snow drift: the tundra's cover, and wet through, so a lightning line that would clip one body
    -- on grass sweeps a whole front of men sheltering behind drifts. The tundra's floor already
    -- conducts; this makes the tundra's COVER conduct too, which is the reason to take a drift rather
    -- than simply the best tile going.
    drift   = { moveCost = 2, walkable = true, sightCost = 1, tags = { "conductable" },
                bonus = { avoid = 20 },
                index = 2, color = { 0.88, 0.92, 0.96 } },
    -- Frozen ground: the ONLY terrain that does not tax a step. What it charges instead is conduction --
    -- a lightning line that would clip one body on grass sweeps a whole frozen front.
    ice     = { moveCost = 1, walkable = true, sightCost = 0, tags = { "conductable" },
                index = 2, color = { 0.80, 0.86, 0.90 } },
    -- Sucking bog: ties the hill for the heaviest walkable floor and gives back LESS than nothing --
    -- no reach, no sight, and a body floundering in it is easier to hit than one on open ground. The
    -- only negative `avoid` in the table, and the tile's whole character: expensive to cross, worse
    -- than worthless to hold, the exact inverse of the hill it costs the same to enter.
    -- Wet through, so it conducts.
    mire    = { moveCost = 3, walkable = true, sightCost = 0, tags = { "conductable" },
                bonus = { avoid = -10 },
                index = 1, color = { 0.28, 0.34, 0.22 } },
}

-- Behaviour for `type`, always a complete table. An unknown or nil type answers as solid rather than as
-- open field: a tile nobody can name is a hole in the data, and a hole that reads as walkable puts a
-- body inside a wall, where a hole that reads as solid merely puts a wall on the board.
function Terrain.get(t)
    return Terrain.TYPES[t] or Terrain.TYPES.mountain
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
