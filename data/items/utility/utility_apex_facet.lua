    -- What the APEX CRYSTAL is (data/characters/character_apex_crystal.lua): the top of the order, warded
-- until every crystal beneath it has fallen, and it comes apart into a new order (trait_split).
    return {
        name = "Apex Facet",
        description = "Voids blades, points and blows. Warded while any crystal beneath it stands; divides into crystal slimes.",
        flavor = "It has never once looked down.",
        sprite = "assets/items/apex_facet.png",
        type = "utility",
        class = "creature",
        tags = { "relic" },
        bound = true,
        noSteal = true, -- a creature's body is not loot
        immune = { physical = true, slash = true, pierce = true, impact = true },
        traits = { "trait_adaptive", "trait_rank_top", "trait_split" },
    traitParams = { spawn = "character_crystal_slime", health = 26 },
    }
