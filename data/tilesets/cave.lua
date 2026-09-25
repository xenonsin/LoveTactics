-- Cave biome tileset (art only): Greed's halls under the mountain (data/biomes/cave.lua). Tile types and
-- walkability are universal and live in models/tileset.lua; here we only name the spritesheet and the
-- pre-art fallback colours, so the map reads as the dwarves' deeps before any art exists: grey-blue rock,
-- worked stone floors, and seams of gold where the forest keeps its water.
return {
    image = "assets/overworld/cave.png",
    tileSize = 16,
    tiles = {
        thicket = { color = { 0.16, 0.17, 0.20 } }, -- living rock (the "fill")
        grass  = { color = { 0.30, 0.30, 0.32 } }, -- worked stone
        rock   = { color = { 0.40, 0.39, 0.40 } }, -- rubble
        path   = { color = { 0.36, 0.34, 0.31 } }, -- a hall's swept floor
        bridge = { color = { 0.48, 0.42, 0.30 } }, -- a timbered span
        river  = { color = { 0.74, 0.60, 0.22 } }, -- a seam of gold
    },
}
