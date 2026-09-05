-- The Unquenched's gut, and the vessel Drinks the Fire rides in.
--
-- A creature's rule lives on an ITEM in its grid -- a blueprint's own `traits` field is never collected
-- (models/trait.lua). Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Quenchless Gut",
    description = "Heals as it acts, if it is standing in fire.",
    flavor = "It went into the rift to put itself out. It came back with a taste for it.",
    sprite = "assets/items/quenchless_gut.png",
    type = "utility",
    class = "creature",
    dropTier = 2,
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_drinks_the_fire" },
}
