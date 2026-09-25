-- THE GODLING'S HUNGER: the Godling's machinery (data/characters/character_the_godling.lua), carried as
-- creature kit -- a boss's rule, not for sale.
--
--   THE TITHE        a kobold that ends its turn beside it gives itself up: heal, and a stack of Glut
--                    (+2 Damage, +2 Defense, no cap) -- trait_the_tithe
--   THE BARE PATCH   a critical hit strips every stack of Glut at once -- trait_bare_patch
--
-- Bound and unstealable: a rogue lifting this off it mid-fight would lift the whole fight.
return {
    name = "The Godling's Hunger",
    description = "A kobold that ends its turn beside you gives itself up: heal, and gain Glut. A critical hit strips all your Glut.",
    flavor = "They named it a god. It has never once corrected them, and it has never once been full.",
    sprite = "assets/items/utility_godlings_hunger.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_tithe", "trait_bare_patch" },
}
