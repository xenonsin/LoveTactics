-- MIRROR OF THE MORNING: Superbia's Host for a person, once (reviewed over three rounds, "Pride's Generals"). The
-- first time each fight the bearer falls below two-thirds health, two Reflections of the Morning -- felled by any
-- blow, Blinding whoever looks at them -- fight beside it (trait_mirror_of_the_morning).
--
-- A Summoner's piece: bodies that arrive on their own, called by being hurt rather than by a cast.
--
-- `unstocked`: a trophy, seen on the rack and never sold (docs/drops.md).
return {
    name = "Mirror of the Morning",
    description = "Below two-thirds health, the first time each fight: two Reflections that die to a single blow fight beside you.",
    flavor = "Every face in it is hers. None of them has ever disagreed with her.",
    sprite = "assets/items/utility_mirror_of_the_morning.png",
    type = "utility",
    tags = { "charm", "holy" },
    class = "summoner",
    unlockLevel = 13,
    unstocked = true,
    traits = { "trait_mirror_of_the_morning" },
}
