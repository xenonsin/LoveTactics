-- MOULT: the Larder Mother's half-health turn (trait_moult). What it hands over is the Castoff Coat.
return {
    name = "Moult",
    description = "Once, at half health: sheds every harmful status and steps aside, leaving a husk behind.",
    flavor = "The thing you have been cutting at is empty. She is standing next to it.",
    sprite = "assets/items/utility_moult.png",
    type = "utility",
    class = "creature",
    tags = { "beast" },
    noSteal = true,
    traits = { "trait_moult" },
}
