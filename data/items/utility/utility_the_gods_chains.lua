-- THE GODS' CHAINS: the Titan's first organ (data/characters/character_titan.lua). A rebel still in the chains it
-- was put in: -2 movement on a body of 3, so it crawls a tile a turn until The Chains Break gives the two back.
-- Bound and unstealable.
return {
    name = "The Gods' Chains",
    description = "Movement -2.",
    flavor = "Forged to hold it forever. Forever has been longer than the iron.",
    sprite = "assets/items/utility_the_gods_chains.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    bonus = { movement = -2 },
}
