-- THE BATH: the Blood Countess's organ (trait_the_bath, models/basin.lua).
return {
    name = "The Bath",
    description = "When the basin fills, bathe next turn: heal to full, +2 Speed and +20% Damage. Stacks twice.",
    flavor = "She has kept her face for three hundred years. The price is paid by whoever is standing closest.",
    sprite = "assets/items/utility_the_bath.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_bath" },
}
