-- Encounter blueprint. THE MERCHANT: a wandering market that sells ordinary goods -- the gear and
-- supplies of the road's own price band (models/spoils.lua's Spoils.shelf) -- for gold, so the coin a
-- run forages or skims has somewhere to go on the map. Prestige-gated -- it shows up once a company has
-- an economy worth spending -- and uncommon. See encounter_relic_cache.lua for the shape.
-- RELIABLE FROM THE FIRST FLOOR, and that is a deliberate reversal of "uncommon".
--
-- It was `weight = 1, minDay = 2` -- rare, and absent from floor one -- on the reasoning that a market
-- should turn up once a company has an economy worth spending. The city has since become a place where
-- every shelf is a HOUSE that opens only on work you find underground (models/errand.lua), so a fresh
-- save's purse had one counter to spend at (the General Store's consumables) and the road had almost
-- nothing. This is the road being the shop, which is what models/gate.lua argues the descent's economy
-- should be: gear comes off the floors, so the stop that SELLS gear has to actually appear on them.
--
-- Still well under a fight's weight -- a floor is a place with things on it, not a bazaar -- and the
-- descent's own texture scaling cuts it further (Descent.TEXTURE_SCALE), which is why the raw number
-- here is larger than it looks.
return {
    name = "Merchant",
    kind = "merchant",
    weight = 4,
    minDay = 1,
}
