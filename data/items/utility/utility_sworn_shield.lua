-- SWORN SHIELD: the human knight's race item ("The Rift's Adventurers", slice D, approved 2026-10-09). When the
-- bearer's guard takes a blow meant for an ally, the ally is Blessed (trait_sworn_shield). It brings no guard of
-- its own -- Oathward and the Martyr's Vow do -- so it is worth exactly as much as the oath the knight keeps.
--
-- Gated to humans (Character.canCarry). No price: a rift find on the knight's shelf at the class's floor.
return {
    name = "Sworn Shield",
    description = "When you take a blow for an ally, the ally is Blessed.",
    flavor = "The oath is painted on the inside of the shield, where only the one behind it can read it.",
    sprite = "assets/items/utility_sworn_shield.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    race = "human",
    unlockLevel = 1,
    traits = { "trait_sworn_shield" },
}
