-- GOLD PLATE: a Gold Golem's plating (trait_shed_plate, round 2). Four to begin, +2 Defense each. An
-- impact blow knocks one off as a COIN HEAP beside it -- gold the company can loot, or the golem can eat
-- back on (Regild, models/golem.lua), which is why this one has no cap: every heap it eats is one more.
--
-- THE GILDED KING WEARS IT TOO (2026-09-26, utility_gilded_flesh), and on him it is a countdown: six plates,
-- ANY blow knocks one off (Shed Plate's `shedOn = "blow"`), and nothing puts one back -- he does not eat
-- heaps, and his curse turns every heal to gold. So the description says what both bodies share and
-- leaves which blow to the trait that decides it.
return {
    name = "Gold Plate",
    abbr = "Gold",
    description = "Plated in solid gold: increase defense per plate. A plate knocked off lands as a coin heap.",
    color = { 0.886, 0.700, 0.250 }, -- badge tint (bright gold)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 99, -- a count, not a cap
    statBonus = { defense = 2 },
    statBonusScales = true,
}
