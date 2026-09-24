-- Resistant: Wind -- the ninth element's ward, which it had never been given. Wind became a real element
-- with the wyverns (Combat.ELEMENTS, appended last) and every other element already had its Resistant
-- status, so a rule that learns "whatever just hit me" (data/traits/trait_studied.lua) had a hole exactly
-- one blow wide: a Wind Shear taught Gula nothing. Same shape as its eight siblings: a negative
-- `vulnerable`, floored at 1 like any mitigation, a buff rather than a debuff. See status_resistant_fire.
return {
    name = "Resistant: Wind",
    abbr = "Rwi",
    description = "Wind-warded: takes less damage from wind.",
    color = { 0.620, 0.780, 0.760 }, -- badge tint (a pale gale; the abbr marks the state)
    duration = 15,
    vulnerable = { wind = -4 },
}
