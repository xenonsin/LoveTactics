-- Biome blueprint. The Underworld is the tightest of the three and the only one with rivers indoors:
-- corridors of cooling rock threaded by channels of something that is not water. Wide enough to walk,
-- never wide enough to withdraw.
--
-- Reached only through data/quests/quest_the_gate_below.lua, once all seven generals are dead.
return {
    name = "The Underworld",
    tileset = "underworld", -- data/tilesets/underworld.lua (art for this biome)
    layout = "caverns", -- cellular automata: bellies and necks (models/layouts/caverns.lua)
    spacing = 2, -- kept for the river band; the carve no longer reads it
    rivers = { min = 2, max = 3 }, -- rivers of fire; the bridges over them are the map's real doors
    -- Signature ground: a spoil heap, which Exposes whoever stands in it -- head down, hands full, in a
    -- warren where something is always coming round the corner. The only hazard in the game a player
    -- should WANT to step in, which is the sharpest small statement Greed has.
    -- See data/hazards/hazard_spoil_heap.lua.
    hazard = { id = "hazard_spoil_heap", min = 1, max = 2 },
}
