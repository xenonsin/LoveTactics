-- HERALD'S TRUMPET: the Herald's drop, the Hymn rebuilt for a person (reviewed 2026-09-30, "Pride's Bestiary").
--
-- The same rule the Herald sings (trait_the_hymn), with the `kin` taken off: at the end of the bearer's turn every
-- ally within 2 is Blessed. A Theurge's piece, because a theurge is the priest who works THROUGH the company
-- rather than on it, and a standing benediction that costs no turn is exactly that. Its price is where you have
-- to stand -- in the middle of them, every turn.
--
-- `unstocked`: a trophy, seen on the rack and never sold (docs/drops.md).
return {
    name = "Herald's Trumpet",
    description = "At the end of your turn, allies within 2 are Blessed.",
    flavor = "It plays one note. The angels never needed a second, and it has not learned one for you.",
    sprite = "assets/items/utility_heralds_trumpet.png",
    type = "utility",
    tags = { "charm", "holy" },
    class = "theurge",
    unlockLevel = 8,
    unstocked = true,
    traits = { "trait_the_hymn" },
}
