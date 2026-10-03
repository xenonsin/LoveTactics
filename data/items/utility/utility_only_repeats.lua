-- ONLY REPEATS: the Echo's own (data/characters/character_echo.lua; "Envy's Bestiary", 2026-10-03, slice C). A foe
-- casts an ability within 3 of her, and she repeats its blow at half power, from her own tile, at the caster
-- (trait_only_repeats).
return {
    name = "Only Repeats",
    description = "When a foe within 3 casts an ability, repeat its blow at the caster at half power.",
    flavor = "She has nothing to say. She will say it back to you anyway.",
    sprite = "assets/items/utility_only_repeats.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_only_repeats" },
}
