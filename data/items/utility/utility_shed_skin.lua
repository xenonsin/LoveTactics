-- SHED SKIN: the naga apothecary's race item ("The Rift's Adventurers", slice D, approved 2026-10-09). Once a
-- fight, the wound that leaves the bearer below half its health sheds every status on it and heals a fifth of
-- its health (trait_shed_skin). Boons go with the banes: a skin is a skin.
--
-- Gated to naga (Character.canCarry). No price: a rift find on the apothecary's shelf at the class's floor.
return {
    name = "Shed Skin",
    description = "Once a fight, when you fall below half health, shed every status on you and heal a fifth of your health.",
    flavor = "The old skin keeps the poison, the curse and the knife wound, and the naga keeps walking.",
    sprite = "assets/items/utility_shed_skin.png",
    type = "utility",
    tags = { "natural" },
    class = "apothecary",
    race = "naga",
    unlockLevel = 8,
    traits = { "trait_shed_skin" },
}
