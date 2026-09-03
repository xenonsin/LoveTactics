-- THE ARCANUM: the mages' shelf, and one of the seven doors on the Houses board.
--
-- IT OPENS AT MAGE 1 -- that level in any body on the roster (`unlockClassLevel`, and
-- models/building.lua for the three gates this one replaced). The deed that opens a shelf is the deed
-- that will shop at it: play the class, and the class's counter is in the city.
--
-- WHAT IS ON IT past the door is the same ladder again -- Quest.shelfRung reads the roster's mage
-- level, so the shop deepens rung by rung as the class does rather than opening whole.
return {
    name = "The Arcanum",
    order = 6,
    x = 505,
    y = 413,
    w = 270,
    h = 130,
    panel = "shop",
    district = "houses",
    vendor = "arcanum", -- mage class
    description = "Staves, foci, and the reading that makes them work.",
    unlockClassLevel = 1,
}
