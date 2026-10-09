-- DUCAL ASCENSION: the Archon Duke's own (data/characters/character_archon_duke.lua; "The Crown's Bestiary", slice A,
-- 2026-10-09). It carries the Ascension (trait_ducal_ascension): any wisp within 3 of the Duke goes to the Duke
-- instead of home, and that Archon stays down; at the third, the Duke Ascends.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (Ascension, a Champion's).
return {
    name = "Ducal Ascension",
    description = "Takes in any wisp within 3. At the third, it Ascends: a new body, healed to full.",
    flavor = "Its court rises home when it falls. The Duke has other plans for them.",
    sprite = "assets/items/utility_ducal_ascension.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_ducal_ascension" },
}
