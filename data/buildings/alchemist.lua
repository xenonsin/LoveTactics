return {
    name = "The Crucible",
    order = 15,
    x = 660,
    y = 564,
    w = 270,
    h = 130,
    panel = "shop",
    vendor = "alchemist", -- alchemist class
    -- The last of the seven vendors to open. You do not envy until you have seen what the others own.
    -- OPENS WHEN ITS CIRCLE FALLS (models/building.lua). This house IS one of the seven sins, and
    -- putting that circle's general down in the descent is what puts its shelf in the city.
    unlockCircle = true,
    unlockPrestige = 4,
}
