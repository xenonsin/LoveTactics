-- The Elder's length, and the vessel The Long Coil rides in.
--
-- A creature's rule lives on an ITEM in its grid -- a blueprint's own `traits` field is never collected
-- (models/trait.lua). Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Serpent's Length",
    description = "Increase the tether's bite for every tile past the circle.",
    flavor = "The young ones hold what they can reach. She has simply never agreed that reach is a limit.",
    sprite = "assets/items/serpents_length.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_the_long_coil" },
}
