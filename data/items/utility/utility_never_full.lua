-- NEVER FULL: the Hungry Ghost's organ (data/characters/character_hungry_ghost.lua). Approved 2026-10-09 ("The
-- Crown's Bestiary", slice E): any heal or draught that lands on a body within 2 is eaten, and the ghost is healed
-- instead (trait_never_full, models/lethe.lua). Bound and unstealable: an organ, never kit.
return {
    name = "Never Full",
    description = "Heals that land on any body within 2 heal this body instead.",
    flavor = "The mouth is the size of a needle's eye. It has never once been full, and it never stops trying.",
    sprite = "assets/items/utility_never_full.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_never_full" },
}
