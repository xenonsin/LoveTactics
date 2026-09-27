-- THE BOX OF GRAVE-EARTH: the Sire's second drop (Wrath's vampires, round 2 rehomed it from the cut coffin elite
-- onto the Sire). The first time you would be downed each fight, you turn to mist instead -- untargetable -- drift
-- back to the tile you began the fight on, and re-form there at 30% health at the start of your next turn
-- (trait_grave_earth, status_grave_mist). It fires before the downed window, so that once you never go down.
return {
    name = "Box of Grave-Earth",
    description = "The first time you'd be downed each fight, turn to mist instead and re-form where you began at 30% health next turn.",
    flavor = "A small lead box of soil from the grave it rose out of, and it will not rest far from it.",
    sprite = "assets/items/utility_box_of_grave_earth.png",
    type = "utility",
    tags = { "trinket" },
    class = "necromancer",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_grave_earth" },
}
