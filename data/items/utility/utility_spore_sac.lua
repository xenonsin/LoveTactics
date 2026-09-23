-- What a Puffer IS: a sac of spores with a cap on. The rule is Spore Burst
-- (data/traits/trait_spore_burst.lua) -- killed, it goes off where it stands. Bound, like the Bomblet's
-- Volatile Core: the fuse over the charge, and the charge is the body.
return {
    name = "Spore Sac",
    description = "On death: bursts, dealing poison and Swoon to everything beside it.",
    flavor = "Whatever you hit it with, you are going to be standing next to afterwards.",
    sprite = "assets/items/spore_sac.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    traits = { "trait_spore_burst" },
}
