-- LETHE HAZE: the Lethe-Drinker's organ (data/characters/character_lethe_drinker.lua). Approved 2026-10-09 ("The
-- Crown's Bestiary", slice E): "It carries the river with it." Any foe within 2 cannot reach for the ability it
-- used last turn (trait_lethe_haze, models/lethe.lua). Bound and unstealable: an organ, never kit.
return {
    name = "Lethe Haze",
    description = "Foes within 2 can't use the same ability two turns running.",
    flavor = "It does nothing to you. You simply cannot remember how you did that last time.",
    sprite = "assets/items/utility_lethe_haze.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_lethe_haze" },
}
