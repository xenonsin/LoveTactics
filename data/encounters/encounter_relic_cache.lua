-- PARKED 2026-09-17. This stop's only payload was a run relic, and models/relic.lua is parked (see the
-- dated note at its head), so the Reliquary has nothing left to hand over. `parked = true` is read by
-- models/encounter.lua's `eligible` and is the whole of the parking -- the blueprint, the slate handler
-- in states/game.lua and ui/panels/relic_offer.lua are all still on disk. Lift all four together.
--
-- Encounter blueprint. A RELIQUARY: an unguarded cache holding a run relic (models/relic.lua) rather
-- than gear. Stepping onto it rolls one Virtue/Vice from the eligible shelf and offers it -- the primary
-- way the roguelike snowball gets stocked across a quest's ~8 stops. Uncommon so a relic still feels like
-- a find. `tier` (drawn by the reveal) leans the roll toward the common shelf; a Sealed Reliquary variant
-- (key-gated, rare) can come later. See data/encounters/encounter_treasure.lua for the shape.
return {
    name = "Reliquary",
    kind = "relic_cache",
    parked = true,
    weight = 2,
    depth = 1,
    -- The reveal rolls from Relic.pool with this bias; nil `alignment` means either a Virtue or a Vice
    -- can surface, which is the greed gamble of opening one at all.
    tier = nil,
}
