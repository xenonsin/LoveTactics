-- BALLAST WORN: what Golden Ballast pays for every impact blow it stands through -- 2 Defense, for the
-- rest of the fight, three times at most (the whole of the ballast's +6). Not a debuff for a Cure to lift:
-- it is the piece's own price, like Gilt Hunger's gold.
return {
    name = "Ballast Worn",
    abbr = "Worn",
    description = "Golden Ballast is wearing thin: reduce defense for the rest of the fight.",
    color = { 0.600, 0.480, 0.260 }, -- badge tint (dented gold)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 3,
    statBonus = { defense = -2 },
    statBonusScales = true,
}
