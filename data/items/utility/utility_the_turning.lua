-- THE TURNING: the Ophan's organ (reviewed 2026-09-30, "Pride's Bestiary"). With a foe beside it, it turns its
-- wheel every turn and does nothing else (trait_the_turning, read by models/choir.lua). The wheel never stops,
-- which is what makes standing next to it a decision rather than an accident.
--
-- Bound and unstealable: an organ, never kit.
return {
    name = "The Turning",
    description = "With a foe beside it, it strikes every adjacent tile, every turn.",
    flavor = "It went straight forward, wherever the spirit was to go, and it did not turn as it went.",
    sprite = "assets/items/utility_the_turning.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_turning" },
}
