-- BANKED TURNS: the Ground Sloth's organ (data/characters/character_ground_sloth.lua; trait_banked_turns).
-- Approved 2026-10-04 on "Sloth's Bestiary", slice A. Its bank holds 3.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (Sleeper's Claws).
return {
    name = "Banked Turns",
    description = "Banks each turn no foe is in reach, up to 3. Its next attack lands once more per turn banked. A blow knocks one out.",
    flavor = "It is not resting. It is saving up.",
    sprite = "assets/items/utility_banked_turns.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_banked_turns" },
    traitParams = { cap = 3 },
}
