-- RIME GUT: the Frost Worm's organ (data/characters/character_frost_worm.lua; "Sloth's Bestiary", 2026-10-04,
-- slice C). The cold it carries inside it, which comes out all at once when it dies: every body within 2 is
-- Frozen (trait_death_throes_frost). Bound and unstealable -- a body, not kit.
return {
    name = "Rime Gut",
    description = "When you die, you burst: every body within 2 is Frozen.",
    flavor = "Whatever it swallowed is still in there, and still cold.",
    sprite = "assets/items/utility_rime_gut.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_death_throes_frost" },
}
