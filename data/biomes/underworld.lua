-- Biome blueprint. The Underworld is the tightest of the three and the only one with rivers indoors:
-- corridors of cooling rock threaded by channels of something that is not water. Wide enough to walk,
-- never wide enough to withdraw.
--
-- Reached only through data/quests/the_gate_below.lua, once all seven generals are dead.
return {
    name = "The Underworld",
    tileset = "underworld", -- data/tilesets/underworld.lua (art for this biome)
    spacing = 2, -- 1-wide corridors, 1-tile-thick walls, as tight as the castle
    rivers = { min = 2, max = 3 }, -- rivers of fire; the bridges over them are the map's real doors
}
