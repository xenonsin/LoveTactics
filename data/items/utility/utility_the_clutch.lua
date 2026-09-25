-- THE CLUTCH: a Dragon Egg's own rule (data/characters/character_dragon_egg.lua; trait_clutch). An ally
-- that ends its turn beside the egg broods it, and brooded three times it hatches a Wyrmling. Creature kit,
-- bound: the shell is the egg.
return {
    name = "The Clutch",
    description = "An ally that ends its turn beside you broods you. Brooded three times, you hatch a Wyrmling.",
    flavor = "Warm, and warmer every time one of them sits down beside it.",
    sprite = "assets/items/utility_the_clutch.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_clutch" },
}
