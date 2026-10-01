-- THE LAMP: what the Lamp is (trait_the_lamp). Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- An object's organ, carried so its tooltip says why the company should break it. Bound and unstealable.
return {
    name = "The Lamp",
    description = "While it stands, the Wishmaker's wishes are granted.",
    flavor = "Brass, dented, and older than the spire. It has had a great many owners and outlived all of them.",
    sprite = "assets/items/utility_the_lamp.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_lamp" },
}
