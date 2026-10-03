-- WHICH DOTH MOCK THE MEAT: the Green-Eyed Monster's own (data/characters/character_green_eyed_monster.lua;
-- "Envy's Bestiary", round 2). It carries the half of the rule that rides every blow (trait_mocks_the_meat): +2
-- damage for each pair of the company standing side by side. The roar is its other half.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (Jealous Roar).
return {
    name = "Which Doth Mock the Meat",
    description = "Deals +2 damage for every pair of foes standing side by side.",
    flavor = "It cannot stand to watch two people trust each other. It has never once had to watch for long.",
    sprite = "assets/items/utility_mocks_the_meat.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_mocks_the_meat" },
}
