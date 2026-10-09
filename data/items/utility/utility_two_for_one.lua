-- TWO FOR ONE: the Lernaean Hydra's organ (data/characters/character_lernaean_hydra.lua). Approved 2026-10-09
-- ("The Crown's Bestiary", slice E): three heads at the bell, a big slash takes one and two grow back (up to 6),
-- and fire stops the growing for two turns (trait_two_for_one, models/lerna.lua). Bound and unstealable.
return {
    name = "Two for One",
    description = "Opens with 3 heads. A slash of a tenth of its health takes one; two grow back. Fire stops growth.",
    flavor = "Heracles needed a nephew with a torch. Most companies bring swords and learn why.",
    sprite = "assets/items/utility_two_for_one.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_two_for_one" },
}
