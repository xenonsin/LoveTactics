-- HEART OF GOLD: the Gold Golem's drop (rounds 1-2, "The Golems of Greed"). Regild on the company's side,
-- widened by round 2's note "also stealing": whenever the wearer takes gold or goods off a foe -- a coin
-- heap looted, a theft that lands, gold chipped off a Gold Golem -- it heals 15% of its health. Once a turn
-- (status_heart_fed), so a fast hitter chipping a golem does not drink on every blow.
return {
    name = "Heart of Gold",
    description = "Taking gold or goods from a foe (a coin heap, a theft) heals you 15% of your health, once a turn.",
    flavor = "It beats faster near money. Most hearts do; this one admits it.",
    sprite = "assets/items/utility_heart_of_gold.png",
    type = "utility",
    tags = { "trinket" },
    class = "mammonite",
    unlockLevel = 5,
    traits = { "trait_heart_of_gold" },
}
