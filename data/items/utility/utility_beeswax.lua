-- BEESWAX: one of the Siren's own (data/characters/character_siren.lua), and the oldest answer to her.
-- Wax in the ears: the bearer is proof against Longing, the Only Voice and Charm -- and pays for it in
-- the same coin, because it cannot hear its own side either. No buff from an ally lands on it
-- (the `hearsNothing` flag, read in Status.apply). Heals still land: a hand on the shoulder needs no ears.
--
-- `unstocked`: visible on the Cathedral's rack and never sold (docs/drops.md).
return {
    name = "Beeswax",
    description = "Immune to Longing, the Only Voice and Charm. No buff from an ally lands on you.",
    flavor = "The crew stopped their ears and rowed. Only one of them ever heard the song and lived.",
    sprite = "assets/items/utility_beeswax.png",
    type = "utility",
    tags = { "protective" },
    class = "priest",
    unlockLevel = 3,
    unstocked = true,
    statusImmunity = { "status_longing", "status_the_only_voice", "status_charm" },
    traits = { "trait_beeswax" },
}
