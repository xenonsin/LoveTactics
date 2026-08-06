-- The Cafe: the one vendor that sells no items at all. It sells SUPPERS.
--
-- It used to be the general store -- a shelf for the classless priced goods plus a resale rack for
-- every `potion`, whichever house brewed it. Both halves were a hedge against the seven houses rather
-- than a thing of its own: the torch, the boots and the flare were classless only because nobody had
-- asked which sin wanted them (they all have a house now), and the potion resale meant the Crucible's
-- own ladder could be walked around by shopping next door.
--
-- What it sells instead is one meal before you set out, and the meal is a rule about the WHOLE company
-- rather than an item somebody carries: see models/meal.lua and docs/meals.md. It keeps a blueprint
-- here anyway, because it keeps a shopkeeper -- the portrait, the name and the one-time greeting
-- (data/conversations/cafe/) all read this file, and the hub's first-visit machinery is keyed on a
-- building naming a vendor.
--
-- `sells = false` is the whole of its shelf contract: Vendor.sells refuses everything, so
-- Vendor.stock is empty and no item can drift onto this counter by acquiring (or losing) a class.
return {
    name = "The Cafe",
    sells = false, -- sells no ITEMS; its whole offer is the meal menu (models/meal.lua)
    meals = true,  -- the kitchen: what ui/panels/cafe.lua opens onto
    sprite = "assets/vendors/cafe.png", -- shopkeeper portrait; falls back to a placeholder
    description = "One hot meal before the road, and it stays with you the whole way out.",
}
