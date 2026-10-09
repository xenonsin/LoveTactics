-- CONSTRICT: the naga plague knight's race item ("The Rift's Adventurers", slice D, approved 2026-10-09). A blow
-- the bearer lands on a Poisoned foe Roots it (trait_constrict): the plague knight's poison is the setup and the
-- coils are the payoff, so the foe that is dying slowly also stops walking away.
--
-- Gated to naga (Character.canCarry). No price: a rift find on the plague knight's shelf at the class's floor.
return {
    name = "Constrict",
    description = "Your blows Root a foe that is Poisoned.",
    flavor = "It holds on until the venom does the rest, and it is in no hurry.",
    sprite = "assets/items/utility_constrict.png",
    type = "utility",
    tags = { "charm" },
    class = "plague_knight",
    race = "naga",
    unlockLevel = 9,
    traits = { "trait_constrict" },
}
