-- Castle biome tileset (art only). Tile types + walkability are universal and
-- live in models/tileset.lua; here we only name the spritesheet and the pre-art
-- fallback colours (cold stone walls, flagstone floors, a dark moat) so a castle
-- map reads visibly different from the forest even before art exists.
return {
    image = "assets/overworld/castle.png",
    tileSize = 16,
    tiles = {
        forest = { color = { 0.20, 0.20, 0.23 } }, -- stone wall block (the "fill")
        grass  = { color = { 0.24, 0.26, 0.22 } }, -- mossy stone
        rock   = { color = { 0.40, 0.40, 0.44 } }, -- lighter masonry
        path   = { color = { 0.46, 0.42, 0.37 } }, -- flagstone corridor
        bridge = { color = { 0.50, 0.38, 0.24 } }, -- timber drawbridge
        water  = { color = { 0.14, 0.24, 0.40 } }, -- moat
    },
}
