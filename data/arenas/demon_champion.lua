-- The Demon Champion's battlefield: the capstone arena the flight leg ends on. Bound to the objective
-- by name (states/prologue.lua's FLIGHT_QUEST.map.objective.layout = "demon_champion", read by
-- states/battle.lua's specFor), and `fixed = true` so it is never rolled into an ordinary forest
-- fight's pool -- it is addressable only when something names it.
--
-- Every cell is load-bearing (like data/arenas/tutorial_village.lua), and each terrain lever answers a
-- stage of the fight (see data/characters/character_demon_champion.lua):
--   * THE NECK (y4): a wall of `obstacle` with a two-wide gap at x4-5 -- the only north-south passage,
--     so the slow Champion must squeeze it (the stage-1 kite/brace beat). The flanking obstacles double
--     as knockback walls: shove the Champion north when it stands at x3 or x6 and it slams into them for
--     doubled impact (the stage-3 finisher).
--   * HIGH GROUND (y7): two `mountain` tiles (+1 range, sight-screening) -- the bow perches that
--     overlook the lane while the Champion approaches.
--   * BURNABLE TREELINE (y2 / y5): `forest` clumps -- the Fire Bolt ignition target and the soft cover
--     the Bomblets use. The Roar's Bomblets arrive beside the Champion around y5, into AoE range.
--   * WATER POOL (y6, x4-5): `conductable` -- the natural melee tile just south of the gap (a Jolt
--     rewards it), and, with the neck, a firebreak that keeps the treeline fire off the party's side.
--
-- The authored `hazards` below (a smouldering treeline near the enemy spawn) are carried into combat by
-- models/arena.lua's Arena.build and placed by Combat.new -- the reusable arena-authored-hazard seam.
return {
    biome = "forest",
    fixed = true, -- addressable by name (spec.layout); never rolled by an ordinary forest fight
    -- x:  1          2         3           4         5         6           7         8
    tiles = {
        { "ground",   "ground", "ground",   "ground", "ground", "ground",   "ground", "ground" }, -- y1 enemy back line
        { "ground",   "ground", "forest",   "ground", "ground", "forest",   "ground", "ground" }, -- y2 smouldering treeline
        { "ground",   "ground", "ground",   "ground", "ground", "ground",   "ground", "ground" }, -- y3 approach
        { "obstacle", "obstacle","obstacle", "ground", "ground", "obstacle", "obstacle","obstacle" }, -- y4 THE NECK (gap x4-5)
        { "ground",   "ground", "forest",   "ground", "ground", "forest",   "ground", "ground" }, -- y5 burnable shoulders
        { "ground",   "forest", "ground",   "water",  "water",  "ground",   "forest", "ground" }, -- y6 pool + treeline
        { "ground",   "ground", "mountain", "ground", "ground", "mountain", "ground", "ground" }, -- y7 PLAYER HIGH GROUND
        { "ground",   "ground", "ground",   "ground", "ground", "ground",   "ground", "ground" }, -- y8 party back line
    },
    -- Slot 1 = avatar, slot 2 = Rowan (Arena.build binds in party order); the rest are spare.
    partySpawns = {
        { x = 4, y = 8 }, { x = 5, y = 8 },
        { x = 3, y = 8 }, { x = 6, y = 8 },
    },
    -- Composition order: champion, imp, imp. The Champion is aligned to the gap; the imps flank it.
    enemySpawns = {
        { x = 4, y = 1 }, { x = 2, y = 2 }, { x = 7, y = 2 },
    },
    -- The world is already burning from the assault: a smouldering patch on the enemy-side treeline.
    -- The non-contiguous forest and the water pool keep it from ever reaching the party's line.
    hazards = {
        { id = "hazard_fire", x = 3, y = 2 },
        { id = "hazard_fire", x = 6, y = 2 },
    },
}
