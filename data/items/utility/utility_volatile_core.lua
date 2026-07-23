-- The hollow a Bomblet is bred around (data/characters/character_demon_bomblet.lua). A bound relic that
-- carries the one rule that makes a suicide bomber a suicide bomber: trait_volatile
-- (data/traits/trait_volatile.lua) -- when the bearer dies, it bursts. Delivered as a grid item (the
-- reliable way a trait reaches a unit -- models/trait.lua), bound so it is never lifted off.
--
-- No `class`/`price`: not gear anyone shops for; it is what the thing is, not something it holds.
return {
    name = "Volatile Core",
    description = "When its bearer falls, it bursts.",
    flavor = "A demon bred hollow and filled with fire. It was never meant to come home.",
    sprite = "assets/items/sig_unappeased_heart.png", -- placeholder until its own art exists
    type = "utility",
    tags = { "relic" },
    bound = true,
    traits = { "trait_volatile" },
}
