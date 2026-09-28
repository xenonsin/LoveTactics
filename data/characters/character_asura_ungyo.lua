-- THE CLOSED MOUTH (UN): the other of the Nio (data/encounters/encounter_wrath_the_nio.lua). It never spends --
-- no Flurry, no Asura Strike -- and it only fills: it answers every blow first (Keen Senses) and its stillness
-- heats it (the Centering Charm's Gather, which its blood turns into chi). When its twin falls it takes all of
-- that twin's chi too (trait_the_nio), and a full pool bursts.
return {
    name = "The Closed Mouth",
    race = "asura",
    tier = 3,
    class = "priest",
    discipline = "monk",
    sprite = "assets/chars/asura_ungyo.png",
    archetype = "defensive",
    stats = {
        health = 124, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 11, magicDamage = 0,
        defense = 8, magicDefense = 6,
        movement = 4,
        speed = 3, -- 4 after the race
        skill = 5, luck = 4,
    },
    startingItems = {
        "utility_six_arms",        "utility_iron_fist",    "ability_keen_senses",
        "utility_centering_charm", "utility_nio",          false,
        false,                     false,                  false,
    },
    signatureWeapon = "utility_iron_fist",
}
