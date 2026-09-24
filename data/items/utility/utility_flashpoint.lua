    -- FLASHPOINT: one of the Caldera King's own (data/characters/character_caldera_king.lua). His
-- shorter fuse, handed to somebody who can aim it (trait_flashpoint).
    --
    -- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
    return {
        name = "Flashpoint",
        description = "Every third time you're hit, your next hit deals +8 Damage.",
        flavor = "One. Two. Three.",
        sprite = "assets/items/utility_flashpoint.png",
        type = "utility",
        class = "fighter",
        unlockLevel = 8,
        unstocked = true,
        tags = { "offensive" },
    traits = { "trait_flashpoint" },
    }
