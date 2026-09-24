-- What a FROST SLIME is (data/characters/character_frost_slime.lua): proof against steel, adapting, and Numb.
return {
    name = "Frost Body",
    description = "Voids blades, points and blows. Takes on elements. Its blows inflict Numbed.",
    flavor = "It was here before you arrived and it intends to be here after.",
    sprite = "assets/items/frost_body.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    immune = { physical = true, slash = true, pierce = true, impact = true },
    traits = { "trait_adaptive", "trait_numb" },
}
