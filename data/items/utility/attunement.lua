-- Attunement: a wider channel for the arcane. A passive charm that raises the bearer's maximum mana
-- (`maxBonus.mana`, folded into Combat.unreservedMax). Mana persists between battles and does not
-- refill, so like Toughness this lifts the ceiling as headroom -- room to bank more mana (via Focus or
-- an Arcane Reservoir) and hold a bigger reserve for the spells that need it.
return {
    name = "Attunement",
    description = "Raises your maximum mana by 12.",
    sprite = "assets/items/attunement.png",
    type = "utility",
    tags = { "charm" },
    class = "mage",
    price = 180,
    repRank = 2,
    maxBonus = { mana = 12 },
}
