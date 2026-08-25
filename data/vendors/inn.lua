-- THE INN's keeper: the one who sets the bone.
--
-- IT KEEPS A BLUEPRINT WITHOUT KEEPING A SHELF, for the reason the Cafe, the Touchstone and the
-- Crossing do (data/vendors/cafe.lua, touchstone.lua, crossing.lua): what a vendor file buys here is a
-- SHOPKEEPER. The portrait, the name and the one-time first-visit greeting all read this file, and the
-- hub's first-visit machinery is keyed on a building naming a vendor. Four counters in this city now
-- stand on those terms, which is the pattern rather than an exception.
--
-- IT NEEDED A FACE MOST OF ALL, because of the four it is the one that touches the company. The Cafe
-- feeds them, the stone reads a satchel, the tear hands up a stranger; this one puts hands on a body
-- that came up broken. A counter that does that with nobody behind it is a room with a bill in it.
--
-- `sells = false` is the whole of its shelf contract: Vendor.sells refuses everything, so Vendor.stock
-- is empty and no item can drift onto this counter by acquiring or losing a class. No `class` either,
-- which keeps it off the market board -- the seven houses are the market and this is not one of them
-- (tests/hub_spec.lua asserts exactly that).
--
-- WHAT IT CHARGES IS PER HEAD (models/gate.lua's Gate.INN_PER_HEAD), which is not a shelf price and must
-- never become one. A bed is priced by how many of you there are, not by how badly the last floor went.
return {
    name = "The Inn",
    sells = false, -- sells no ITEMS; its whole offer is the night (models/gate.lua's Gate.rest)
    description = "A bed and a fire. What the fighting cost comes back; what it broke needs longer.",
}
