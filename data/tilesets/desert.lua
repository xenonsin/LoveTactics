-- Desert biome tileset (art only). Tile types + walkability are universal and live in
-- models/tileset.lua; here we only name the spritesheet and the pre-art fallback colours.
--
-- The role each type plays is the biome's to reinterpret: a desert's "forest" fill is a dune crest and
-- its "water" is the pool at the bottom of a wadi. Bleached, high-key and low-contrast between the
-- fills, so the trail is the only thing that reads as a route -- which is the point of the place.
--
-- Until assets/overworld/desert.png exists, the widget draws the `color` rects (see models/sprite.lua's
-- tolerant loader), so the map is playable before art.
return {
    image = "assets/overworld/desert.png",
    tileSize = 16,
    tiles = {
        forest = { color = { 0.76, 0.62, 0.38 } }, -- dune crest: the impassable fill
        grass  = { color = { 0.70, 0.66, 0.44 } }, -- dry scrub
        rock   = { color = { 0.55, 0.46, 0.36 } }, -- weathered sandstone
        path   = { color = { 0.86, 0.76, 0.54 } }, -- packed track, the lightest thing on the board
        bridge = { color = { 0.60, 0.45, 0.28 } }, -- planks over the wadi
        water  = { color = { 0.30, 0.52, 0.52 } }, -- the pool at its bottom: the only cool note here
    },
}
