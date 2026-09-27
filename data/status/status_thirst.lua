-- THE THIRST: a vampire's count of dry turns (models/thirst.lua; Wrath's vampires, 2026-09-26, "The Vampires of
-- Wrath"). +1 for every turn it ends without having drawn blood from a living body; at 3 (2 for a Fledgling,
-- newly turned) it is in Bloodlust. Drawing blood takes it off whole. While a Sire stands it stops at 2.
return {
    name = "Thirst",
    abbr = "Thr",
    description = "Thirst: one more for each turn it drew no blood. At 3 it is in Bloodlust.",
    color = { 0.560, 0.080, 0.140 }, -- badge tint (dark blood)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 3,
}
