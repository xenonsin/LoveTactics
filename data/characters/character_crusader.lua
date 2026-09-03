-- Crusader exemplar (fighter x priest multiclass). Smite: holy melee against demon/undead, healing on
-- the kill; Zeal banks on any kill or nearby heal. Met as a holy-blade zealot, mentor/boss. Home shelf
-- is fighter for its steel, priest for the smite. Kit from data/disciplines/crusader.lua.
return {
    name = "Crusader",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/crusader.png",
    class = "fighter",
    discipline = "crusader",
    -- Smites the unclean and wades in; heal-on-kill keeps it standing (models/ai.lua `aggressive`).
    archetype = "aggressive",
    stats = {
        health = 106, mana = 40, stamina = 20,
        staminaRegen = 2,
        damage = 20, magicDamage = 10,
        defense = 12, magicDefense = 9,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 3,
    },
    startingItems = {
        "weapon_demon_bane",    "ability_smite",          "ability_zealous_charge",
        "ability_reckoning",    "utility_vow_of_the_march", "armor_crusaders_tabard",
        "consumable_healing_potion", "armor_marching_vow",               false,
    },
    defaultAction = "ability_smite",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_demon_bane",
    signatureAbility = "ability_smite",
    -- Bring the smite down on the foe closest to falling; Zeal banks on the kill.
    ai = {
        { priority = "high", act = "attack", item = "ability_smite", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.6 } },
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
