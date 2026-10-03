-- THE FLAYING: the Skin-Thief's organ (data/characters/character_skin_thief.lua). Reviewed 2026-10-01..03
-- ("Envy's Bestiary", round 2). Its hit Halts one of the company for 2 turns and it wears that body's face for
-- the same 2 (data/traits/trait_the_flaying.lua). Bound and unstealable, and carried into every face it wears.
return {
    name = "The Flaying",
    description = "Its hit Halts one of the company for 2 turns, and it wears that body's face until then.",
    flavor = "It does not want what you have. It wants to be the one who has it.",
    sprite = "assets/items/utility_the_flaying.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_flaying" },
}
