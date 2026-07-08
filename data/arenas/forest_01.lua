-- Curated battle arena (a layout: tile types + spawn positions, no bound units). The
-- biome tag makes models/arena.lua prefer this over procedural generation for forest
-- quests. Party ids fill partySpawns and the encounter's scaled enemy roster fills
-- enemySpawns (extras beyond the listed spawns are dropped). Hand-edit freely, or
-- capture a fresh one in-battle with the F5 debug save. See models/arena.lua.
return {
    -- Terrain shapes the fight through both movement AND line of sight: the central `obstacle`
    -- rocks are solid (block movement + sight), while `forest` is soft cover that only LOWERS
    -- sight -- a single copse still lets an arrow through, but the stacked pair at column 3
    -- (rows 4-5) fully screens that lane. Ranged abilities (bow / fireball / jolt) need a clear
    -- line, so units angle around cover. See models/arena.lua TILE_PROPS + models/combat.lua.
    biome = "forest",
    tiles = {
        { "ground", "ground", "ground", "ground",   "ground",   "ground", "ground", "ground" },
        { "ground", "ground", "ground", "forest",   "ground",   "ground", "ground", "ground" },
        { "ground", "forest", "ground", "ground",   "ground",   "ground", "forest", "ground" },
        { "ground", "ground", "forest", "obstacle", "obstacle", "forest", "ground", "ground" },
        { "ground", "ground", "forest", "obstacle", "obstacle", "forest", "ground", "ground" },
        { "ground", "forest", "ground", "ground",   "ground",   "ground", "forest", "ground" },
        { "ground", "ground", "ground", "ground",   "forest",   "ground", "ground", "ground" },
        { "ground", "ground", "ground", "ground",   "ground",   "ground", "ground", "ground" },
    },
    partySpawns = {
        { x = 2, y = 8 }, { x = 4, y = 8 }, { x = 6, y = 8 },
    },
    enemySpawns = {
        { x = 2, y = 1 }, { x = 4, y = 1 }, { x = 6, y = 1 },
        { x = 3, y = 2 }, { x = 5, y = 2 }, { x = 7, y = 2 },
    },
    -- Authored enemy traps in the mid-field lanes the party advances through (hidden from the
    -- player until a unit carrying a "detect traps" item comes within range). See models/trap.lua.
    traps = {
        { id = "spike_trap", x = 3, y = 4, side = "enemy" },
        { id = "snare_trap", x = 6, y = 5, side = "enemy" },
    },
}
