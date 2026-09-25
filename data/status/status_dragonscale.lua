-- DRAGONSCALE: a kobold blessed by its Scale-Priest (data/items/ability/ability_scale_blessing.lua): +3
-- Defense for about two turns.
return {
    name = "Dragonscale",
    abbr = "Scale",
    description = "Blessed with a dragon's scale: increase defense.",
    color = { 0.620, 0.300, 0.220 }, -- badge tint (old red scale)
    duration = 10, -- ~two turns
    statBonus = { defense = 3 },
}
