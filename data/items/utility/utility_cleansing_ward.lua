-- Grants the Cleansing Ward trait: the first debuff to land on the bearer is stripped straight back
-- off (on a cooldown). A defensive charm for a front-liner who expects to be poisoned, blinded or marked.
return {
    name = "Cleansing Ward",
    description = "Strips the first debuff to land on you, then must recharge.",
    flavor = "The Cathedral's cheapest mercy, and the one it is proudest of.",
    sprite = "assets/items/cleansing_ward.png",
    type = "utility",
    tags = { "ward" },
    class = "priest",
    price = 260,
    repRank = 2,
    traits = { "trait_cleansing_ward" },
}
