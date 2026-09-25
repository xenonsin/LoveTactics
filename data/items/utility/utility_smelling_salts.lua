-- Off Luxuria's body (Descent.DROPS.lust): the answer to her charm, carried in a pocket. The first time
-- each fight the bearer is Charmed, it breaks at once (data/traits/trait_smelling_salts.lua).
--
-- A general's find: `unstocked`, on the alchemist's shelf -- the house that bottles what brings you round.
return {
    name = "Smelling Salts",
    description = "The first time each fight you are Charmed, you come to your senses at once.",
    flavor = "Hartshorn and something sharper. It smells like being told no.",
    sprite = "assets/items/utility_smelling_salts.png",
    type = "utility",
    tags = { "defensive" },
    class = "alchemist",
    unlockLevel = 13,
    unstocked = true,
    traits = { "trait_smelling_salts" },
}
