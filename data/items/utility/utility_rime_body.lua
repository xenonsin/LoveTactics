-- What a RIME SLIME is (data/characters/character_rime_slime.lua): proof against steel, adapting, and it Freezes
-- Solid where it dies -- its tile and the empty tiles beside it become Ice Walls (trait_freeze_solid). It made
-- you Torpid until the creature identity pass (2026-11-19); Torpor stays on the Glacier King.
return {
    name = "Rime Body",
    description = "Voids blades, points and blows. Takes on elements. On death, it and the empty tiles beside it become Ice Walls.",
    flavor = "It was here before you arrived and it intends to be here after.",
    sprite = "assets/items/rime_body.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    immune = { physical = true, slash = true, pierce = true, impact = true },
    traits = { "trait_adaptive", "trait_freeze_solid" },
}
