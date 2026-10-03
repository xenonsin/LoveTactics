-- RED STONE HEART: the Homunculus's own (data/characters/character_red_homunculus.lua; "Envy's Bestiary",
-- 2026-10-03, slice C). It carries the rule the body is about (trait_red_stone): 3 Red Stone, a killing blow
-- consumes one and it stands back up whole next turn, and it heals a tenth a turn while it holds any.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (the Stone Heart).
return {
    name = "Red Stone Heart",
    description = "Opens with 3 Red Stone. A killing blow consumes one; it rises whole next turn. Heals 10% a turn.",
    flavor = "Somebody made it to last. Nobody made it to stop.",
    sprite = "assets/items/utility_red_stone_heart.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_red_stone" },
}
