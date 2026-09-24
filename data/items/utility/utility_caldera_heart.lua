    -- What the CALDERA KING is (data/characters/character_caldera_king.lua): the Cinder Body with a
-- shorter fuse (erupts at 3), and it comes apart into cinder slimes already Seething (trait_split).
    return {
        name = "Caldera Heart",
        description = "Voids blades, points and blows. Boils over at 3 stacks, and divides into Seething pieces.",
        flavor = "It was a mountain once. Most of it still is.",
        sprite = "assets/items/caldera_heart.png",
        type = "utility",
        class = "creature",
        tags = { "relic" },
        bound = true,
        noSteal = true, -- a creature's body is not loot
        immune = { physical = true, slash = true, pierce = true, impact = true },
        traits = { "trait_adaptive", "trait_boil_over", "trait_split" },
    traitParams = { eruptAt = 3, spawn = "character_cinder_slime", pieceStatus = "status_seething", pieceMagnitude = 2, health = 26 },
    }
