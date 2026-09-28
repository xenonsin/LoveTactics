-- ERUPTION STONE: the Thunderhead's eruption, lava half only (trait_eruption_stone; "Fire, Lightning, and Dirty
-- Thunder", round 2, 2026-09-28), and one of the three things it drops. The first time you drop to a third of your
-- health, every tile beside you turns to lava: an island to stand on when you are about to fall. It shuts out your
-- own healers' reach too. A Warden's, who holds ground -- and pairs with Flowwalker's Soles, which walk off it.
return {
    name = "Eruption Stone",
    description = "The first time you drop to a third of your health, every tile beside you turns to lava.",
    flavor = "Warm to the touch. Warmer the worse things go.",
    sprite = "assets/items/utility_eruption_stone.png",
    type = "utility",
    tags = { "fire" },
    class = "warden",
    unlockLevel = 8,
    unstocked = true,
    traits = { "trait_eruption_stone" },
}
