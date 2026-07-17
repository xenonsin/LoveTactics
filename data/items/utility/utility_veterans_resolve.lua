-- The item form of Last Stand: a veteran's token that, the first time its bearer is driven below 40%
-- health, throws up a physical barrier and grants +4 damage for the rest of the battle. A
-- fighter-class charm, sold at the Colosseum -- it pays out only when the fight has turned against you.
return {
    name = "Veteran's Resolve",
    description = "Cornered below 40% health, you raise a barrier and hit harder.",
    flavor = "A battered campaign medal. It pays out only once the fight has already turned against you.",
    sprite = "assets/items/veterans_resolve.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    price = 220,
    repRank = 2,
    traits = { "trait_last_stand" },
}
