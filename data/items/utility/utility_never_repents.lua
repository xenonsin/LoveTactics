-- NEVER REPENTS: the Phoenix's own (data/characters/character_phoenix.lua; "Pride's Bestiary", 2026-09-30). It
-- carries the rule the fight is about (trait_never_repents): felled, the Phoenix leaves an Ember that rises as
-- the Phoenix again in three turns, 3 Damage the stronger for every death, until somebody breaks it.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight
-- hands over is on the body's `drops` list instead (the Phoenix Feather).
return {
    name = "Never Repents",
    description = "Felled, it leaves an Ember that rises as the Phoenix in 3 turns, +3 Damage per death. Break it.",
    flavor = "Every other bird learns something from dying. This one only learns that it can.",
    sprite = "assets/items/utility_never_repents.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_never_repents" },
}
