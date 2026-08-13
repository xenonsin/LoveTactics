-- Biome blueprint. Castle is tight: dense corridors with thin walls, a
-- stronghold's warren of passages rather than open wilderness.
return {
    name = "Castle",
    tileset = "castle", -- data/tilesets/castle.lua (art for this biome)
    layout = "rooms", -- chambers and halls, cut by recursive splits (models/layouts/rooms.lua)
    spacing = 2, -- kept for the river band; the carve no longer reads it
    rivers = 0,  -- no rivers indoors
}
