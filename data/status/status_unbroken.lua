-- UNBROKEN: the streak the Berserker's drops carry into a player's hand (2026-09-26, "The Orcs of Wrath"): +2
-- Damage for each turn in a row the bearer has landed a hit, up to +10. The Unbroken Axe counts its own hits,
-- Warpaint counts every hit; worn together they do not add -- the badge carries the longer of the two streaks
-- (data/traits/trait_unbroken.lua).
return {
    name = "Unbroken",
    abbr = "Unbr",
    description = "Unbroken: more damage for each turn in a row you have landed a hit.",
    color = { 0.780, 0.300, 0.160 }, -- badge tint (war-paint red)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 5,
    statBonus = { damage = 2 },
    statBonusScales = true,
}
