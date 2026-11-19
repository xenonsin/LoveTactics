-- What the GLACIER KING is (data/characters/character_glacier_king.lua): Sloth's slimes in one body -- a doubled
-- Torpor shove on its blows, Frostbite on whoever strikes it from beside it, and Drift while it holds still --
-- and it comes apart into one of each slime.
--
-- Numb came off it in the creature identity pass (2026-11-19), with the Frost Slime's move to Frostbite. Torpor
-- stays here alone: the King is the one body that still carries it, which is also what the Unhurried Coat
-- (the Rime Slime's trophy) is for.
return {
    name = "Glacier Heart",
    description = "Voids blades, points and blows. Its blows make you Torpid; a blow on it from beside Freezes you. Gains Drift.",
    flavor = "Everything that stopped here is still in it somewhere.",
    sprite = "assets/items/glacier_heart.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    immune = { physical = true, slash = true, pierce = true, impact = true },
    traits = { "trait_adaptive", "trait_torpid_touch", "trait_frostbite", "trait_drift", "trait_split" },
    traitParams = { shove = 6, spawns = { "character_rime_slime", "character_frost_slime", "character_snowdrift_slime" }, health = 26 },
}
