-- PURITY: the Unicorn's own (data/characters/character_unicorn.lua; "Pride's Bestiary", 2026-09-30). It
-- carries the rule the fight is about, Rejects the Unworthy: no body carrying a debuff, a curse or an injury
-- can hurt it, and at the end of each of its turns its horn cleanses its side.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight
-- hands over is on the body's `drops` list instead (the Horn of Purity).
return {
    name = "Purity",
    description = "Can't be hurt by a body carrying a debuff, a curse or an injury. Cleanses its side at the end of its turn.",
    flavor = "It has never once been wrong about anybody, and it does not intend to start with you.",
    sprite = "assets/items/utility_purity.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_rejects_the_unworthy" },
}
