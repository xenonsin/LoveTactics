-- Forest biome tileset (art only). Tile types + walkability are universal and
-- live in models/tileset.lua; here we only name the spritesheet and the pre-art
-- fallback colours (leafy greens, brown trails). `index` may be overridden per
-- type if this sheet's layout differs from the canonical row-major order.
--
-- Until assets/overworld/forest.png exists, the widget draws the `color` rects
-- (see models/sprite.lua's tolerant loader), so the map is playable before art.
return {
    image = "assets/overworld/forest.png",
    tileSize = 16,
    tiles = {
        forest = { color = { 0.10, 0.24, 0.12 } }, -- dense canopy fill
        grass  = { color = { 0.16, 0.32, 0.16 } },
        rock   = { color = { 0.34, 0.32, 0.30 } },
        path   = { color = { 0.42, 0.30, 0.18 } }, -- dirt trail
        bridge = { color = { 0.55, 0.40, 0.22 } },
        water  = { color = { 0.18, 0.34, 0.55 } }, -- river
    },
}
