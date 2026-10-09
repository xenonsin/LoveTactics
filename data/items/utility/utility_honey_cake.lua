-- HONEY-CAKE: a Cerberus head's own (data/characters/character_cerberus_head.lua; "The Crown's Bestiary", slice C).
-- It carries the head's rule (trait_honey_cake): a Sleep, or a draught thrown at the head, quiets it for 2 turns, and
-- every wound the head takes is the body's.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player.
return {
    name = "Honey-Cake",
    description = "A Sleep or a thrown draught quiets this head for 2 turns. Its wounds are the body's.",
    flavor = "Steeped in poppy and honey, and swallowed whole. It has worked before.",
    sprite = "assets/items/utility_honey_cake.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_honey_cake" },
}
