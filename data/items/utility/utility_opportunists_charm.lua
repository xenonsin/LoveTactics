-- Grants the Opportunist trait: afflict a foe with any debuff and the bearer gains Haste (on a
-- cooldown). Rewards a debuff-heavy kit -- carry it beside your poisons, marks and cripples.
return {
    name = "Opportunist's Charm",
    description = "When you afflict a foe with a debuff, you gain Hasted. Then it recharges.",
    flavor = "The Undercroft's whole philosophy: someone else's bad turn is your good one.",
    sprite = "assets/items/opportunists_charm.png",
    type = "utility",
    tags = { "charm" },
    class = "rogue",
    price = 240,
    repRank = 2,
    traits = { "trait_opportunist" },
}
