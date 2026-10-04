-- THE GLASS PALACE: the Snow Queen's organ (data/characters/character_snow_queen.lua), carrying her wall
-- (trait_glass_palace). Creature kit: bound, unstealable, on no shelf. What a company takes off her instead is the
-- Splinter of the Mirror.
return {
    name = "The Glass Palace",
    description = "At the end of its turn, marks 3 tiles in a line through its foes; a turn later they become Ice Walls.",
    flavor = "Every room in it is beautiful, and none of them has a door to the next.",
    sprite = "assets/items/utility_glass_palace.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_glass_palace" },
}
