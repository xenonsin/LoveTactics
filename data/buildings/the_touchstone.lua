-- THE TOUCHSTONE: the counter that reads what the rift hands up unread (models/identify.lua).
--
-- A touchstone is a real instrument and it is the older half of an assay office: a slab of dark stone
-- that a piece of metal is drawn across, read by the colour of the streak it leaves. The city names its
-- doors after the instrument rather than the office -- a crucible, a bastion, an arcanum -- and this is
-- the one candidate where the object IS the mechanic. Something unknown is drawn across it and comes
-- back legible.
--
-- IT SITS DIRECTLY UNDER THE RIFT, in the last free slot on the plaza, between the Cafe and the Dueling
-- Grounds. Not decoration: what comes up the stair walks straight into it, and the two cards read as one
-- movement down the middle of the screen.
--
-- IT ARRIVES ON THE FIRST THING NOBODY CAN READ (models/building.lua's `unlockUnidentified`), which is
-- the most literal of the six gates the city grows on. The Cafe waits for a road you have walked, the
-- Inn waits for a bone that needs setting; this waits for the object itself to be in your hands. The
-- player finds the thing, cannot use it, and THEN the door is there. Nothing has to explain it.
--
-- NOT A SHOP. It keeps no shelf, and the panel it opens is a BENCH -- it takes a thing you already own
-- and changes it, the way the Forge does. Vendors sell; benches work. The vendor id below is for the
-- shopkeeper, not for a shelf: see data/vendors/touchstone.lua.
return {
    name = "The Touchstone",
    order = 9,
    x = 490,
    y = 480,
    w = 300,
    h = 130,
    description = "It reads what the rift hands up unread, for a fee.",
    panel = "touchstone",
    -- Keeps a vendor id without keeping a shelf, exactly as the Cafe does (data/buildings/cafe.lua):
    -- the portrait, the name and the one-time first-visit greeting all hang off this, and its record in
    -- `visitedVendors` is also what keeps the door standing once it has been walked through
    -- (models/identify.lua's Identify.everFound).
    vendor = "touchstone",
    unlockUnidentified = true, -- see models/building.lua
    unlockPrestige = 1,
}
