-- THE MARKET: the city's one shop, and the building that replaced eight.
--
-- The square used to stand here -- The Markets, a board of its own holding seven shopfronts, one per
-- house, each shut until you had found and run that house's first errand underground. Every part of
-- that is gone. The houses are CLASSES now (docs/classes.md): a class is something a body climbs, not a
-- room you unlock, so there is nothing left for seven doors to gate and no reason for a square to hold
-- them. What is left is a counter, and a counter is a building.
--
-- IT IS ON THE CITY BOARD RATHER THAN BEHIND A DISTRICT, which is the whole point of the change. The
-- square existed because seven shelves are too many cards for one street; one shelf is not, and a board
-- that holds a single door is a corridor with a door at the end of it.
--
-- NO UNLOCK GATE OF ANY KIND. It is open on the first morning of a fresh save, which is deliberate:
-- what the market sells is bounded by the company's tier and by what it can afford (models/market.lua),
-- and a shop that is SHUT teaches nothing while a shop full of things you cannot afford yet teaches the
-- whole ladder at a glance.
return {
    name = "The Market",
    order = 4,
    x = 835,
    y = 120,
    w = 270,
    h = 130,
    panel = "shop",
    vendor = "market",
    description = "Everything anyone came back up with, and a few things nobody did.",
}
