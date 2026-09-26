-- BOTTLED RAGE: the hits a bearer of the Brute's drop has taken and not yet spent (trait_bottled_rage,
-- ability_bottled_rage). A stacking status, capped at 5; it stays until the ability spends it.
return {
    name = "Bottled Rage",
    abbr = "Btl",
    description = "Hits taken and held in, to 5. The Bottled Rage ability consumes them all at once.",
    color = { 0.851, 0.325, 0.180 }, -- badge tint (ember)
    duration = math.huge,
    hideDuration = true,
    stacks = 5,
    magnitude = 1,
}
