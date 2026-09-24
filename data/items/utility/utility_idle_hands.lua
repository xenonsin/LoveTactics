    -- IDLE HANDS: what comes off a frost slime (data/characters/character_frost_slime.lua). Its Numb, turned
-- inside out (trait_idle_hands).
    --
    -- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
    return {
        name = "Idle Hands",
        description = "The first thing you use each battle costs nothing.",
        flavor = "It did not do anything. That was the trick.",
        sprite = "assets/items/utility_idle_hands.png",
        type = "utility",
        class = "knight",
        unlockLevel = 9,
        unstocked = true,
        tags = { "utility" },
    traits = { "trait_idle_hands" },
    }
