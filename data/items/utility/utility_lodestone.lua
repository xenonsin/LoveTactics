-- LODESTONE: one of the Gold Golem's three trophies (round 2, "The Golems of Greed": all three, on the note
-- that a drop must be "useful everywhere" rather than only where coin heaps lie). Gold Calls to Gold with
-- bodies in place of heaps: at the start of the wearer's turn every foe within 3 is dragged one tile toward
-- it (trait_lodestone, status_lodestone). A tank that pulls the fight onto itself. Anything that cannot be
-- moved stays put.
return {
    name = "Lodestone",
    description = "At the start of your turn, every foe within 3 is dragged one tile toward you.",
    flavor = "Cut from the Gold Golem's core. Whatever it was pulling, it has not stopped.",
    sprite = "assets/items/utility_lodestone.png",
    type = "utility",
    tags = { "earth" },
    class = "bulwark",
    unlockLevel = 5,
    unstocked = true,
    traits = { "trait_lodestone" },
}
