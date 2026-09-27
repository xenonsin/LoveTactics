-- THE BLOOD BASIN: the basin's organ (trait_blood_basin). Every point of Bleed damage taken anywhere fills it.
return {
    name = "Blood Basin",
    description = "Fills with every point of Bleed damage taken anywhere. When it is full, the Countess bathes in it.",
    flavor = "Stone, deep enough to lie down in, and never quite dry.",
    sprite = "assets/items/utility_blood_basin.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_blood_basin" },
}
