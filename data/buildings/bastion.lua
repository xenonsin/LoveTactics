-- The Bastion: the knights' shelf, and the house of Sloth.
--
-- OPENS ON ITS OWN FIRST ERRAND, found on a floor -- see data/buildings/colosseum.lua for the whole of
-- that note, and models/building.lua for why it is not the circle any more.
return {
    name = "The Bastion",
    order = 2,
    x = 350,
    y = 265,
    w = 270,
    h = 130,
    panel = "shop",
    district = "market",
    vendor = "bastion", -- knight class
    unlockErrand = true,
}
