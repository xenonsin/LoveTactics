-- Rubble: a slab of a golem, knocked off by a blow of weight (trait_shed_plate -- the Earth Golem's
-- Shed Plate and the company's Shale Plating). Reviewed 2026-09-25, "The Golems of Greed".
--
-- A WALL IN EVERY WAY THE BOARD CARES ABOUT, like the Dryad's hedge: it bars a step, screens a line, and
-- is what a shove slams into. So a golem fight changes shape over its own length -- every plate the mace
-- takes off is one more piece of cover on the floor. Not an `illusion`: it is rock, and a Dispel has
-- nothing to unmake. It stands until something breaks it (or a Veinfinder mines it for the gold in it).
return {
    name = "Rubble",
    description = "A fallen slab of rock. Blocks movement and line of sight until broken.",
    sprite = "assets/items/rubble.png",
    health = 14,
    blocksMove = true,
    sightCost = 2,
    tags = { "structure", "earth" },
}
