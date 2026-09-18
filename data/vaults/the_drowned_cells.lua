-- Vault blueprint. THE DROWNED CELLS: a ring of cells around a flooded well, with the only dry thing
-- in the room sitting in the middle of it.
--
-- THE FIRST ONE, AND IT IS THE PROBE. The whole bet behind the vault system (round 4's A-1) is that a
-- floor with one authored thing in it reads differently from a floor with none -- and that is a
-- question worth answering for the price of one file before anybody builds a library. If it does not
-- read, this file and models/overworld.lua's placeVaults come back out and the generator is untouched.
--
-- HOW A VAULT IS WRITTEN. `map` is a block of characters stamped onto the floor, one character per
-- cell, and it is the whole of the geometry:
--
--   #   wall. Not there; the silhouette closes around it.
--   .   floor. Ordinary ground, but INSIDE the footprint -- so nothing rolled ever lands on it
--       (Overworld:placeVaults marks every cell it stamps). That is what makes the shape survive: a
--       merchant seated in the middle of the ring would be the generator talking over the author.
--   1-9 floor, and the nth entry in `contents` stands on it.
--
-- WHY THE CONTENTS ARE AUTHORED HERE rather than rolled at placement: a vault whose contents are rolled
-- is just a differently-shaped patch of the same floor. The shape is not what anybody remembers -- the
-- thing in it is. (Wizardry Variants Daphne's own rule, in its community guide's words: what is on a
-- tile "will always appear at the same place within the tile".)
--
-- IT ASKS FOR NO PARTICULAR BIOME. A ring of cells round a well reads in a swamp, a castle and an
-- underworld alike, and the first vault should be one that can turn up anywhere -- a library gated to
-- one circle is six circles with nothing in them.
return {
    name = "The Drowned Cells",

    -- 5x5. Small on purpose: a vault has to FIT, and the floor it lands on is 11x11 at the top of the
    -- stack (Descent.floorDims). Two of these would be most of a floor, which is why only one is ever
    -- placed -- see Descent.FLOOR_VAULTS.
    map = {
        "##.##",
        "#...#",
        "..1..",
        "#...#",
        "##.##",
    },

    -- WHAT IS IN THE MIDDLE, and it is one thing rather than a pile. The room is the reward's frame:
    -- four ways in, no cover, and whatever is standing in the water is standing between the company and
    -- the only thing worth walking in for.
    contents = {
        { kind = "treasure", name = "The Well" },
    },
}
