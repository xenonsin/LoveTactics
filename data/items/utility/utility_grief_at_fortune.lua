-- GRIEF AT YOUR FORTUNE: the Pale Crone's own (data/characters/character_pale_crone.lua; "Envy's Bestiary", round
-- 4). It carries the leap (trait_grief_at_fortune): a foe healed or blessed in her sight is struck, once a round.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (the Thorned Staff).
return {
    name = "Grief at Your Fortune",
    description = "Once a round, when a foe it can see is healed or blessed, it leaps beside that foe and strikes.",
    flavor = "She wastes at the sight of anyone doing well, and she has never once looked away.",
    sprite = "assets/items/utility_grief_at_fortune.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_grief_at_fortune" },
}
