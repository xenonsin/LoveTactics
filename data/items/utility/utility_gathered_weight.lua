-- THE GATHERED WEIGHT: a charm that pays the bearer for every hex they are carrying
-- (data/traits/trait_gathered_weight.lua, docs/curses.md).
--
-- THE PASSIVE HALF OF THE COUNTING SHELF, and what turns a curse-carrier from one weapon into a BUILD.
-- The Reckoning pays only when it swings; this pays on every blow the body throws, every spell it casts
-- and every forecast it draws, because it moves the stats themselves.
--
-- IT COSTS A CELL, which is the quiet part and the interesting one. Nine cells is the whole of what a
-- body can reach, and this one is spent on a multiplier with no floor -- carried by somebody clean it is
-- an empty slot. So it is only ever worth taking down by a company that has already decided to live
-- with what the rift deals, which is exactly the decision the whole system is for.
return {
    name = "The Gathered Weight",
    description = "+2 attack and +2 magic damage for every hex the bearer is carrying.",
    flavor = "The trick is not bearing it. The trick is finding out you would rather.",
    sprite = "assets/items/gathered_weight.png",
    type = "utility",
    tags = { "charm", "dark" },
    class = "shaman",
    unlockLevel = 7,
    traits = { "trait_gathered_weight" },
}
