-- The item form of the Mage's Overchannel: a bloodstone that lets its bearer cast through their own
-- life when the mana runs dry. Slot it and any character casts in blood past empty (Combat.spendCost
-- reads the trait). A mage-class focus, sold at the Arcanum.
return {
    name = "Bloodstone Focus",
    description = "When mana fails, your spells draw on your life instead.",
    flavor = "The Arcanum sells it without comment. There is nothing it could usefully add.",
    sprite = "assets/items/bloodstone_focus.png",
    type = "utility",
    tags = { "arcane" },
    class = "mage",
    price = 260,
    repRank = 2,
    traits = { "trait_overchannel" },
}
