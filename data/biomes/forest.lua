-- Biome blueprint. A quest's `map.biome` names one of these; it sets the maze
-- node spacing and which tileset draws the map. Forest is loose: wide-apart trails
-- with chunky forest blocks between them.
return {
    name = "Forest",
    tileset = "forest", -- data/tilesets/forest.lua (art for this biome)
    layout = "glades", -- trails through thick wood that open into clearings (models/layouts/glades.lua)
    spacing = 4, -- 1-wide trails, (spacing - 1) = 3-tile-thick fill
    rivers = { min = 1, max = 2 }, -- number (or {min,max} range) of rivers
    -- Signature ground: sweetbriar, which Charms whoever blunders into it. Forest was one of three
    -- biomes shipping with no hazard at all, so its circle read as a tileset rather than a place. Charm
    -- because that is what this stratum IS: being called out of your line is Lust's whole mechanic, and
    -- the glades carve is the game's ambush board -- a body pulled out of formation is a body fighting
    -- alone in cover. See data/hazards/hazard_sweetbriar.lua.
    hazard = { id = "hazard_sweetbriar", min = 1, max = 2 },
}
