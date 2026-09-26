-- THE DELVER'S SKULL-LANTERN: the Dwarf Skeleton's. A dwarf sees in the deep, dead or not; a candle in its
-- skull and so do you. Foes within 2 are Limned (trait_skull_lantern, Status.lanternLit) -- targetable
-- however well they hide, and all here for a barrow-wight. Hawk Bells answer hiding within their earshot
-- too; the lantern is the one that LIMNS, which is also what strips a wight's Half Here.
return {
    name = "Delver's Skull-Lantern",
    description = "Foes within 2 of you are Limned.",
    flavor = "It was the best light in the Deeps. It still is. The dwarf just is not holding it any more.",
    sprite = "assets/items/utility_skull_lantern.png",
    type = "utility",
    tags = { "light" },
    class = "saboteur",
    unlockLevel = 5,
    unstocked = true,
    traits = { "trait_skull_lantern" },
}
