-- The item form of Arcane Reservoir: a wellspring stone whose bearer's mana slowly regenerates -- the
-- one pool that otherwise never does. Slot it and any caster refills over time (Combat.regenerate
-- reads the trait). A mage-class relic, sold at the Arcanum; the answer to the game's mana scarcity.
return {
    name = "Mana Wellspring",
    description = "Your mana slowly returns, alone of all the pools.",
    flavor = "A stone that weeps blue light, and the Arcanum's answer to its own worst rule.",
    sprite = "assets/items/mana_wellspring.png",
    type = "utility",
    tags = { "arcane" },
    class = "mage",
    price = 340,
    repRank = 3,
    traits = { "trait_arcane_reservoir" },
}
