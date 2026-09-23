-- Biome blueprint. A quest's `map.biome` names one of these; it sets the maze
-- node spacing and which tileset draws the map. Forest is loose: wide-apart trails
-- with chunky forest blocks between them.
return {
    -- A PLACE, not a terrain category (models/biome.lua's naming note). The veil is the web strung
    -- between its trees now -- the ambush this board is built to be.
    name = "Thornveil Wood",
    tileset = "forest", -- data/tilesets/forest.lua (art for this biome)
    layout = "glades", -- trails through thick wood that open into clearings (models/layouts/glades.lua)
    spacing = 4, -- 1-wide trails, (spacing - 1) = 3-tile-thick fill
    rivers = { min = 1, max = 2 }, -- number (or {min,max} range) of rivers
    -- Signature ground: WEB, which holds and Marks whoever steps in (data/hazards/hazard_web.lua).
    -- It WAS sweetbriar, which Charms, and its reason was "that is what this stratum IS: Lust's whole
    -- mechanic" -- written when the wood was Lust's. The wood is Gluttony's, a beast hunt, and the half
    -- of a hunt no animal here was fielding was the trap: something already strung across the glade
    -- before the bell. Sweetbriar went with Lust, onto the garden's own bodies (their `seedsGround`).
    -- A spider in the fight lays more of this on top (models/arena.lua, bodyGround).
    hazard = { id = "hazard_web", min = 2, max = 3 },
}
