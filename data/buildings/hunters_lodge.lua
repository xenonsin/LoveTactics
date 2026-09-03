-- HUNTER'S LODGE: the hunters' shelf, and one of the seven doors on the Houses board.
--
-- IT OPENS AT HUNTER 1 -- that level in any body on the roster (`unlockClassLevel`, and
-- models/building.lua for the three gates this one replaced). The deed that opens a shelf is the deed
-- that will shop at it: play the class, and the class's counter is in the city.
--
-- WHAT IS ON IT past the door is the same ladder again -- Quest.shelfRung reads the roster's hunter
-- level, so the shop deepens rung by rung as the class does rather than opening whole.
return {
    name = "Hunter's Lodge",
    order = 4,
    x = 970,
    y = 265,
    w = 270,
    h = 130,
    panel = "shop",
    district = "houses",
    vendor = "hunters_lodge", -- hunter class
    description = "Bows, traps and field kit, from people who work outdoors.",
    unlockClassLevel = 1,
}
