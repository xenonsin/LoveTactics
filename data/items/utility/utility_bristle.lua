-- BRISTLE: the Manticore's hide (trait_bristle). Every 15 damage it takes, it sprays quills at every foe
-- within 2. The creature's copy; its drop is utility_the_bristling, the same rule at reach 1.
return {
    name = "Bristle",
    description = "Every 15 damage taken, sprays quills at every foe within 2, inflicting Quilled.",
    flavor = "Hit it hard enough and it answers everyone standing close enough to have helped.",
    sprite = "assets/items/utility_bristle.png",
    type = "utility",
    class = "creature",
    tags = { "beast", "pierce" },
    noSteal = true,
    traits = { "trait_bristle" },
}
