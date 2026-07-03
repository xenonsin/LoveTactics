-- Overworld tileset descriptor. Plain data (no love.graphics), so it is safe to
-- require under the headless test suite.
--
-- `models/overworld.lua` reads the per-type `walkable` flags to decide what the
-- player can step on; `ui/overworld_map.lua` reads `image`/`tileSize`/`index` to
-- slice the spritesheet into quads and batch-draw the map. Each grid cell stores
-- a tile-type string (the keys below); the widget maps that to `index`.
--
-- `index` is a 1-based tile number into the sheet, row-major:
--   index 1 = top-left, then left-to-right, wrapping by (image width / tileSize).
--
-- Add a tile type = one row here plus art in the sheet. Until the art file
-- exists, the widget falls back to the `color` below (see models/sprite.lua's
-- tolerant loader).
return {
    image = "assets/overworld/tileset.png",
    tileSize = 16,
    tiles = {
        -- type      index  walkable  fallback color (RGB 0..1) used pre-art
        forest = { index = 1,  walkable = false, color = { 0.10, 0.24, 0.12 } },
        grass  = { index = 2,  walkable = false, color = { 0.16, 0.32, 0.16 } },
        rock   = { index = 3,  walkable = false, color = { 0.34, 0.32, 0.30 } },
        path   = { index = 4,  walkable = true,  color = { 0.42, 0.30, 0.18 } },
        bridge = { index = 5,  walkable = true,  color = { 0.55, 0.40, 0.22 } },
        water  = { index = 6,  walkable = false, color = { 0.18, 0.34, 0.55 } },
    },
}
