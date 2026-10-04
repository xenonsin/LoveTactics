-- Roots: the Old Spruce's, spreading a tile at the end of each of its turns (trait_will_not_be_hurried), and the
-- Spruce Staff's, rising beside a druid who struck nothing (trait_spruce_staff). "Sloth's Bestiary", 2026-10-04.
--
-- A WALL IN THE ONE WAY THAT MATTERS: nothing crosses it, on either side, and a wall bars a flier too
-- (Combat.objectBlocksAt). It does NOT screen a line of sight -- it is a root across the ground, not a hedge --
-- so an archer still shoots over it, which is the counter the review gave: kill from range, or burn the tree.
-- Not an `illusion`: it is wood, and a Dispel has nothing to unmake. It stands until it is cut down.
return {
    name = "Roots",
    description = "Spruce roots. Nothing crosses them until they are cut down.",
    sprite = "assets/items/roots.png",
    health = 14,
    blocksMove = true,
    sightCost = 0,
    tags = { "structure", "nature", "burnable" },
}
