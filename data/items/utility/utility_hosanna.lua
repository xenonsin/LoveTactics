-- HOSANNA: the Throne's organ for its third phase (reviewed 2026-09-30, "Pride's Bestiary"). At 75%, 50% and 25%
-- health it calls two Heralds, who walk on under the board's reinforcement telegraph (trait_hosanna).
--
-- Bound and unstealable: an organ, never kit.
return {
    name = "Hosanna",
    description = "At 75%, 50% and 25% health, two Heralds are called to the fight.",
    flavor = "Every wound it takes is answered by more voices. It has never once needed to raise its own.",
    sprite = "assets/items/utility_hosanna.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_hosanna" },
}
