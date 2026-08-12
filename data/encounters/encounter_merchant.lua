-- Encounter blueprint. THE MERCHANT: a wandering market that sells ordinary goods -- the gear and
-- supplies of the road's own price band (models/spoils.lua's Spoils.shelf) -- for gold, so the coin a
-- run forages or skims has somewhere to go on the map. Prestige-gated -- it shows up once a company has
-- an economy worth spending -- and uncommon. See encounter_relic_cache.lua for the shape.
return {
    name = "Merchant",
    kind = "merchant",
    weight = 1,
    minDay = 2,
}
