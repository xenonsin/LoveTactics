-- SEEK DEATH: the Pit Locust's own (data/characters/character_pit_locust.lua; "The Crown's Bestiary", slice C). It
-- carries the rule (trait_seek_death): its stings never take a body below 1, and a body already at 1 is Tormented.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (Torment).
return {
    name = "Seek Death",
    description = "Its blows cannot take a foe below 1 health. Each blow on a foe already at 1 adds Torment.",
    flavor = "In those days they shall seek death, and shall not find it.",
    sprite = "assets/items/utility_seek_death.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_seek_death" },
}
