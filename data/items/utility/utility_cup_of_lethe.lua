-- CUP OF LETHE: the Lethe-Drinker's trophy, on the Warden's shelf. Approved 2026-10-09 ("The Crown's Bestiary",
-- slice E). The body's haze carried in a cup (trait_cup_of_lethe, models/lethe.lua): a warden holds ground, and a
-- foe standing near it cannot lean on the same answer twice.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Cup of Lethe",
    description = "Foes within 2 of you can't use the same ability two turns running.",
    flavor = "The dead drink from it to forget. It works on the living too, just a turn at a time.",
    sprite = "assets/items/utility_cup_of_lethe.png",
    type = "utility",
    tags = { "charm" },
    class = "warden",
    unlockLevel = 14,
    unstocked = true,
    traits = { "trait_cup_of_lethe" },
}
