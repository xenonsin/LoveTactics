-- THOUSAND WINGS: the Thousand-Winged's organ (character_thousand_winged) -- its wings (`flying`) and its death
-- (trait_scatter): struck to 0, half the bats in it fly out again. Wrath's vampires, round 3.
return {
    name = "Thousand Wings",
    description = "Flies. Struck to 0, it comes apart: half the bats in it fly out again, and the rest are dead.",
    flavor = "It has no heart to find. It has a great many small ones, and they disagree about where to go.",
    sprite = "assets/items/utility_thousand_wings.png",
    type = "utility",
    tags = { "natural", "flying" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_scatter" },
}
