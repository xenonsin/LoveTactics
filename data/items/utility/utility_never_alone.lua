-- NEVER ALONE: the goblin saboteur's race item ("The Rift's Adventurers", slice D, approved 2026-10-09). A
-- goblin with no kin within two Cowers (trait_mob_courage); a saboteur's own hidden charges count as kin
-- (trait_never_alone, models/race_items.lua), so it does not Cower while it sits beside one.
--
-- Gated to goblins (Character.canCarry). No price: a rift find on the saboteur's shelf at the class's floor.
return {
    name = "Never Alone",
    description = "Your hidden charges count as goblins, so you do not Cower beside one.",
    flavor = "The powder keg never argues, never runs, and goes off when asked, which makes it the best friend a goblin has.",
    sprite = "assets/items/utility_never_alone.png",
    type = "utility",
    tags = { "trinket" },
    class = "saboteur",
    race = "goblin",
    unlockLevel = 14,
    traits = { "trait_never_alone" },
}
