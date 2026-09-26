-- THE MARCH: the orc War-Drummer's organ (approved as pitched, 2026-09-26, "The Orcs of Wrath"). Every other turn
-- the drum sounds and every orc on its side takes one free step toward its nearest foe; the turn before, it wears
-- Drumbeat (trait_the_march, models/march.lua).
return {
    name = "The March",
    description = "Every other turn the drum sounds, and every orc steps toward its nearest foe.",
    flavor = "Nobody chose to step. The drum chose, and they were already moving.",
    sprite = "assets/items/utility_the_march.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_march" },
}
