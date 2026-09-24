    -- What a MIMIC SLIME is (data/characters/character_mimic_slime.lua): Envy's slime -- proof against steel,
-- adapting, and both halves of Envy: it becomes you (trait_mimicry) and it wants what you get (trait_begrudge).
    return {
        name = "Mimic Body",
        description = "Voids blades, points and blows. Becomes the first foe to target it, and gains every blessing its foes gain.",
        flavor = "It has always wanted to be somebody. It is not fussy about whom.",
        sprite = "assets/items/mimic_body.png",
        type = "utility",
        class = "creature",
        tags = { "relic" },
        bound = true,
        noSteal = true, -- a creature's body is not loot
        immune = { physical = true, slash = true, pierce = true, impact = true },
        traits = { "trait_adaptive", "trait_mimicry", "trait_begrudge" },
    }
