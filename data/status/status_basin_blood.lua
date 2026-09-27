-- BLOOD IN THE BASIN: how full the Blood Countess's basin is (models/basin.lua). Every point of Bleed damage taken
-- anywhere on the board runs in; at 45 it is full, and the Countess bathes on her next turn. The count is the
-- clock, so the badge prints it (`badgeCount`) rather than a name -- read the number on the basin, not a tooltip.
local Basin = require("models.basin")

return {
    name = "Blood in the Basin",
    abbr = "Basn",
    description = "Every point of Bleed damage anywhere fills it. When it is full, the Countess bathes on her next turn.",
    color = { 0.620, 0.040, 0.100 }, -- badge tint (standing blood)
    duration = math.huge,
    hideDuration = true, -- the count is the story
    badgeCount = true,
    magnitude = 1,
    stacks = Basin.CAPACITY,
}
