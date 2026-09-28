-- HEART OF THE WILDFIRE: the Blaze's Wildfire in a player's grid (trait_wildfire; "Fire, Lightning, and Dirty
-- Thunder", 2026-09-27), and one of the three things it drops. At the end of your turn every fire within 2 of you
-- creeps a tile into plain ground, toward your nearest foe. A fire build's board control -- and unsided, so it
-- closes your own corridor as readily as theirs.
return {
    name = "Heart of the Wildfire",
    description = "At the end of your turn, fire within 2 of you spreads one tile into plain ground.",
    flavor = "It was a small fire once. Everything is, for a while.",
    sprite = "assets/items/utility_heart_of_the_wildfire.png",
    type = "utility",
    tags = { "fire" },
    class = "elementalist",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_wildfire" },
}
