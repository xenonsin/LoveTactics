-- THE GAZE THAT IS ADMIRED: the Peacock-Basilisk's organ (data/characters/character_peacock_basilisk.lua;
-- trait_the_admired_gaze). A reverse taunt: look away from it and you are Stunned. Bound and unstealable.
return {
    name = "The Gaze That Is Admired",
    description = "A foe within 3 that ends its turn without attacking it is Stunned.",
    flavor = "It does not turn men to stone. It only asks to be looked at, and it is very hard to stop.",
    sprite = "assets/items/utility_the_admired_gaze.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_admired_gaze" },
}
