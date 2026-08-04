-- Biome blueprint. Desert is the widest board in the game: long open runs between thin ridges of
-- rock, the loosest maze the generator draws. Where the forest hides you and the castle corners you,
-- the desert simply makes you walk -- there is nowhere to be that is not seen.
--
-- Its battle floor is `sand` (models/arena.lua): forest's move cost without forest's cover, so a
-- desert fight is a long ranged exchange that neither side can cross quickly or safely.
--
-- Signature ground: quicksand. Mired doubles what a step and a cast cost, which on the one board
-- already built around slow crossings is the difference between arriving and not.
return {
    name = "Desert",
    tileset = "desert", -- data/tilesets/desert.lua (art for this biome)
    spacing = 5, -- 1-wide tracks, 4-tile-thick dune fill: the loosest maze, longest sightlines
    rivers = { min = 0, max = 1 }, -- a wadi at most; water here is the exception, not the terrain
    hazard = { id = "hazard_quicksand", min = 1, max = 2 },
}
