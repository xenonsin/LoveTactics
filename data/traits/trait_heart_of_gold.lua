-- HEART OF GOLD (rounds 1-2): taking gold or goods off a foe heals the bearer 15%, once a turn. A flag,
-- read by models/golem.lua's Golem.took from each seam that pays a taker: a coin heap looted, a theft
-- that lands (Combat.steal), gold chipped off a Gold Golem.
return {
    name = "Heart of Gold",
    description = "Taking gold or goods from a foe heals you 15% of your health, once a turn.",
    healsOnTake = true,
}
