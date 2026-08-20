-- The Cafe: one supper before the road, worn by the whole company for the whole expedition.
--
-- IT ARRIVES ON THE SECOND FLOOR (models/building.lua's `unlockDepth`). A meal is a decision made
-- against a road you already know the shape of -- which floor, how deep, how long the company will be
-- down there before it eats again -- and on the morning of the first descent the player knows none of
-- that. A counter selling a buff for a trip nobody has taken is a menu read in a language not yet
-- learned. One floor down is the whole of the teaching: the company has been under once, come up
-- hungry, and the supper is now an answer to a question they have.
return {
    name = "Cafe",
    order = 7,
    x = 175,
    y = 480,
    w = 270,
    h = 130,
    -- Not a shop: the Cafe sells no items at all any more (data/vendors/cafe.lua). Its own panel opens
    -- onto the meal menu -- one supper before the road, worn by the whole company for the whole quest
    -- (models/meal.lua, docs/meals.md).
    panel = "cafe",
    description = "One supper, worn by the whole company for the whole expedition.",
    -- It keeps a vendor id even so, because it keeps a shopkeeper: the portrait, the name and the
    -- one-time first-visit greeting all hang off this (states/hub.lua's vendorScenes).
    vendor = "cafe",
    unlockDepth = 2, -- see models/building.lua
    unlockPrestige = 1,
}
