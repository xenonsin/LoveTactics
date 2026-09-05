-- The chorister's call, and the vessel Lure rides in.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Chorister's Call",
    description = "Charms a foe as it acts, then goes on cooldown.",
    flavor = "It is not singing to you. You are simply standing where the song is.",
    sprite = "assets/items/chorister_call.png",
    type = "utility",
    class = "creature",
    dropTier = 3,
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_lure" },
}
