-- DEAF HEART: one of the Lorelei's own (data/characters/character_lorelei.lua). Her Only Voice as a
-- presence: every foe within two tiles of the bearer cannot be healed, and no buff or cleanse from its
-- own side reaches it (trait_deaf_heart, read through Status.deafToAllies). The answer to the Tidecaller,
-- the Alraune's heal-steal and every enemy priest -- worn by whoever walks into their line.
--
-- `unstocked`: visible on the Cathedral's rack and never sold (docs/drops.md).
return {
    name = "Deaf Heart",
    description = "Foes within 2 tiles of you cannot be healed, buffed or cleansed by their allies.",
    flavor = "She sang to it for a hundred years. It stopped listening to anything else.",
    sprite = "assets/items/utility_deaf_heart.png",
    type = "utility",
    tags = { "offensive" },
    class = "priest",
    unlockLevel = 4,
    unstocked = true,
    traits = { "trait_deaf_heart" },
}
