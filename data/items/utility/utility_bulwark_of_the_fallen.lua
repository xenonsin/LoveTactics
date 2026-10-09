-- BULWARK OF THE FALLEN: the Death Knight's own (data/characters/character_death_knight.lua; "The Crown's
-- Bestiary", slice B, 2026-10-09). It carries the rule (trait_bulwark_of_the_fallen): an ally falling within 3
-- closes over the knight as a Physical Barrier worth half that ally's max health.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (Oathbound Plate).
return {
    name = "Bulwark of the Fallen",
    description = "When an ally within 3 falls, gain a Physical Barrier of half its max health.",
    flavor = "It signed for all of them. It keeps what it signed for.",
    sprite = "assets/items/utility_bulwark_of_the_fallen.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_bulwark_of_the_fallen" },
}
