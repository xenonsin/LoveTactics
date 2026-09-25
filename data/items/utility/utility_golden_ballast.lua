-- GOLDEN BALLAST: one of the Gold Golem's three trophies (round 2, "The Golems of Greed"), from its gold
-- plates. +6 Defense, and the wearer cannot be pushed, pulled or knocked back (the Unheld's own
-- trait_nothing_to_hold). The price is the plating's: each impact blow the wearer takes wears 2 of the
-- Defense off for the rest of the fight (trait_ballast_wear, status_ballast_worn), so three good hammer
-- blows leave only the anchor.
return {
    name = "Golden Ballast",
    description = "+6 Defense, and you cannot be moved. Each impact blow you take wears 2 Defense off it for the fight.",
    flavor = "Solid gold, and heavy with it. Nobody is carrying you anywhere.",
    sprite = "assets/items/utility_golden_ballast.png",
    type = "utility",
    tags = { "trinket" },
    class = "bulwark",
    unlockLevel = 5,
    unstocked = true,
    bonus = { defense = 6 },
    traits = { "trait_nothing_to_hold", "trait_ballast_wear" },
}
