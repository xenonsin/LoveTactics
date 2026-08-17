-- Biome blueprint. Castle is tight: dense corridors with thin walls, a
-- stronghold's warren of passages rather than open wilderness.
return {
    name = "Castle",
    tileset = "castle", -- data/tilesets/castle.lua (art for this biome)
    layout = "rooms", -- chambers and halls, cut by recursive splits (models/layouts/rooms.lua)
    spacing = 2, -- kept for the river band; the carve no longer reads it
    rivers = 0,  -- no rivers indoors
    -- Signature ground: a threshold, which Disarms whoever stands in it. Pride's circle is built on
    -- adjacency, and the rooms carve makes a doorway the place a rank comes apart -- so the tile that
    -- BREAKS a formation also punishes whoever holds it, and pulling them through one at a time costs
    -- something to execute. See data/hazards/hazard_threshold.lua.
    hazard = { id = "hazard_threshold", min = 1, max = 3 },
}
