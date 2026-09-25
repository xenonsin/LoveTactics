-- THE THANE'S SEAL: the Hoard-Thane's standing, carried as creature kit (a boss's machinery, not for sale).
-- It makes him the heir of every dwarf on the board (trait_heir_of_all), so Inheritance flows to him at
-- any range. Bound: the seal is the office, and it does not come off.
return {
    name = "The Thane's Seal",
    description = "Every fallen dwarf's Share and coffer pass to you, wherever you stand.",
    flavor = "A ring the width of a man's wrist. Every coin in the keep is struck with the same face.",
    sprite = "assets/items/utility_the_thanes_seal.png",
    type = "utility",
    tags = { "relic" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_heir_of_all" },
}
