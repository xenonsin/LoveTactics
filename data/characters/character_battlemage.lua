-- Battlemage exemplar (fighter x mage multiclass). Spellstrike: a cantrip folded into a melee swing.
-- Met as a spell-and-steel veteran, a boss. Home shelf is mage. Kit from data/disciplines/battlemage.lua.
return {
    name = "Battlemage",
    sprite = "assets/chars/mage.png",
    boss = true,
    class = "mage",
    -- Closes and cleaves; each swing carries the last spell (models/ai.lua `aggressive`).
    archetype = "aggressive",
    stats = {
        health = 104, mana = 55, stamina = 18,
        staminaRegen = 2,
        damage = 18, magicDamage = 16,
        defense = 10, magicDefense = 10,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_emberwand",     "ability_arcane_cleave", "utility_spellstrike",
        "utility_resonant_grip", "utility_arcane_conduit", "utility_battle_casting",
        "armor_silk_robes",     "consumable_healing_potion", false,
    },
    defaultAction = "ability_arcane_cleave",
    -- Close the distance and cleave whatever it reaches.
    ai = {
        { priority = "high", act = "attack", item = "ability_arcane_cleave",
          when = { subject = "any_foe", test = "within", value = 1 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
