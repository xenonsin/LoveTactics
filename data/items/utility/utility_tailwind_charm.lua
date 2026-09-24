-- THE TAILWIND CHARM: the Alpha Wyvern's hand-over -- the flight's own defence, worn by a person. +15 Avoid
-- while no foe is beside you (data/traits/trait_tailwind.lua, at 15 through `traitParams` where the animal
-- carries 25: a person chooses where to stand, and a wyvern is only choosing where to fly). For the archer
-- or the mage who keeps a line between themselves and the fight.
return {
    name = "Tailwind Charm",
    description = "+15 Avoid while no foe is adjacent.",
    flavor = "Hold it up and it pulls. Always away from whatever you are looking at.",
    sprite = "assets/items/utility_tailwind_charm.png",
    type = "utility",
    tags = { "wind" },
    class = "skirmisher",
    unlockLevel = 4,
    unstocked = true,
    traits = { "trait_tailwind" },
    traitParams = { avoid = 15 },
}
