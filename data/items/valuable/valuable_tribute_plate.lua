-- Tribute Plate: loot, and nothing else. See models/valuable.lua for what that means -- no class, no shelf, no
-- effect, no use below. It occupies 2 mule slots on the way out and turns into gold at a city counter.
return {
    name = "Tribute Plate",
    description = "Loot. Worth gold at a counter in the city, and worth nothing to anyone below.",
    flavor = "Beaten thin, stamped with a hand, and paid to something that took it.",
    sprite = "assets/items/valuable_tribute_plate.png",
    type = "valuable",
    valuable = true,
    -- Its worth in gold, paid in full at a counter (Valuable.value) -- a valuable is never marked down,
    -- because nobody ever sold you one.
    price = 700,
    -- Mule slots. See Valuable.bulk: worth per slot climbs with this, so the heavy pieces are the ones
    -- worth making room for.
    bulk = 2,
    -- The shallowest floor it turns up on (Valuable.pool).
    depth = 7,
}
