-- What a Mandrake IS rather than what it swings: the scream it comes up with. The rule is The Shriek
-- (data/traits/trait_mandrake_shriek.lua) -- on death, a Stun on every body within two tiles, both sides.
-- Bound, like the Bomblet's Volatile Core, because it is the body and not a thing the body carries.
return {
    name = "Mandrake Scream",
    description = "On death: Stuns everything within 2 tiles.",
    flavor = "The herbals say to tie a dog to it and walk away. Nobody in the keep owns a dog.",
    sprite = "assets/items/mandrake_scream.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    traits = { "trait_mandrake_shriek" },
}
