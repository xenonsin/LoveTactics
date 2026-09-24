    -- COPYCAT: what comes off a mimic slime (data/characters/character_mimic_slime.lua). Its Mimicry, worn
-- small (trait_copycat).
    --
    -- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
    return {
        name = "Copycat",
        description = "When a foe's weapon hits you, you get a copy of it until you use it.",
        flavor = "It liked yours. So it has one now.",
        sprite = "assets/items/utility_copycat.png",
        type = "utility",
        class = "alchemist",
        unlockLevel = 11,
        unstocked = true,
        tags = { "offensive" },
    traits = { "trait_copycat" },
    }
