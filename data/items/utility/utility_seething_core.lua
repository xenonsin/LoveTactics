    -- SEETHING CORE: what comes off a cinder slime (data/characters/character_cinder_slime.lua). Its Boil
-- Over worn without the eruption (trait_seething_core).
    --
    -- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
    return {
        name = "Seething Core",
        description = "When you're hit, +1 Damage for the fight, up to +5.",
        flavor = "Still warm. It will be warm for a long time.",
        sprite = "assets/items/utility_seething_core.png",
        type = "utility",
        class = "fighter",
        unlockLevel = 7,
        unstocked = true,
        tags = { "offensive" },
    traits = { "trait_seething_core" },
    }
