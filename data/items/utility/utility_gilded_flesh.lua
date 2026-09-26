-- GILDED FLESH: what the Gilded King IS (2026-09-26, the Gilded King). He starved when his bread turned to
-- gold in his mouth, and the gold did not stop at the bread:
--   * GOLD PLATE        six plates, +2 Defense each, and ANY blow knocks one off as a COIN HEAP beside him
--                       (trait_shed_plate with `shedOn = "blow"`, status_gold_plate -- the Gold Golem's own
--                       plating). He never eats one back and nothing puts one on again, so every blow the
--                       company lands makes him softer and pays it.
--   * TURNED TO GOLD    a heal aimed at him is a coin heap instead, and restores nothing (trait_turned_to_gold)
--   * THE GILDED GUARD  his men open the fight Gilded (trait_the_gilded_guard)
--
-- The Gold Golem's machinery on purpose (reviewed with the echo named): the same plate, the same heap, the
-- same trait -- one parameter apart, where the golem sheds only under weight.
--
-- BOUND AND UNSTEALABLE: an organ, not kit.
return {
    name = "Gilded Flesh",
    description = "Gold plates that any blow knocks off as coin heaps, never to return. Heals turn to gold. Allies open Gilded.",
    flavor = "The bread went first. Then the hand that held it.",
    sprite = "assets/items/utility_gilded_flesh.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_shed_plate", "trait_turned_to_gold", "trait_the_gilded_guard" },
    traitParams = { plateStatus = "status_gold_plate", plates = 6, shedAs = "heap", shedOn = "blow" },
}
