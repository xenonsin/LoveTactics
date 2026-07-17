-- The item form of Martyr's Vow: a saint's icon whose bearer will, once per battle, take a lethal
-- blow meant for an adjacent ally. Slot it and any character can spend their life to save another's.
-- A priest-class relic, sold at the Cathedral.
return {
    name = "Martyr's Icon",
    description = "Once per battle, take a mortal blow meant for an ally beside you.",
    flavor = "A saint painted mid-sacrifice. The Cathedral sells the picture, not the nerve.",
    sprite = "assets/items/martyrs_icon.png",
    type = "utility",
    tags = { "holy" },
    class = "priest",
    price = 260,
    repRank = 3,
    traits = { "trait_martyrs_vow" },
}
