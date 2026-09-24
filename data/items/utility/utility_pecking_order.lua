    -- PECKING ORDER: what comes off a crystal slime (data/characters/character_crystal_slime.lua). Its Rank,
-- worn (trait_pecking_order).
    --
    -- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
    return {
        name = "Pecking Order",
        description = "+3 Damage against a foe with less health than you.",
        flavor = "Somebody has to be at the bottom. It is simply never you.",
        sprite = "assets/items/utility_pecking_order.png",
        type = "utility",
        class = "mage",
        unlockLevel = 13,
        unstocked = true,
        tags = { "offensive" },
    traits = { "trait_pecking_order" },
    }
