-- LOOSENED LACES: one of the Velvet Queen's own (data/characters/character_velvet_queen.lua). Her
-- presence, worn: every foe within two tiles of you has -2 Defense (trait_loosened_laces) -- the one
-- piece of hers that helps the whole company hit.
--
-- `unstocked`: visible on the Cathedral's rack and never sold (docs/drops.md).
return {
    name = "Loosened Laces",
    description = "Foes within 2 tiles of you have -2 Defense.",
    flavor = "Nobody remembers undoing them.",
    sprite = "assets/items/utility_loosened_laces.png",
    type = "utility",
    tags = { "offensive" },
    class = "priest",
    unlockLevel = 4,
    unstocked = true,
    traits = { "trait_loosened_laces" },
}
