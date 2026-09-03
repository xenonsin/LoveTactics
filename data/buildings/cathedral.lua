-- THE CATHEDRAL: the priests' shelf, and one of the seven doors on the Houses board.
--
-- IT OPENS AT PRIEST 1 -- that level in any body on the roster (`unlockClassLevel`, and
-- models/building.lua for the three gates this one replaced). The deed that opens a shelf is the deed
-- that will shop at it: play the class, and the class's counter is in the city.
--
-- WHAT IS ON IT past the door is the same ladder again -- Quest.shelfRung reads the roster's priest
-- level, so the shop deepens rung by rung as the class does rather than opening whole.
return {
    name = "The Cathedral",
    order = 3,
    x = 660,
    y = 265,
    w = 270,
    h = 130,
    panel = "shop",
    district = "houses",
    vendor = "cathedral", -- priest class
    description = "Relics, rites, and what the church will part with.",
    unlockClassLevel = 1,
}
