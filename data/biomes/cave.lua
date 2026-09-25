-- Biome blueprint: Greed's ground, the halls under the mountain (2026-09-24, on Keno's call -- "put greed
-- biome in a mountain or cave not castle"). Greed took the castle off Lust in the swap and held it for an
-- afternoon; the dwarves it was filled with belong in the rock they dug, not in a keep somebody built on
-- top of it. Delving deeper is the circle's own verb, and a cave is where that verb lives.
--
-- THE CAVERNS CARVE (bellies and necks), shared with the Underworld at the bottom of the rift -- but not
-- its board: that one's walls are black water, these are the mountain's own rock, and the rivers are
-- gone, because a mine is dug above the water table on purpose. What it has instead is LAVA PITS -- one to
-- three a board, where the mine was struck too deep (models/arena.lua's scatter table; Keno, 2026-09-24).
return {
    -- A PLACE, not a terrain category (models/biome.lua's naming note): compound + landform, no article.
    name = "Goldvein Deeps",
    tileset = "cave", -- data/tilesets/cave.lua (art for this biome)
    layout = "caverns", -- cellular automata: bellies and necks
    spacing = 2, -- kept for the river band; the carve no longer reads it
    rivers = 0,  -- a mine is dug dry
    -- Signature ground: loose gold (data/hazards/hazard_coin_heap.lua). A dwarf goes for a heap and
    -- sickens on it; the company that loots one banks it and sets every dwarf on the board on itself.
    -- Two to four a board, so a dwarf fight always has something on the floor to run for.
    hazard = { id = "hazard_coin_heap", min = 2, max = 4 },
}
