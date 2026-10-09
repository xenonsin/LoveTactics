-- HOMEWARD: the wisp's organ (data/characters/character_archon_wisp.lua). Bound and unstealable: it is what the
-- wisp is for. See data/traits/trait_homeward.lua.
return {
    name = "Homeward",
    description = "Walks back to the body it tore loose from. Ending a turn beside it raises the body at half health.",
    flavor = "It knows the way. It has only ever had the one.",
    sprite = "assets/items/utility_wisp_homeward.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_homeward" },
}
