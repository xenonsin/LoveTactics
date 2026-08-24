-- THE CROSSING's keeper: the one who watches the tear and knows what comes out of it.
--
-- The tear is above ground, small, and it gives up people (data/buildings/hiring_hall.lua). Somebody
-- has to be standing at it -- a tear nobody attends is a hole in a wall, and the room the player opens
-- would be a counter with no one behind it while every other counter in the city has a face.
--
-- IT KEEPS A BLUEPRINT WITHOUT KEEPING A SHELF, for the reason the Cafe and the Touchstone do
-- (data/vendors/cafe.lua, data/vendors/touchstone.lua): what a vendor file buys here is a SHOPKEEPER.
-- The portrait, the name and the one-time first-visit greeting all read this file, and the hub's
-- first-visit machinery is keyed on a building naming a vendor. Three counters in this city now exist
-- on those terms, which is enough to call it the pattern rather than an exception.
--
-- `sells = false` is the whole of its shelf contract: Vendor.sells refuses everything, so Vendor.stock
-- is empty and no item can drift onto this counter by acquiring or losing a class. It has no `class`
-- either, which is what keeps it out of the market board -- the seven houses are the market and this is
-- not one of them (tests/hub_spec.lua asserts exactly that).
--
-- WHAT IT TAKES IS NOT MONEY. Every other counter in the city is paid in gold; this one is paid in
-- tokens carried up from below (models/voucher.lua), which is why it is on the plaza rather than the
-- market board. A keeper who cannot be bought is the right face for the one door whose price is how
-- deep you went.
return {
    name = "The Crossing",
    sells = false, -- sells no ITEMS; its whole offer is the crossing (models/voucher.lua)
    description = "Bring up a token and it will hold the tear long enough for one of them to come through.",
}
