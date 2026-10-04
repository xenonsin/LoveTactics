-- NOONDAY HAZE: the Noonday Demon's organ (data/characters/character_noonday_demon.lua; "Sloth's Bestiary",
-- 2026-10-04, slice C). Listless: foes within 4 that end a turn having dealt no damage weigh -3 Damage a stack,
-- and at 3 the next turn is Shamed (trait_the_noonday_demon). Bound and unstealable: it is the hour, not a thing
-- the demon holds. What the fight hands over is the Meridian Charm, on the body's `drops`.
return {
    name = "Noonday Haze",
    description = "Foes within 4 that end their turn having dealt no damage gain Listless. At 3, they are Shamed.",
    flavor = "The sun stops in the sky. The afternoon goes on without it.",
    sprite = "assets/items/utility_noonday_haze.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_noonday_demon" },
}
