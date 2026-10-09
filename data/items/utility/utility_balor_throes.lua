-- DEATH THROES: the Balor's own (data/characters/character_balor.lua; "The Crown's Bestiary", slice B, 2026-10-09).
-- It carries the blast (trait_hellfire_throes): when the Balor dies it explodes, 20 fire to every body within 3,
-- its own escort included.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (Last Breath).
return {
    name = "Death Throes",
    description = "When it dies, it explodes: fire damage to every body within 3, its own side included.",
    flavor = "It has been burning from the inside the whole time. Killing it only lets that out.",
    sprite = "assets/items/utility_balor_throes.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_hellfire_throes" },
}
