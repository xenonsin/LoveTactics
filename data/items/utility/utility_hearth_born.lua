-- HEARTH-BORN: the Hellhound's own (data/characters/character_hellhound.lua; "The Crown's Bestiary", slice C). It
-- carries the rule (trait_hearth_born): fire on the ground heals it instead of burning it, and it deals 3 more
-- damage standing in it. Wet puts it out.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (the Hellhound Collar).
return {
    name = "Hearth-Born",
    description = "Fire on the ground heals it instead of burning it, and it deals 3 more damage standing in it.",
    flavor = "Whatever kennel bred it kept the fire lit instead of the lamps.",
    sprite = "assets/items/utility_hearth_born.png",
    type = "utility",
    class = "creature",
    tags = { "natural", "fire" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_hearth_born" },
}
