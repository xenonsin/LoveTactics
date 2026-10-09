-- FLAWLESS SHOT: the elf hunter's race item ("The Rift's Adventurers", slice D, approved 2026-10-09). While the
-- bearer is Unblemished, its bow shots are not asked the dice and reach a tile further (trait_flawless_shot,
-- models/race_items.lua). The first wound ends it with the status, so the elf's whole argument is the
-- opening exchange: shoot first, from further, and never miss while nothing has touched you.
--
-- Gated to elves (Character.canCarry). No price: a rift find on the hunter's shelf at the class's floor.
return {
    name = "Flawless Shot",
    description = "While Unblemished, your bow shots cannot miss and reach 1 tile farther.",
    flavor = "An elf does not aim so much as wait until missing would be an insult.",
    sprite = "assets/items/utility_flawless_shot.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    race = "elf",
    unlockLevel = 1,
    traits = { "trait_flawless_shot" },
}
