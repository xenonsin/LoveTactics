-- THE SWARM: the organ of the Thousand-Winged's bats (character_swarm_familiar) -- its wings (`flying`) and its rule
-- (trait_the_swarm): four of them standing together at a turn's end fuse into the Thousand-Winged. Wrath's
-- vampires, round 3.
return {
    name = "The Swarm",
    description = "Flies. At the end of any turn, 4 or more bats standing together fuse into the Thousand-Winged.",
    flavor = "One bat is a bat. Four is the start of something with a name.",
    sprite = "assets/items/utility_the_swarm.png",
    type = "utility",
    tags = { "natural", "flying" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_swarm" },
}
