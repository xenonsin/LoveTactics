-- The Cathedral: the priests' shelf, and the house of Lust.
--
-- OPENS ON ITS OWN FIRST ERRAND, found on a floor -- see data/buildings/colosseum.lua.
--
-- It used to be held shut a beat longer than its neighbours for a story reason: the campaign's padded
-- card ended with the company dead on the sand and its epilogue opened on a Cathedral ceiling, so the
-- first sight of the place was from a slab. That scene belongs to the Quest Board, which is retired, and
-- the door cannot wait on a quest nobody can finish.
return {
    name = "The Cathedral",
    order = 3,
    x = 660,
    y = 265,
    w = 270,
    h = 130,
    panel = "shop",
    district = "market",
    vendor = "cathedral", -- priest class
    unlockErrand = true,
}
