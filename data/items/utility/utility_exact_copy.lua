-- EXACT COPY: the Doppelganger's organ (data/characters/character_doppelganger.lua). Reviewed 2026-10-01..03
-- ("Envy's Bestiary"). At the opening bell its bearer becomes an exact copy of the nearest of the company and keeps
-- it until it dies (trait_exact_copy, models/masks.lua). Bound and unstealable: what the body is, never kit.
return {
    name = "Exact Copy",
    description = "At the start of the fight, become an exact copy of the nearest foe: stats, kit and tactics.",
    flavor = "It has never had a face of its own. It has never needed one; there is always someone nearer.",
    sprite = "assets/items/utility_exact_copy.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_exact_copy" },
}
