-- CAST BY YOU: the Shade's own (data/characters/character_shade.lua; "Envy's Bestiary", round 1). It carries the
-- rule (trait_cast_by_you): Unseen beside a wall or ridge, Limned on open sand.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (the Shade Cloak).
return {
    name = "Cast by You",
    description = "Unseen beside a wall or ridge, and Limned on open ground.",
    flavor = "Every shadow in the waste belongs to somebody. This one decided it would rather belong to itself.",
    sprite = "assets/items/utility_cast_by_you.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_cast_by_you" },
}
