-- STITCHED TO YOU: the Patchwork's own (data/characters/character_patchwork.lua; "Envy's Bestiary", round 1). It
-- carries the rule (trait_stitched_to_you): whoever last struck it is Conjoined to it, and the stitch moves to
-- each new attacker.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (Surgeon's Thread).
return {
    name = "Stitched to You",
    description = "Whoever last struck it is Conjoined to it. The stitch moves to each new attacker.",
    flavor = "It was sewn together from people who wanted to be somebody else. It found the thread works both ways.",
    sprite = "assets/items/utility_stitched_to_you.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_stitched_to_you" },
}
