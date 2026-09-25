-- DRAGONBLOOD: what a dragon IS, granted by its race (data/races/dragon.lua) and set in every Dragon Egg's
-- grid. It carries the one rule the kobolds' whole faith hangs on (trait_dragonkin): the kobolds who see
-- this body struck are driven to Fervor, and the ones who see it destroyed are Forsaken. Bound and
-- unstealable -- an organ, not kit.
return {
    name = "Dragonblood",
    description = "Kobolds who see you struck are driven to Fervor; kobolds who see you destroyed are Forsaken.",
    flavor = "Every kobold can smell it. Most of them would call it the only thing worth smelling.",
    sprite = "assets/items/utility_dragonblood.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_dragonkin" },
}
