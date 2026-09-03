-- UNCOMMON. A small RULE CHANGE rather than a stat swap, which is what makes it read as a rung above The
-- Keen Edge rather than a variant of it: it re-draws the board for the back line, and then punishes them
-- for being caught on it.
--
-- Reach is resolved per ability rather than carried as a stat on the body, so both halves are rules.
return {
    name = "The Far Mark",
    blurb = "Every ability reaches +%d tiles.",
    tier = "uncommon", mark = "Fm",
    cost = "-%d damage against anything adjacent.",
    costScale = { 3, 1 },
    scale = { 1, 1 },
    rules = { abilityRange = true, contactPenalty = true },
    ruleScale = { abilityRange = { 1, 1 }, contactPenalty = { 3, 1 } },
}
