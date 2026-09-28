-- THE OPEN MOUTH (A): one of the Nio, the gate pair (data/encounters/encounter_wrath_the_nio.lua). A Three-Faced
-- Asura that spends -- Flurry and Asura Strike -- beside a closed-mouthed twin that only fills. When either
-- falls, the other takes every point of chi it was holding (trait_the_nio), and if that fills it, it bursts at
-- once. Kill the Closed Mouth first and this one spends what it inherits; kill this one first and the Closed
-- Mouth bursts with both gauges.
return {
    name = "The Open Mouth",
    race = "asura",
    tier = 3,
    class = "priest",
    discipline = "monk",
    sprite = "assets/chars/asura_agyo.png",
    archetype = "aggressive",
    stats = {
        health = 112, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 12, magicDamage = 0,
        defense = 6, magicDefense = 6,
        movement = 4,
        speed = 4, -- 5 after the race
        skill = 5, luck = 4,
    },
    startingItems = {
        "utility_six_arms",     "utility_iron_fist", "ability_flurry",
        "ability_asura_strike", "utility_nio",       false,
        false,                  false,               false,
    },
    signatureWeapon = "utility_iron_fist",
    signatureAbility = "ability_asura_strike",
}
