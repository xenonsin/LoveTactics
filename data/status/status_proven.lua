-- PROVEN: the orc's racial rule, as a badge (data/traits/trait_proven.lua; 2026-09-26, "The Orcs of Wrath"). A
-- killing blow makes an orc Proven: +2 Damage and +2 Defense for the rest of the fight, three times at most. Each
-- stack is a scar. Also worn by a company body through Orc Scars, and handed across by Blood Offering.
return {
    name = "Proven",
    abbr = "Prvn",
    description = "Proven by a kill: increase damage and defense for the rest of the fight.",
    color = { 0.560, 0.180, 0.140 }, -- badge tint (old blood)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 3,
    statBonus = { damage = 2, defense = 2 },
    statBonusScales = true,
}
