-- Colosseum biome tileset (art only). Tile types + walkability are universal and live in
-- models/tileset.lua; here we only name the spritesheet and the pre-art fallback colours.
--
-- Two materials and nothing else, which is what makes the bowl read as one object: raked SAND, and the
-- grey STONE of everything the house built -- the stands that ring it, the barriers set out for the
-- card, the pens underneath. The floor is the lightest thing here by a distance, so from any height the
-- oval is the first thing the eye finds.
--
-- Warmer and greyer than the desert's palette on purpose: that sand is a country and this is a floor,
-- swept, watered and walked on, with the colour of the crowd's shadow on it.
--
-- Until assets/overworld/colosseum.png exists, the widget draws the `color` rects (see models/sprite.lua's
-- tolerant loader), so the map is playable before art.
--
-- AND ONE TILE IS RESKINNED, for the same reason the castle's is (data/tilesets/castle.lua, which
-- carries the full note). `mountain` is the board's impassable solid; in this bowl there is no
-- landform of any kind, so it draws set stone and is called a pillar -- which is what the arenas
-- already call it in their own comments (data/arenas/colosseum_sand.lua's shoulder pillars and funnel
-- walls). Everything standing on this floor was carried in and set down for the card, and a
-- snow-capped peak in the middle of it would say the opposite.
return {
    image = "assets/overworld/colosseum.png",
    tileSize = 16,
    tiles = {
        thicket = { color = { 0.34, 0.32, 0.31 } }, -- the stands: the wall the bowl is cut out of
        -- No `color`: an impassable tile's tone comes from the `rock` art role above.
        mountain = { skin = "masonry", name = "Pillar",
                     desc = "Set stone, carried in for the card. Blocks movement and line of sight -- only a flier gets over it." },
        grass  = { color = { 0.42, 0.40, 0.38 } }, -- worn stone, pale where the seats have been sat on
        rock   = { color = { 0.52, 0.49, 0.45 } }, -- the barriers and pillars set out on the sand
        path   = { color = { 0.82, 0.72, 0.52 } }, -- the sand itself, raked
        bridge = { color = { 0.55, 0.42, 0.26 } }, -- the timber of a gate ramp
        river  = { color = { 0.42, 0.16, 0.16 } }, -- the drain. It is not water and everyone knows it
    },
}
