-- The item form of Guardian's Blessing: a censer whose bearer's heals also lay a physical barrier on
-- their target -- every mend a ward. Slot it beside a healing ability and each cast shields as it
-- restores. A priest-class relic, sold at the Cathedral.
return {
    name = "Warding Censer",
    description = "Every heal you cast also shields its target.",
    flavor = "Sweet smoke trails it. Every mend a ward, and every ward a debt.",
    sprite = "assets/items/warding_censer.png",
    type = "utility",
    tags = { "holy" },
    class = "priest",
    price = 240,
    repRank = 2,
    traits = { "trait_guardians_blessing" },
}
