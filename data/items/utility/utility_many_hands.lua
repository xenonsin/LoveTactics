-- MANY HANDS: the kobold trapper's race item ("The Rift's Adventurers", slice D, approved 2026-10-09). Each of the
-- bearer's own traps beside the foe it strikes counts as one more kobold for Pack (trait_many_hands,
-- models/race_items.lua) -- under Pack's own cap -- so a lone trapper standing in its snares fights like a
-- warren.
--
-- Gated to kobolds (Character.canCarry). No price: a rift find on the trapper's shelf at the class's floor.
return {
    name = "Many Hands",
    description = "Each of your traps beside a target counts as a kobold for Underfoot.",
    flavor = "Every snare is tied with the same knot, which to a kobold makes it family.",
    sprite = "assets/items/utility_many_hands.png",
    type = "utility",
    tags = { "trinket" },
    class = "trapper",
    race = "kobold",
    unlockLevel = 7,
    traits = { "trait_many_hands" },
}
