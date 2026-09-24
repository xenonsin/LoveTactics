-- What a RIME SLIME is (data/characters/character_rime_slime.lua): proof against steel, adapting, and Torpor.
return {
    name = "Rime Body",
    description = "Voids blades, points and blows. Takes on elements. Its blows make you Torpid.",
    flavor = "It was here before you arrived and it intends to be here after.",
    sprite = "assets/items/rime_body.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    immune = { physical = true, slash = true, pierce = true, impact = true },
    traits = { "trait_adaptive", "trait_torpid_touch" },
}
