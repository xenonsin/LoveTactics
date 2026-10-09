-- SWORN SHIELD: the human knight's race item (data/items/utility/utility_sworn_shield.lua, "The Rift's
-- Adventurers", slice D). When the bearer's guard takes a blow meant for an ally (Combat.tryRedirect --
-- Oathward, the Martyr's Vow), the ally is Blessed (status_blessing). It gives no guard of its own: the knight
-- carries the oath, and this is what keeping it pays. Read through models/race_items.lua's `tookBlow`.
return {
    name = "Sworn Shield",
    description = "When you take a blow for an ally, the ally is Blessed.",
    swornShield = true,
}
