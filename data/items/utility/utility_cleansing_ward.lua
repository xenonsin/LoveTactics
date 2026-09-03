-- Grants the Cleansing Ward trait: the first debuff to land on the bearer is stripped straight back
-- off (on a cooldown). A defensive charm for a front-liner who expects to be poisoned, blinded or marked.
return {
    name = "Cleansing Ward",
    description = "Strips the first debuff to land on you, then goes on cooldown.",
    flavor = "The Cathedral's cheapest mercy, and the one it is proudest of.",
    sprite = "assets/items/cleansing_ward.png",
    type = "utility",
    tags = { "ward" },
    class = "exorcist", -- deeper cut of the shelf: buyable only once the exorcist gate is cleared
    price = 330,
    unlockQuests = 3,
    traits = { "trait_cleansing_ward" },
    -- the first debuff simply does not land
    bonus = { magicDefense = 2 },
}
