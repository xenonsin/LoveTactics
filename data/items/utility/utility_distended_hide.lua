-- The Sated's hide, and the belly behind it: this is what carries Three Meals (data/traits/trait_three_meals.lua).
--
-- IT USED TO CARRY A PHASE TABLE with negative magnitudes -- the Sated shed four Defense at two thirds and
-- four more and five Damage at one third -- which made it the one fight that got easier as it was cut, and
-- it was a placeholder. Reviewed over two rounds (2026-09-23, "The Sated and the Flight"), the conceit
-- kept its shape and changed its cause: the Sated gets lighter because it SPENDS its meals (Retch,
-- Settle) and has them knocked out of it (a critical), and it gets heavier again by eating whatever dies
-- beside it. Nothing about it now is read off its health bar, which was the round-one note: "just like
-- lose more mechanic".
--
-- Natural kit: no class, no price, noSteal, outside every shelf (tests/bestiary_spec.lua).
return {
    name = "Distended Hide",
    description = "Holds three meals. Eats whatever dies beside it; a critical hit knocks a meal loose.",
    flavor = "Most of a circle went in here. None of it made the thing faster.",
    sprite = "assets/items/distended_hide.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_three_meals" },
}
