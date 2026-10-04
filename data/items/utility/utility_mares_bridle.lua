-- THE MARE'S BRIDLE: what a company takes off the Mare ("Sloth's Bestiary", 2026-10-04, approved word for word).
-- An assassin's piece: a sleeper is a body that will not see the knife, and this keeps it asleep for the next one.
-- Paired with anything that lays Sleep, it turns a sleeper into a target that stays one (trait_mares_bridle).
-- An unstocked trophy on the seat's rung.
return {
    name = "The Mare's Bridle",
    description = "Your blows do not wake a sleeping foe.",
    flavor = "Whoever wore it last rode all night, and never once woke the house.",
    sprite = "assets/items/utility_mares_bridle.png",
    type = "utility",
    tags = { "charm" },
    class = "assassin",
    unlockLevel = 10,
    unstocked = true,
    traits = { "trait_mares_bridle" },
}
