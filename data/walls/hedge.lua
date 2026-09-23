-- A quickset hedge: green wood called up out of a floor that had none, by the Dryad line's Quickset
-- (and by a company that carries the spell out of the Rood Loft).
--
-- A WALL IN EVERY WAY THE BOARD CARES ABOUT -- it bars a step, screens a line, and is what a shove
-- slams into (Combat.knockback bills the impact of a shove it could not finish). Which is the point of
-- it: a fight board is eight by eight with a few blockers scattered on it, so the walls a Dryad throws
-- you into are the ones she grows first.
--
-- `illusion`, so a Dispel clears it as it clears every other conjured barrier -- a mage's answer -- and
-- `burnable`, so the ground under it answers a torch the way the thorn floor does. Tagged `nature` for
-- the Nymph's Greenstep, which reads a hedge as one of the plants she may step between.
return {
    name = "Hedge",
    description = "A quickset hedge. Blocks movement and line of sight until cut down or dispelled.",
    sprite = "assets/items/hedge.png",
    health = 16,
    blocksMove = true,
    sightCost = 2,
    duration = 24,
    tags = { "illusion", "structure", "nature", "burnable" },
}
