-- Biome blueprint. A quest's `map.biome` names one of these; it sets the maze
-- node spacing (and, later, tileset/props). Forest is loose: wide-apart trails
-- with chunky forest blocks between them.
return {
    name = "Forest",
    spacing = 4, -- 1-wide trails, (spacing - 1) = 3-tile-thick fill
    rivers = { min = 1, max = 2 }, -- number (or {min,max} range) of rivers
}
