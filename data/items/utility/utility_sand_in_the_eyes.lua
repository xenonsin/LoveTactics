-- SAND IN THE EYES: the Sandman's organ (data/characters/character_the_sandman.lua), carrying his sowing
-- (data/traits/trait_sand_in_the_eyes.lua; models/sandman.lua). Creature kit: bound, unstealable, on no shelf. What a
-- company takes off him instead is the Sandman's Pouch, the same sleep on a trapper's 3x3.
return {
    name = "Sand in the Eyes",
    description = "Each turn, sows sand in a cross, a ring, then a row. Whatever stands on it at his next turn falls Asleep.",
    flavor = "He does not throw it. He lets it run out of his hands, and the world goes to bed.",
    sprite = "assets/items/utility_sand_in_the_eyes.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_sand_in_the_eyes" },
}
