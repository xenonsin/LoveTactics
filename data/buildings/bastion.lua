-- THE BASTION: the knights' shelf, and one of the seven doors on the Houses board.
--
-- IT OPENS AT KNIGHT 1 -- that level in any body on the roster (`unlockClassLevel`, and
-- models/building.lua for the three gates this one replaced). The deed that opens a shelf is the deed
-- that will shop at it: play the class, and the class's counter is in the city.
--
-- WHAT IS ON IT past the door is the same ladder again -- Quest.shelfRung reads the roster's knight
-- level, so the shop deepens rung by rung as the class does rather than opening whole.
return {
    name = "The Bastion",
    order = 2,
    x = 350,
    y = 265,
    w = 270,
    h = 130,
    panel = "shop",
    district = "houses",
    vendor = "bastion", -- knight class
    description = "An order's armoury: the plate, and the oath that goes with it.",
    unlockClassLevel = 1,
}
