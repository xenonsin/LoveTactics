-- REBORN: what a Phoenix carries back up out of its Ember (models/pride_elites.lua; "Pride's Bestiary",
-- 2026-09-30). One stack for every time it has died, and +3 Damage a stack: it never repents, it only
-- returns, and it returns angrier. The count is the story, so the badge shows it and no clock.
--
-- Not a debuff, so no Cure takes the anger off it; a Dispel that strips blessings may, which is fair.
return {
    name = "Reborn",
    abbr = "Rbn",
    description = "Reborn: increases damage by 3 for each time it has died.",
    color = { 0.960, 0.560, 0.180 }, -- badge tint (flame)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 99,
    statBonus = { damage = 3 },
    statBonusScales = true, -- the table is one death's worth (Status.statBonus)
}
