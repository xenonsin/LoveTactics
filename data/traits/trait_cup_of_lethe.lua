-- CUP OF LETHE: the Lethe-Drinker's haze carried in a cup (data/items/utility/utility_cup_of_lethe.lua). The same
-- flag as the body's own rule (trait_lethe_haze), on its own trait so the drop carries a grade weight and the organ
-- carries none.
return {
    name = "Cup of Lethe",
    description = "Foes within 2 of you can't use the same ability two turns running.",
    letheHaze = true,
    radius = 2,
}
