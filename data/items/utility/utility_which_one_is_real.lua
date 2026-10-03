-- WHICH ONE IS REAL: the Mirage's own (data/characters/character_mirage.lua; "Envy's Bestiary", round 1). It
-- carries the rule the fight is about (trait_which_one_is_real): three illusions at the bell, a place traded with
-- one when the real one is struck, and the sand that only the real one sinks in.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (Mirage Step).
return {
    name = "Which One Is Real",
    description = "Fights beside three illusions of itself. Struck, it trades places with one, once a round.",
    flavor = "The heat off the sand makes four of everything, and only one of them is thirsty.",
    sprite = "assets/items/utility_which_one_is_real.png",
    type = "utility",
    class = "creature",
    tags = { "natural", "illusion" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_which_one_is_real" },
}
