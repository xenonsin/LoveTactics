-- Grants the Executioner's Eye trait: when the bearer stuns or freezes a foe, it also Marks it (on a
-- cooldown), turning a lockdown into a kill window. Pairs with any stun/freeze the bearer can deliver.
return {
    name = "Executioner's Eye",
    description = "When you stun or freeze a foe, mark it for the kill (then it recharges).",
    sprite = "assets/items/executioners_eye.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    price = 260,
    repRank = 3,
    traits = { "executioners_eye" },
}
