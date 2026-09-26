-- TAKEN UP: the Heir's Torc (data/traits/trait_heirs_torc.lua). Each ally that falls, the bearer takes up its
-- fight: +3 Damage for the rest of the fight, three times at most.
return {
    name = "Taken Up",
    abbr = "Heir",
    description = "Taken up a fallen ally's fight: increase damage for the rest of the fight.",
    color = { 0.760, 0.620, 0.260 }, -- badge tint (torc gold)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 3,
    statBonus = { damage = 3 },
    statBonusScales = true,
}
