return {
    name = "Cafe",
    order = 12,
    x = 815,
    y = 530,
    w = 270,
    h = 140,
    -- Not a shop: the Cafe sells no items at all any more (data/vendors/cafe.lua). Its own panel opens
    -- onto the meal menu -- one supper before the road, worn by the whole company for the whole quest
    -- (models/meal.lua, docs/meals.md).
    panel = "cafe",
    -- It keeps a vendor id even so, because it keeps a shopkeeper: the portrait, the name and the
    -- one-time first-visit greeting all hang off this (states/hub.lua's vendorScenes).
    vendor = "cafe",
    unlockPrestige = 1,
}
