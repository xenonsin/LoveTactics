-- GRUDGE PURSE: the goblin thief's race item (data/items/utility/utility_grudge_purse.lua, "The Rift's
-- Adventurers", slice D). The thief's steals (models/race_items.lua's STEALS: Pickpocket, Sap, Shakedown, the
-- Flaying Knife) are not asked the dice when they are aimed at the bearer's side's Feud (models/feud.lua). Read
-- by Combat.rollsToHit, so the forecast says 100 too.
return {
    name = "Grudge Purse",
    description = "Your steals from the Feud cannot miss.",
    grudgePurse = true,
}
