-- Duelist exemplar (fighter x rogue multiclass). Duel stance: a bonus that escalates while locked
-- 1v1 with one foe. Met as a swaggering blade-for-hire, a recruit. Home shelf is rogue (Main-Gauche),
-- and it grows both parents. Kit from data/disciplines/duelist.lua.
return {
    name = "Duelist",
    sprite = "assets/chars/archer.png",
    class = "rogue",
    -- Picks one foe and stays on it; the duel bonus rewards never letting go (models/ai.lua).
    archetype = "aggressive",
    stats = {
        health = 66, mana = 8, stamina = 22,
        staminaRegen = 2,
        damage = 18, magicDamage = 4,
        defense = 7, magicDefense = 5,
        movement = 4,
        speed = 5,
    },
    startingItems = {
        "weapon_main_gauche", "ability_en_garde",       "ability_coup_droit",
        "utility_reading_the_blade", "utility_duelists_poise", "armor_leather_armor",
        "consumable_healing_potion", false,             false,
    },
    defaultAction = "weapon_main_gauche",
    -- Lock onto the nearest foe and escalate; the duel stance does the rest.
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
