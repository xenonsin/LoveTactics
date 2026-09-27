-- HUNGERING: the Hungering Fang's count of dry turns (data/traits/trait_hungering_fang.lua). +3 Damage for each
-- turn its bearer ended without drawing blood, to three, and all of it spent on the next hit.
return {
    name = "Hungering",
    abbr = "Hng",
    description = "Hungering: increase damage by 3 for each turn you drew no blood. The next hit consumes it.",
    color = { 0.600, 0.120, 0.160 }, -- badge tint
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 3,
    statBonus = { damage = 3 },
    statBonusScales = true,
}
