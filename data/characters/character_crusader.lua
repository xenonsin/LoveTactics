-- Crusader exemplar (fighter x priest multiclass). Smite: holy melee against demon/undead, healing on
-- the kill; Zeal banks on any kill or nearby heal. Met as a holy-blade zealot, mentor/boss. Home shelf
-- is fighter for its steel, priest for the smite. Kit from data/disciplines/crusader.lua.
return {
    name = "Crusader",
    sprite = "assets/chars/knight.png",
    class = "fighter",
    -- Smites the unclean and wades in; heal-on-kill keeps it standing (models/ai.lua `aggressive`).
    archetype = "aggressive",
    stats = {
        health = 106, mana = 40, stamina = 20,
        staminaRegen = 2,
        damage = 20, magicDamage = 10,
        defense = 12, magicDefense = 9,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_demon_bane",    "ability_smite",          "ability_zealous_charge",
        "ability_reckoning",    "utility_vow_of_the_march", "armor_crusaders_tabard",
        "consumable_healing_potion", false,               false,
    },
    defaultAction = "ability_smite",
    -- Bring the smite down on the foe closest to falling; Zeal banks on the kill.
    ai = {
        { priority = "high", act = "attack", item = "ability_smite", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.6 } },
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
