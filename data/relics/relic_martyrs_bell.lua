-- VIRTUE · combat · rare. The first ally felled in each fight catches a second wind and rises once. A
-- pure trait relic: it names an existing combat reflex (trait_second_wind) and battle setup attaches it
-- to every party unit, so the whole reactive-trait system carries it for free -- no bespoke combat path.
return {
    name = "Martyr's Bell",
    blurb = "The first time each ally would fall in a fight, they rise once instead.",
    tier = "rare", alignment = "virtue", affinity = "combat", weight = 1,
    traits = { "trait_second_wind" }, scope = "party",
}
