-- Tundra biome tileset (art only). Tile types + walkability are universal and live in
-- models/tileset.lua; here we only name the spritesheet and the pre-art fallback colours.
--
-- A tundra's "forest" fill is a snow drift and its "bridge" is a span of ice. The hard problem in this
-- palette is that snow wants to be white and so does the trail, so the trodden path is kept the
-- BLUEST rather than the brightest thing here -- otherwise the route vanishes into the drifts.
--
-- Until assets/overworld/tundra.png exists, the widget draws the `color` rects (see models/sprite.lua's
-- tolerant loader), so the map is playable before art.
return {
    image = "assets/overworld/tundra.png",
    tileSize = 16,
    tiles = {
        thicket = { color = { 0.86, 0.89, 0.93 } }, -- drift: bright, impassable
        grass  = { color = { 0.72, 0.77, 0.80 } }, -- frozen tussock breaking the snow
        rock   = { color = { 0.48, 0.52, 0.58 } }, -- frost-split stone
        path   = { color = { 0.56, 0.66, 0.78 } }, -- trodden snow, shadowed blue so the route reads
        bridge = { color = { 0.66, 0.80, 0.88 } }, -- a span of ice
        river  = { color = { 0.20, 0.38, 0.52 } }, -- meltwater: the cold that never set
    },
}
