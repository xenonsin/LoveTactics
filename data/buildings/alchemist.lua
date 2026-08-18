-- The Crucible: the alchemists' shelf, and the house of Envy.
--
-- OPENS ON ITS OWN FIRST ERRAND, found on a floor -- see data/buildings/colosseum.lua.
--
-- It was the last of the seven to open, on the reasoning that you do not envy until you have seen what
-- the others own. That ordering came off a prestige ladder the city no longer climbs; the houses are met
-- in whatever order the run deals their work now (models/descent.lua's Descent.openerAt).
return {
    name = "The Crucible",
    order = 7,
    x = 815,
    y = 413,
    w = 270,
    h = 130,
    panel = "shop",
    district = "market",
    vendor = "alchemist", -- alchemist class
    unlockErrand = true,
}
