    -- SNOWBANK: what comes off a snowdrift slime (data/characters/character_snowdrift_slime.lua). Its Drift's
-- Defense half, worn (trait_snowbank); the Snowslide spends it.
    --
    -- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
    return {
        name = "Snowbank",
        description = "Each turn you end where you began: +2 Defense, up to +6. Moving resets it.",
        flavor = "It settles on anything that stays still long enough.",
        sprite = "assets/items/utility_snowbank.png",
        type = "utility",
        class = "knight",
        unlockLevel = 9,
        unstocked = true,
        tags = { "protective" },
    traits = { "trait_snowbank" },
    }
