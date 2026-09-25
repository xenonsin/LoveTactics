-- BROOD: how near a Dragon Egg is to hatching (data/traits/trait_clutch.lua). One stack each time an ally
-- ends its turn beside it; at three it hatches. The count is the clock, and the badge is where the player
-- reads it.
return {
    name = "Brood",
    abbr = "Brood",
    description = "Brooded by the kobolds beside it. At three, it hatches.",
    color = { 0.760, 0.560, 0.300 }, -- badge tint (warm shell)
    duration = math.huge,
    hideDuration = true, -- the count is the story
    magnitude = 1,
    stacks = 3,
}
