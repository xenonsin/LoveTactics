-- THE NIO: the bond between the gate pair (character_asura_agyo, character_asura_ungyo). When one falls, the
-- other takes every point of chi the fallen was holding (trait_the_nio) -- and a pool that fills, bursts.
return {
    name = "The Gate Pair",
    description = "When your twin falls, take all of its chi.",
    flavor = "One mouth open, one closed. Between them, every sound there is.",
    sprite = "assets/items/utility_nio.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_nio" },
}
