-- BACK 2026-10-24 (parked 2026-09-17 to 2026-10-24). Relics returned as a per-trip layer
-- (models/relic.lua), so the Altar's two verbs -- the gamble and the two-for-one trade -- have
-- something to deal again. Eligible in the pool, never guaranteed; new every run (the rift resets).
--
-- Encounter blueprint. A SIN'S ALTAR: a shrine that will hand over a powerful VICE relic (models/relic.lua)
-- for an upfront toll in gold. The greed-vs-safety gamble made into a stop -- spend the coin you foraged
-- for a boon that bites. Uncommon, and only ever offers Vices. See encounter_relic_cache.lua for shape.
return {
    name = "Sin's Altar",
    kind = "shrine",
    weight = 1,
    depth = 1,
}
