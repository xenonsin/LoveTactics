    -- What a CRYSTAL SLIME is (data/characters/character_crystal_slime.lua): Pride's slime -- proof against
-- steel, adapting, and RANKED (trait_rank).
    return {
        name = "Crystal Body",
        description = "Voids blades, points and blows. Takes on elements. Warded while a lower-ranked crystal stands.",
        flavor = "It knows exactly where it stands, and where you do.",
        sprite = "assets/items/crystal_body.png",
        type = "utility",
        class = "creature",
        tags = { "relic" },
        bound = true,
        noSteal = true, -- a creature's body is not loot
        immune = { physical = true, slash = true, pierce = true, impact = true },
        traits = { "trait_adaptive", "trait_rank" },
    }
