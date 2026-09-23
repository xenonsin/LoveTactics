-- THE BRISTLING: the manticore's hide rule rebuilt for a person (trait_bristle, through `traitParams`).
-- Every 15 damage its bearer takes, every foe within ONE is Quilled and takes a light pierce blow. Where
-- Quillhide answers each blow, this answers the TOTAL: a body surrounded and taking punishment turns the
-- whole press around it into targets for the archers behind. Off the Manticore; a trophy, the chase.
--
-- REACH 1 AGAINST THE ANIMAL'S 2, because the player chooses where to stand and the animal does not:
-- the same rule at the same reach on a knight parked in a doorway would quill a corridor.
--
-- TRAPPER STOCK: a trap that is your own body, on the shelf beside the Caltrop Greaves.
return {
    name = "The Bristling",
    description = "Every 15 damage taken, sprays quills at every adjacent foe, inflicting Quilled.",
    flavor = "It is not armour. Armour keeps the blow out. This makes the blow expensive.",
    sprite = "assets/items/utility_the_bristling.png",
    type = "utility",
    tags = { "pierce" },
    class = "trapper",
    unlockLevel = 4,
    unstocked = true,
    traits = { "trait_bristle" },
    traitParams = { radius = 1 },
}
