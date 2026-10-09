-- BLOOD TALLY: the orc barbarian's race item (data/items/utility/utility_blood_tally.lua, "The Rift's
-- Adventurers", slice D). Approved as "Blood Price"; renamed because trait_blood_price exists.
--
-- The barbarian's Fury is paid for in health spent: Desperate Strike and The Red Account both scale on how
-- much of the bar is gone. A Blood Tally adds a tenth to that figure for every Proven its bearer carries (up to
-- three), so a kill does what a wound does. Read through models/race_items.lua's `healthSpent`, capped at all
-- of it.
return {
    name = "Blood Tally",
    description = "Each Proven counts as a tenth of your health lost, for your Fury.",
    bloodTally = true,
}
