    -- What the GLACIER KING is (data/characters/character_glacier_king.lua): all three of Sloth's rules on
-- one body -- a doubled Torpor shove, Numb and Drift -- and it comes apart into one of each slime.
    return {
        name = "Glacier Heart",
        description = "Voids blades, points and blows. Torpor, Numb and Drift; divides into one of each Sloth slime.",
        flavor = "Everything that stopped here is still in it somewhere.",
        sprite = "assets/items/glacier_heart.png",
        type = "utility",
        class = "creature",
        tags = { "relic" },
        bound = true,
        noSteal = true, -- a creature's body is not loot
        immune = { physical = true, slash = true, pierce = true, impact = true },
        traits = { "trait_adaptive", "trait_torpid_touch", "trait_numb", "trait_drift", "trait_split" },
    traitParams = { shove = 6, spawns = { "character_rime_slime", "character_frost_slime", "character_snowdrift_slime" }, health = 26 },
    }
