-- THE HEIR'S TORC: the Warchief's first drop (approved as pitched, 2026-09-26, "The Orcs of Wrath"). When an ally
-- falls you take up its fight: heal 25% and +3 Damage for the fight, up to three times (trait_heirs_torc). Nothing
-- else on the shelf triggers on an ally falling. Its partner is The Strongest Leads, the Warchief's second drop.
return {
    name = "Heir's Torc",
    description = "When an ally falls, heal 25% of your max health and increase damage by 3 for the fight, up to 3 times.",
    flavor = "It has been taken off three necks and closed around a fourth. It fitted every one of them.",
    sprite = "assets/items/utility_heirs_torc.png",
    type = "utility",
    tags = { "trinket" },
    class = "fighter",
    unlockLevel = 8,
    unstocked = true,
    traits = { "trait_heirs_torc" },
}
