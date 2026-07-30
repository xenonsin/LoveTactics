-- Encounter blueprint. THE FENCE: a wandering market that sells run relics (models/relic.lua) for gold,
-- so the coin a run forages or skims has somewhere to go on the map. Prestige-gated -- it shows up once a
-- company has an economy worth spending -- and uncommon. See encounter_relic_cache.lua for the shape.
return {
    name = "The Fence",
    kind = "fence",
    weight = 1,
    minPrestige = 2,
}
