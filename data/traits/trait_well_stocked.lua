-- WELL STOCKED: the human alchemist's race item (data/items/utility/utility_well_stocked.lua, "The Rift's
-- Adventurers", slice D). The first use the bearer makes of each consumable in a fight leaves the stack alone,
-- so every one of them has one more use. Kept on the fighting unit (`wellStockedSpared`), so it is fresh every
-- fight and is never written onto the item a company carries home. Read through models/race_items.lua's
-- `spareUse`.
return {
    name = "Well Stocked",
    description = "Your consumables have one more use each fight.",
    wellStocked = true,
}
