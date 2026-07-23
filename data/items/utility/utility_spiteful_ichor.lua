-- The Spiteful Ichor: a vial the alchemist drank rather than sold, some years ago, and has not
-- entirely stopped being since. Grants the trait of the same name
-- (data/traits/trait_spiteful_ichor.lua): melee attackers are Poisoned by the blood they draw.
--
-- The Crucible's answer to its own worst problem. Every other alchemist item asks you to be somewhere
-- else -- throw the bomb, plant the keg, coat the blade and let someone else swing it. This one is for
-- the turn where that failed and there is a demon in your face, and what it does is exactly what envy
-- would do about it: not fight back, but make being the one who won unpleasant.
return {
    name = "Spiteful Ichor",
    description = "Melee attackers are Poisoned by the blood they draw.",
    flavor = "She drank it to see what it did. She has been finding out ever since, and selling the answer.",
    sprite = "assets/items/utility_spiteful_ichor.png",
    type = "utility",
    tags = { "charm", "poison" },
    class = "alchemist",
    price = 300,
    repRank = 2,
    traits = { "trait_spiteful_ichor" },
}
