-- Underworld biome tileset (art only). Tile types + walkability are universal and live in
-- models/tileset.lua; here we only name the spritesheet and the pre-art fallback colours, so the
-- final map reads as somewhere else entirely even before art exists: black basalt, ash floors, and
-- rivers of molten rock where the forest keeps its water.
return {
    image = "assets/overworld/underworld.png",
    tileSize = 16,
    tiles = {
        forest = { color = { 0.10, 0.08, 0.09 } }, -- basalt block (the "fill")
        grass  = { color = { 0.22, 0.15, 0.14 } }, -- cooled slag
        rock   = { color = { 0.32, 0.24, 0.23 } }, -- broken stone
        path   = { color = { 0.28, 0.20, 0.19 } }, -- ash underfoot
        bridge = { color = { 0.38, 0.30, 0.26 } }, -- a span of fused bone
        water  = { color = { 0.72, 0.24, 0.08 } }, -- a river of fire
    },
}
