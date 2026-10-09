-- MANY HANDS: the kobold trapper's race item (data/items/utility/utility_many_hands.lua, "The Rift's
-- Adventurers", slice D). Each living trap the bearer set beside the foe it strikes counts as one more kobold
-- for Pack (trait_pack), under Pack's own cap of three. Read through models/race_items.lua's `trapsBeside`.
return {
    name = "Many Hands",
    description = "Each of your traps beside a target counts as a kobold for Underfoot.",
    manyHands = true,
}
