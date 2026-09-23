-- The Matriarch's flight feathers, and the vessel Downdraft rides in.
--
-- A creature's rule lives on an ITEM in its grid -- a blueprint's own `traits` field is never collected
-- (models/trait.lua). Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Flight Feathers",
    description = "When struck in melee, drives everything adjacent back a tile.",
    flavor = "Long enough to be a cloak, and she wears them the way a saint is painted wearing one.",
    sprite = "assets/items/flight_feathers.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_downdraft" },
}
