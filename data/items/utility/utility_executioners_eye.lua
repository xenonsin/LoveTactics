-- Grants the Executioner's Eye trait: when the bearer stuns or freezes a foe, it also Marks it (on a
-- cooldown), turning a lockdown into a kill window. Pairs with any stun/freeze the bearer can deliver.
return {
    name = "Executioner's Eye",
    description = "When you Stun or Freeze a foe, it is also Marked. Then it recharges.",
    flavor = "The Lodge teaches that a kill is decided before the shot. This is the deciding.",
    sprite = "assets/items/executioners_eye.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    price = 260,
    repRank = 3,
    traits = { "trait_executioners_eye" },
}
