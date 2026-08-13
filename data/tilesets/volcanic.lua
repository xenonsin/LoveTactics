-- Volcanic biome tileset (art only). Tile types + walkability are universal and live in
-- models/tileset.lua; here we only name the spritesheet and the pre-art fallback colours.
--
-- Deliberately warmer and lighter than the underworld's, which shares the same vocabulary of rock and
-- fire: this is a volcanic SURFACE under daylight, and the two must not read as the same place. The
-- underworld's basalt is near-black; here it is a hot grey-brown with sun on it.
--
-- Until assets/overworld/volcanic.png exists, the widget draws the `color` rects (see
-- models/sprite.lua's tolerant loader), so the map is playable before art.
return {
    image = "assets/overworld/volcanic.png",
    tileSize = 16,
    tiles = {
        thicket = { color = { 0.32, 0.26, 0.24 } }, -- basalt block: the impassable fill
        grass  = { color = { 0.42, 0.35, 0.31 } }, -- cooled slag
        rock   = { color = { 0.52, 0.44, 0.40 } }, -- broken stone, sun-bleached
        path   = { color = { 0.66, 0.60, 0.55 } }, -- ash underfoot, pale against the rock
        bridge = { color = { 0.46, 0.34, 0.26 } }, -- a fused span across the flow
        river  = { color = { 0.86, 0.34, 0.14 } }, -- the flow itself: the only saturated thing here
    },
}
