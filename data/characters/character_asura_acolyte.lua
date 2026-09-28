-- ASURA ACOLYTE: the first rung of Wrath's asura (models/asura.lua; "The Asura of Wrath", 2026-09-27/28). Two
-- arms, fists and an Iron Fist, and the broken vow and nothing else -- the body that teaches the rule. Hit it
-- and it fills; leave it and it cools; let it fill and it throws everything at whoever is nearest.
--
-- Imagery: a Thai yak temple guardian, as a novice.
return {
    name = "Asura Acolyte",
    race = "asura",
    tier = 1,
    class = "priest",
    discipline = "monk",
    sprite = "assets/chars/asura_acolyte.png",
    archetype = "aggressive",
    stats = {
        health = 26, mana = 0, stamina = 18,
        staminaRegen = 3,
        damage = 7, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 4,
        speed = 3, -- 4 after the race
        skill = 3, luck = 3, -- 4 after the race
    },
    startingItems = {
        "utility_iron_fist", false, false,
        false,               false, false,
        false,               false, false,
    },
    signatureWeapon = "utility_iron_fist",
}
