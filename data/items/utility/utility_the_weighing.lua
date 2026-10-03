-- THE WEIGHING: the Jackal Weighers' own (data/characters/character_jackal_weigher.lua; "Envy's Bestiary",
-- round 2). It carries the rule (trait_the_weighing): each turn two of the company go on the scale, the lighter
-- heart is Spared, and every Weigher strikes the other.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (the Scale of Hearts).
return {
    name = "The Weighing",
    description = "Each turn, weighs two foes: the one with less health is Spared, and every Weigher strikes the other.",
    flavor = "The feather has never once come up short. They find it is usually the heart that was greedy.",
    sprite = "assets/items/utility_the_weighing.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_the_weighing" },
}
