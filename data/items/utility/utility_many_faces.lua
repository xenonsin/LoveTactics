    -- What the MANY-FACED KING is (data/characters/character_many_faced_king.lua): the Mimic Body, crowned,
-- and it comes apart into copies of the company that beat it (trait_many_faced).
    return {
        name = "Many Faces",
        description = "Voids blades, points and blows. Mimicry and Begrudge; divides into copies of three foes.",
        flavor = "Everyone who has ever looked at it is in there.",
        sprite = "assets/items/many_faces.png",
        type = "utility",
        class = "creature",
        tags = { "relic" },
        bound = true,
        noSteal = true, -- a creature's body is not loot
        immune = { physical = true, slash = true, pierce = true, impact = true },
        traits = { "trait_adaptive", "trait_mimicry", "trait_begrudge", "trait_many_faced" },
    }
