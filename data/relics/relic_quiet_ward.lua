-- COMMON. The fourth corner of the damage/defense square: physical attack, physical armour, magical
-- attack, magical armour, one relic each at one point each. The set is deliberately complete, because a
-- rung whose rule is "one relic per stat" is a rung a player can hold in their head.
return {
    name = "The Quiet Ward",
    blurb = "+%d magic defense for the whole company.",
    tier = "common", mark = "Qw",
    scale = { 1, 1 },
    bonus = { magicDefense = 1 },
}
