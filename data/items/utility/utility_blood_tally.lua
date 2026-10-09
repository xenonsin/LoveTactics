-- BLOOD TALLY: the orc barbarian's race item ("The Rift's Adventurers", slice D, approved 2026-10-09). Approved
-- as "Blood Price"; renamed because trait_blood_price exists.
--
-- The barbarian's Fury is paid in health spent (Desperate Strike, The Red Account). An orc is paid in kills
-- (Proven). This lets the second count as the first: each Proven reads as a tenth of the bar already gone
-- (trait_blood_tally, models/race_items.lua), so an orc can rage at full health on the strength of its scars.
--
-- Gated to orcs (Character.canCarry). No price: a rift find on the barbarian's shelf at the class's floor.
return {
    name = "Blood Tally",
    description = "Each Proven counts as a tenth of your health lost, for your Fury.",
    flavor = "It keeps the count in notches on its own forearm, which is cheaper than keeping it in its head.",
    sprite = "assets/items/utility_blood_tally.png",
    type = "utility",
    tags = { "trinket" },
    class = "barbarian",
    race = "orc",
    unlockLevel = 5,
    traits = { "trait_blood_tally" },
}
