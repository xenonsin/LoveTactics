-- The Touchstone: the second vendor that sells no items at all. It sells READINGS.
--
-- Four houses dig the rift and none of them trusts the other three to say what came out of it, so the
-- counter that says it has to belong to none of them. That is the whole of this house's place in the
-- world: not a shop, not a house, a neutral stone somebody pays to be told the truth by.
--
-- IT KEEPS A BLUEPRINT ANYWAY, for the same reason the Cafe does (data/vendors/cafe.lua): it keeps a
-- shopkeeper. The portrait, the name and the one-time first-visit greeting (data/conversations/touchstone/)
-- all read this file, and the hub's first-visit machinery is keyed on a building naming a vendor.
--
-- `sells = false` is the whole of its shelf contract: Vendor.sells refuses everything, so Vendor.stock is
-- empty and no item can drift onto this counter by acquiring or losing a class. What it charges for is a
-- SERVICE priced by the floor a piece came off (models/identify.lua's Identify.fee), which is not a shelf
-- price and must never become one -- a fee derived from what the piece is worth would print the answer on
-- the price tag.
return {
    name = "The Touchstone",
    sells = false, -- sells no ITEMS; its whole offer is the reading (models/identify.lua)
    description = "Bring up what nobody can name. The stone will say what it is.",
}
