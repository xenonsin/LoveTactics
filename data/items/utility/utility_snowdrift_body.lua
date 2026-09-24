-- What a SNOWDRIFT SLIME is (data/characters/character_snowdrift_slime.lua): proof against steel, adapting, and Drift.
return {
    name = "Snowdrift Body",
    description = "Voids blades, points and blows. Takes on elements. It gains Drift while it holds still.",
    flavor = "It was here before you arrived and it intends to be here after.",
    sprite = "assets/items/snowdrift_body.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    immune = { physical = true, slash = true, pierce = true, impact = true },
    traits = { "trait_adaptive", "trait_drift" },
}
