-- The item form of Last Stand: a veteran's token that, the first time its bearer is driven below 40%
-- health, throws up a physical barrier and grants +4 damage for the rest of the battle. A
-- fighter-class charm, sold at the Colosseum -- it pays out only when the fight has turned against you.
return {
    name = "Veteran's Resolve",
    description = "On first dropping below 40% health: raise a barrier and gain +4 Damage this battle.",
    flavor = "A battered campaign medal. It pays out only once the fight has already turned against you.",
    sprite = "assets/items/veterans_resolve.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    discipline = "warlord", -- deeper cut of the shelf: buyable only once the warlord gate is cleared
    price = 440,
    unlockQuests = 6,
    traits = { "trait_last_stand" },
}
