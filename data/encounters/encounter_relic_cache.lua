-- Encounter blueprint. A RELIQUARY: an unguarded cache holding a run relic (models/relic.lua) rather
-- than gear. Stepping onto it rolls one Virtue/Vice from the eligible shelf and offers it -- the primary
-- way the roguelike snowball gets stocked across a quest's ~8 stops. Uncommon so a relic still feels like
-- a find. `tier` (drawn by the reveal) leans the roll toward the common shelf; a Sealed Reliquary variant
-- (key-gated, rare) can come later. See data/encounters/encounter_treasure.lua for the shape.
return {
    name = "Reliquary",
    kind = "relic_cache",
    weight = 2,
    minPrestige = 1,
    -- The reveal rolls from Relic.pool with this bias; nil `alignment` means either a Virtue or a Vice
    -- can surface, which is the greed gamble of opening one at all.
    tier = nil,
}
