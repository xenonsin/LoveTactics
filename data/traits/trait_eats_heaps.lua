-- REGILD (round 1): a Gold Golem EATS the coin heaps. A flag, read in two places: hazard_coin_heap
-- `welcomes` the bearer and feeds it (Golem.eat: heal 15%, one more Gold Plate), and models/ai.lua's
-- fallback walk heads for the nearest heap when there is nothing to hit. Looting a heap first is how the
-- company starves it.
return {
    name = "Regild",
    description = "Eats coin heaps it steps on, healing and plating itself with the gold.",
    eatsHeaps = true,
}
