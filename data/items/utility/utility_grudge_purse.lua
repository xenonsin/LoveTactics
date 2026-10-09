-- GRUDGE PURSE: the goblin thief's race item ("The Rift's Adventurers", slice D, approved 2026-10-09). The
-- thief's steals (Pickpocket, Sap, Shakedown, the Flaying Knife) are not asked the dice when they are aimed at
-- the Feud (trait_grudge_purse, models/race_items.lua): a goblin's hand is never steadier than in the pocket of
-- the one it hates.
--
-- Gated to goblins (Character.canCarry). No price: a rift find on the thief's shelf at the class's floor.
return {
    name = "Grudge Purse",
    description = "Your steals from the Feud cannot miss.",
    flavor = "Everything in it once belonged to somebody who hit a goblin.",
    sprite = "assets/items/utility_grudge_purse.png",
    type = "utility",
    tags = { "trinket" },
    class = "thief",
    race = "goblin",
    unlockLevel = 3,
    traits = { "trait_grudge_purse" },
}
