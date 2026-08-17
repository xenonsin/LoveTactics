-- Elio, the Duelist the Hiring Hall offers. A version of the duelist exemplar
-- (data/characters/character_duelist.lua, the swaggering blade-for-hire), which stays put.
--
-- The Long Bout (data/items/weapon/weapon_long_bout.lua) is the roster's ONE weapon relic, and it never
-- gates: the streak is a readout, the blade always swings. En Garde and Reading the Blade bank the same
-- repeatStrike, and Coup Droit competes for it -- which is the decision his whole build is.
return {
    name = "Elio",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/elio.png",
    class = "fighter",
    discipline = "duelist",
    archetype = "aggressive",
    stats = {
        health = 88, mana = 5, stamina = 22,
        staminaRegen = 2,
        damage = 18, magicDamage = 3,
        defense = 7, magicDefense = 5,
        movement = 4,
        speed = 5,
    },
    startingItems = {
        "weapon_long_bout",  "ability_en_garde",      "ability_coup_droit",
        "weapon_main_gauche", "utility_duelists_poise", "utility_reading_the_blade",
        "armor_leather_armor", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_long_bout",
    signatureWeapon  = "weapon_long_bout",
    signatureAbility = "utility_duelists_poise",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
