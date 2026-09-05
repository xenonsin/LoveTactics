-- The Winter Hart's pelt, and the vessel Conduction rides in.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Hoarfrost Pelt",
    description = "Leaves black ice on the tile it is standing on as it acts.",
    flavor = "Whatever the cold wanted from it, it got, and then it kept the animal as well.",
    sprite = "assets/items/hoarfrost_pelt.png",
    type = "utility",
    class = "creature",
    dropTier = 2,
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_conduction" },
}
