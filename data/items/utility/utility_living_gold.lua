-- LIVING GOLD: what a Gold Golem IS (reviewed over two rounds, 2026-09-25, "The Golems of Greed"). Round 2
-- asked that it be no weaker than the Earth Golem, so it carries every Earth Golem rule and more of each:
--   * GOLD PLATE           four plates, +2 Defense each; an impact blow knocks one off as a COIN HEAP
--                          (trait_shed_plate, status_gold_plate) -- gold to loot, or to eat back on
--   * THE VEIN             the hole it Delves out of is gold, or one time in three lava (trait_strikes_vein)
--   * REGILD               it eats heaps: heals 15% and gains a plate, no cap (trait_eats_heaps)
--   * CHIPPED GOLD         every blow that lands on it pays 3 gold into the spoils (trait_chipped_gold)
--   * THE HOARD FALLS OUT  four coin heaps where it falls (trait_hoard_falls_out)
--   * GOLD CALLS TO GOLD   heaps within 4 slide a tile toward it each turn (trait_gold_calls)
--
-- BOUND AND UNSTEALABLE: an organ, not kit.
return {
    name = "Living Gold",
    description = "Gold plates that shed as coin heaps. Eats heaps to heal and re-plate, pulls them in, pays gold per blow taken.",
    flavor = "Every coin in the mountain wants to be part of it. Most of them already are.",
    sprite = "assets/items/utility_living_gold.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_shed_plate", "trait_strikes_vein", "trait_eats_heaps", "trait_chipped_gold",
        "trait_hoard_falls_out", "trait_gold_calls" },
    traitParams = { plateStatus = "status_gold_plate", plates = 4, shedAs = "heap" },
}
