-- THE CHAINS BREAK: the Titan's second organ (data/characters/character_titan.lua; trait_the_chains_break). Below
-- half health, the +2 movement that undoes the Gods' Chains and +4 damage. Bound and unstealable.
return {
    name = "The Chains Break",
    description = "Below half health: +2 movement and +4 damage.",
    flavor = "Every blow you land is a link it does not have to break itself.",
    sprite = "assets/items/utility_the_chains_break.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_chains_break" },
}
