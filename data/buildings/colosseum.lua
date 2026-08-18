-- The Colosseum: the fighters' shelf, and the house of Wrath (data/vendors/colosseum.lua).
--
-- OPENS ON ITS OWN FIRST ERRAND, found on a floor (models/building.lua, models/errand.lua). The house
-- cannot ask -- a house asks inside its own shop and this one has no shop yet -- so its opening job is
-- lying at a dead end down there for the company to walk into.
--
-- On the MARKET board rather than in the city: seven shelves and a general store are one kind of door,
-- and they share a screen behind the city's Markets card.
return {
    name = "The Colosseum",
    order = 1,
    x = 40,
    y = 265,
    w = 270,
    h = 130,
    panel = "shop",
    district = "market",
    vendor = "colosseum", -- fighter class
    unlockErrand = true,
}
