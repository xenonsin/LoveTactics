-- WELL STOCKED: the human alchemist's race item ("The Rift's Adventurers", slice D, approved 2026-10-09). The
-- first use the bearer makes of each consumable in a fight leaves its stack alone (trait_well_stocked,
-- models/race_items.lua), so every draught and coating it carries has one more use. The city's own people are
-- the ones who packed properly.
--
-- Gated to humans (Character.canCarry). No price: a rift find on the alchemist's shelf at the class's floor.
return {
    name = "Well Stocked",
    description = "Your consumables have one more use each fight.",
    flavor = "There is always one more at the bottom of the satchel, because a human put it there on purpose.",
    sprite = "assets/items/utility_well_stocked.png",
    type = "utility",
    tags = { "pack" },
    class = "alchemist",
    race = "human",
    unlockLevel = 1,
    traits = { "trait_well_stocked" },
}
