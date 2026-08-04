-- Swamp biome tileset (art only). Tile types + walkability are universal and live in
-- models/tileset.lua; here we only name the spritesheet and the pre-art fallback colours.
--
-- Kin to the forest's palette and deliberately a few degrees sicker: the greens are pushed toward
-- yellow-grey rather than leaf, and the standing water is the brownest in the game. The forest reads
-- as somewhere you walk through; this should read as somewhere you wade.
--
-- Until assets/overworld/swamp.png exists, the widget draws the `color` rects (see models/sprite.lua's
-- tolerant loader), so the map is playable before art.
return {
    image = "assets/overworld/swamp.png",
    tileSize = 16,
    tiles = {
        forest = { color = { 0.16, 0.22, 0.15 } }, -- mangrove thicket: the impassable fill
        grass  = { color = { 0.28, 0.32, 0.18 } }, -- sedge and reed, yellowed
        rock   = { color = { 0.30, 0.33, 0.28 } }, -- a mossed-over boulder
        path   = { color = { 0.36, 0.31, 0.20 } }, -- churned mud and boardwalk
        bridge = { color = { 0.48, 0.38, 0.24 } }, -- old timber over the channel
        water  = { color = { 0.22, 0.26, 0.20 } }, -- brackish standing water, barely lighter than fill
    },
}
