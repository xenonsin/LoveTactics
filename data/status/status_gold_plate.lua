-- GOLD PLATE: a Gold Golem's plating (trait_shed_plate, round 2). Four to begin, +2 Defense each. An
-- impact blow knocks one off as a COIN HEAP beside it -- gold the company can loot, or the golem can eat
-- back on (Regild, models/golem.lua), which is why this one has no cap: every heap it eats is one more.
return {
    name = "Gold Plate",
    abbr = "Gold",
    description = "Plated in solid gold: increase defense per plate. An impact blow knocks one off as a coin heap.",
    color = { 0.886, 0.700, 0.250 }, -- badge tint (bright gold)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 99, -- a count, not a cap
    statBonus = { defense = 2 },
    statBonusScales = true,
}
