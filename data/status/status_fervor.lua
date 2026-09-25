-- FERVOR: a kobold that saw its dragon struck (data/traits/trait_dragonkin.lua, models/devotion.lua).
-- Approved as pitched (2026-09-24): +2 Damage for two turns. The cost of chipping a dragon instead of
-- killing it -- every kobold in sight of the blow comes on harder.
return {
    name = "Fervor",
    abbr = "Ferv",
    description = "Saw its dragon struck: increase damage.",
    color = { 0.820, 0.420, 0.220 }, -- badge tint (dragon-fire)
    duration = 10, -- ~two turns at Status.TICKS_PER_TURN
    statBonus = { damage = 2 },
}
