-- Biome blueprint. Tundra is open ground gone hard: broad frozen flats broken by drifts, with rivers
-- that never quite froze running through them.
--
-- Its battle floor is `ice` (models/arena.lua), the one terrain feature in the game that does not tax a
-- step -- every other floor costs more than open field, ice costs the same. So where another biome's
-- scattered fill slows a crossing, the tundra's does not slow it at all: this is the board with no
-- movement obstacles on it, and both lines close as fast as they like.
--
-- What it charges instead is conduction. Ice carries a charge the way a river does, so a lightning line
-- that would clip one body on grass sweeps a whole frozen front. Free to cross, expensive to stand on.
--
-- Signature ground: black ice, which Cripples whoever finds it -- the only thing on the board that
-- costs a step, which is what makes the ROUTE across an otherwise open field worth choosing.
return {
    name = "Tundra",
    tileset = "tundra", -- data/tilesets/tundra.lua (art for this biome)
    spacing = 3, -- between the forest's open trails and the castle's warren
    rivers = { min = 1, max = 2 }, -- meltwater leads: the part of the cold that did not set
    hazard = { id = "hazard_black_ice", min = 1, max = 3 },
}
