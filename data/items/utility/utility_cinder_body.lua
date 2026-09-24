    -- What a CINDER SLIME is (data/characters/character_cinder_slime.lua): Wrath's slime body -- proof
-- against steel, adapting to elements, and it erupts with the element it has taken (trait_boil_over).
    return {
        name = "Cinder Body",
        description = "Voids blades, points and blows. Takes on elements, and erupts with them when it boils over.",
        flavor = "It has been angry for a very long time, and it is not finished.",
        sprite = "assets/items/cinder_body.png",
        type = "utility",
        class = "creature",
        tags = { "relic" },
        bound = true,
        noSteal = true, -- a creature's body is not loot
        immune = { physical = true, slash = true, pierce = true, impact = true },
        traits = { "trait_adaptive", "trait_boil_over" },
    }
