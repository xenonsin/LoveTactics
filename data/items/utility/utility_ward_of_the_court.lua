-- WARD OF THE COURT: the Greater Archon's own (data/characters/character_greater_archon.lua; "The Crown's Bestiary",
-- slice A, 2026-10-09). It carries the ward (trait_ward_of_the_court): an Archon struck within 3 is thrown a Magical
-- Barrier, on a cooldown, and the bearer opens every fight under one.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (Killing Magic).
return {
    name = "Ward of the Court",
    description = "When an Archon within 3 is struck, wards it with a Magical Barrier. Opens each fight warded.",
    flavor = "It does not ward the court because it loves the court. It wards it because the court is its own.",
    sprite = "assets/items/utility_ward_of_the_court.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_ward_of_the_court" },
}
