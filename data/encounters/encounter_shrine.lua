-- PARKED 2026-09-17. The Altar's two verbs both spend and deal run relics, and models/relic.lua is
-- parked (see the dated note at its head), so neither has anything to trade. `parked = true` is read by
-- models/encounter.lua's `eligible`; the blueprint, the gamble/trade handler in states/game.lua and
-- ui/panels/relic_reveal.lua all remain on disk. Lift them together.
--
-- Encounter blueprint. A SIN'S ALTAR: a shrine that will hand over a powerful VICE relic (models/relic.lua)
-- for an upfront toll in gold. The greed-vs-safety gamble made into a stop -- spend the coin you foraged
-- for a boon that bites. Uncommon, and only ever offers Vices. See encounter_relic_cache.lua for shape.
return {
    name = "Sin's Altar",
    kind = "shrine",
    parked = true,
    weight = 1,
    depth = 1,
}
