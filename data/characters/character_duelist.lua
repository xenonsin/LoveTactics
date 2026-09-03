-- Duelist exemplar (fighter x rogue multiclass). Duel stance: a bonus that escalates while locked
-- 1v1 with one foe. Met as a swaggering blade-for-hire, a recruit. Home shelf is rogue (Main-Gauche),
-- and it grows both parents. Kit from data/classes/duelist.lua.
return {
    name = "Duelist",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/duelist.png",
    class = "rogue",
    discipline = "duelist",
    -- Picks one foe and stays on it; the duel bonus rewards never letting go (models/ai.lua).
    archetype = "aggressive",
    stats = {
        health = 66, mana = 8, stamina = 22,
        staminaRegen = 2,
        damage = 18, magicDamage = 4,
        defense = 7, magicDefense = 5,
        movement = 4,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 7, luck = 7,
    },
    startingItems = {
        "weapon_main_gauche", "ability_en_garde",       "ability_coup_droit",
        "utility_reading_the_blade", "utility_duelists_poise", "armor_leather_armor",
        "consumable_healing_potion", "weapon_long_bout",             false,
    },
    defaultAction = "weapon_main_gauche",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_main_gauche",
    signatureAbility = "ability_en_garde",
    -- Lock onto the nearest foe and escalate; the duel stance does the rest.
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
