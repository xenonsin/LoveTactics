-- LYING LOW: how a Shoalkin hides, carried as creature kit (data/traits/trait_lying_low.lua). Natural kit
-- only (docs/bestiary.md: unpriced, noSteal, on no shelf), the Tawny Hide's arrangement: the rule is a
-- trait, and the body wears it on a cell of its grid because blueprint traits do not attach.
--
-- Added 2026-11-19 by the creature identity pass, so the Mere's chaff asks a question of WHERE you fight
-- it: in the channel it is hard to hit, on the bank it is twenty health and a knife.
return {
    name = "Lying Low",
    description = "+25 Avoid while standing in water.",
    flavor = "Two eyes and a ripple. The rest of it is under the silt, and so is the knife.",
    sprite = "assets/items/utility_lying_low.png",
    type = "utility",
    class = "creature",
    tags = { "natural", "water" },
    noSteal = true,
    traits = { "trait_lying_low" },
}
