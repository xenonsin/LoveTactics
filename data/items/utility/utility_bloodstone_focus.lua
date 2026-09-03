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
    price = 495,
    unlockQuests = 5,
    traits = { "trait_overchannel" },
    -- spells paid for in life: the focus is the bargain
    bonus = { magicDamage = 3, defense = -1 },
}
