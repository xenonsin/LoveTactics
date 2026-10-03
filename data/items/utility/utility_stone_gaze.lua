-- THE GORGON'S EYES: Medusa's organ (data/characters/character_medusa.lua), carrying her three rules -- Stone Gaze,
-- her blood and her garden (models/gorgon.lua). Creature kit: bound, unstealable, on no shelf. What a company
-- takes off her instead is the Gorgon's Gaze, Serpent Locks and the Hand-Mirror.
return {
    name = "The Gorgon's Eyes",
    description = "Foes ending a turn in its sight within 4 gain Stone. A slash on it springs an adder. At half, its statues wake.",
    flavor = "She was not born this way. Somebody else wanted her not to be looked at, and got their wish.",
    sprite = "assets/items/utility_stone_gaze.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_stone_gaze", "trait_gorgon_blood", "trait_her_garden" },
}
