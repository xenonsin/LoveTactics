-- Cripple: the unit's movement is cut for a time. Movement is a flat stat (Combat.moveBudget reads
-- flatStat "movement"), so a plain statBonus does the whole job -- the blue reachable set simply
-- shrinks, no special-case code. Contrast Blind, whose range cut needs its own reader.
return {
    name = "Cripple",
    abbr = "Crp",
    description = "Crippled: moves fewer spaces each turn.",
    color = { 0.72, 0.45, 0.20 }, -- badge tint (rust)
    duration = 4,
    debuff = true,               -- removable by Cure
    statBonus = { movement = -2 },
}
