-- Miasmal Plate: the Plague Knight (knight x alchemist) wears its sickness. A charm that lays choking
-- fumes around its bearer and carries them wherever it walks (data/hazards/hazard_choking.lua -- every
-- body in the cloud EXCEPT the bearer's own side is Poisoned). Standing next to the Plague Knight is the
-- injury; it does not have to swing at all. A DELIBERATE BORROW of the incense machine, like the Coveted
-- Blood (docs/classes.md) -- a zone that is wherever the bearer is -- carrying no censer and no edge.
return {
    name = "Miasmal Plate",
    description = "Lays choking fumes around you that travel with you: adjacent foes are Poisoned.",
    flavor = "The Bastion asked what had happened to the shine. He said he had stopped polishing it.",
    sprite = "assets/items/utility_miasmal_plate.png",
    type = "utility", -- a charm, not armour: the walking cloud IS the item (cf. utility_coveted_blood)
    tags = { "charm", "poison" },
    class = "knight",
    discipline = "plague_knight", -- knight x alchemist; the Contagion mechanic's first stock
    price = 380,
    repRank = 3,
    incense = { hazard = "hazard_choking", radius = 1, amount = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 } },
}
