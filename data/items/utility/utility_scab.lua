-- Scab: the barbarian's Blood Price way back (docs/engines.md). Every point of health the bearer lost on
-- its own turn -- a Red Tithe, a Wound Gift's price, a riposte taken mid-swing -- comes back when that
-- turn ends in a kill (trait_scab).
return {
    name = "Scab",
    description = "A kill heals the health you lost this turn.",
    flavor = "It never quite closes, and the barbarians who wear one would not want it to.",
    sprite = "assets/items/utility_scab.png",
    type = "utility",
    tags = { "trinket" },
    class = "barbarian",
    unlockLevel = 6,
    traits = { "trait_scab" },
    bonus = { defense = 1 },
}
