-- Biome blueprint. The Colosseum's own ground: the bowl the house's card is fought on, and the only
-- biome in the game that is a BUILDING rather than a country (docs/story.md, "The Colosseum: wrath,
-- designed"). Every other ground is somewhere the company travels to; this one it walks into.
--
-- That is why the board is an oval of open floor and nothing else (models/layouts/sands.lua). There is
-- no route to read, no long way round, and no cover worth the name -- what a bout costs is decided by
-- what is standing on the sand and where you were when the gate came up. The desert is the nearest
-- thing to it in shape and is still a landscape; this is a room, and the wall is the same distance away
-- whichever way you run.
--
-- Its battle floor is `sand` (models/arena.lua): forest's move cost without forest's cover. On a plain
-- that makes a long ranged exchange; in a bowl with no exit it makes a fight nobody can back out of at
-- speed, which is the same rule doing the opposite job.
--
-- No rivers. Nothing runs through a floor the crowd paid to see.
--
-- Signature ground: grasping hollow -- the soft sand the house sets, seeded on the curated debut board
-- long before this biome existed (data/arenas/colosseum_sand.lua). Roots on entry, visible, and the
-- enemy AI routes around it: the ground is not neutral here, and it was never meant to be.
return {
    name = "Colosseum",
    tileset = "colosseum", -- data/tilesets/colosseum.lua (art for this biome)
    layout = "sands", -- one oval of floor, the furniture on it, the pens beneath (models/layouts/sands.lua)
    spacing = 2, -- kept for the shared passes; the carve has no lattice to read it off
    rivers = 0,
    hazard = { id = "hazard_grasping_hollow", min = 1, max = 2 },
}
