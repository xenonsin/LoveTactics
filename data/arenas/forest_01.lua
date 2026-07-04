-- Curated battle arena (a layout: tile types + spawn positions, no bound units). The
-- biome tag makes models/arena.lua prefer this over procedural generation for forest
-- quests. Party ids fill partySpawns and the encounter's scaled enemy roster fills
-- enemySpawns (extras beyond the listed spawns are dropped). Hand-edit freely, or
-- capture a fresh one in-battle with the F5 debug save. See models/arena.lua.
return {
    biome = "forest",
    tiles = {
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" },
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" },
        { "ground", "rough",  "ground", "ground", "ground", "ground", "rough",  "ground" },
        { "ground", "ground", "ground", "obstacle", "obstacle", "ground", "ground", "ground" },
        { "ground", "ground", "ground", "obstacle", "obstacle", "ground", "ground", "ground" },
        { "ground", "rough",  "ground", "ground", "ground", "ground", "rough",  "ground" },
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" },
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" },
    },
    partySpawns = {
        { x = 2, y = 8 }, { x = 4, y = 8 }, { x = 6, y = 8 },
    },
    enemySpawns = {
        { x = 2, y = 1 }, { x = 4, y = 1 }, { x = 6, y = 1 },
        { x = 3, y = 2 }, { x = 5, y = 2 }, { x = 7, y = 2 },
    },
}
