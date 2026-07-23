-- Aegis of the Oath: the knight half of the Paladin (knight x priest). A charm that raises a shared
-- greatshield of light around its bearer and carries it wherever they walk (data/hazards/
-- hazard_shared_bulwark.lua -- every ally standing in it carries a physical barrier that swallows a
-- blow whole). The Given Guard's trade made mobile and holy: the knight's protection is a place now,
-- and the place moves with the oath that made it. Borrows the incense machine like the Coveted Blood.
return {
    name = "Aegis of the Oath",
    description = "Raises a moving ward around you: allies beside you carry a barrier that swallows a blow.",
    flavor = "An oath is not a wall you stand behind. It is a wall that follows you to where the wall is needed.",
    sprite = "assets/items/utility_aegis_of_the_oath.png",
    type = "utility", -- a charm, not armour: the walking ward IS the item (cf. utility_coveted_blood)
    tags = { "charm", "holy" },
    class = "knight",
    discipline = "paladin", -- knight x priest; the Ward-aura mechanic's first stock
    price = 440,
    repRank = 3,
    incense = { hazard = "hazard_shared_bulwark", radius = 1, amount = { 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3 } },
}
