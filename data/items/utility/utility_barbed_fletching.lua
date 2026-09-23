-- BARBED FLETCHING: the manticore's volley rebuilt for a person, one quill at a time
-- (trait_barbed_fletching). Every weapon blow its bearer lands inflicts Quilled on the foe it struck, so
-- a company's own pierce -- the bearer's next blow included -- climbs two points a quill against it.
-- Asked for on review (2026-09-23) in place of an area volley: "utility that applies quill on each
-- attack". Off the Manticore; a trophy.
--
-- HUNTER STOCK: the Lodge's setup class -- "sets a target up, then takes it" -- and this sets up whatever
-- it touches. It builds nothing its bearer does not also spend: pair it with a bow and the quills it
-- lays are the ones its own arrows collect.
return {
    name = "Barbed Fletching",
    description = "Your weapon blows inflict Quilled on the foe they strike.",
    flavor = "Barbed back along the shaft, the way the tail is. It comes out of the wound the way it went in: badly.",
    sprite = "assets/items/utility_barbed_fletching.png",
    type = "utility",
    tags = { "pierce" },
    class = "hunter",
    unlockLevel = 3,
    unstocked = true,
    traits = { "trait_barbed_fletching" },
}
