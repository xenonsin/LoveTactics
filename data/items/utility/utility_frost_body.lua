-- What a FROST SLIME is (data/characters/character_frost_slime.lua): proof against steel, adapting, and
-- Frostbite -- a foe beside it whose blow lands is Frozen (trait_frostbite). It laid Numb until the creature
-- identity pass (2026-11-19); Numb lives on in the Heavy Lids.
return {
    name = "Frost Body",
    description = "Voids blades, points and blows. Takes on elements. A foe beside it whose blow lands on it is Frozen.",
    flavor = "It was here before you arrived and it intends to be here after.",
    sprite = "assets/items/frost_body.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    immune = { physical = true, slash = true, pierce = true, impact = true },
    traits = { "trait_adaptive", "trait_frostbite" },
}
