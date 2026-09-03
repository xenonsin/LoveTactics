-- Gilded Thurible: loot, and nothing else. See models/valuable.lua for what that means -- no class, no shelf, no
-- effect, no use below. It occupies 1 mule slot on the way out and turns into gold at a city counter.
return {
    name = "Gilded Thurible",
    description = "Loot. Worth gold at a counter in the city, and worth nothing to anyone below.",
    flavor = "Swung until the chain wore through. The gold on it never did.",
    sprite = "assets/items/valuable_gilded_thurible.png",
    type = "valuable",
    valuable = true,
    -- Its worth in gold, paid in full at a counter (Valuable.value) -- a valuable is never marked down,
    -- because nobody ever sold you one.
    price = 110,
    -- Mule slots. See Valuable.bulk: worth per slot climbs with this, so the heavy pieces are the ones
    -- worth making room for.
    bulk = 1,
    -- The shallowest floor it turns up on (Valuable.pool).
    depth = 1,
}
