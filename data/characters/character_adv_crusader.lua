-- ADVENTURER: the race-free Crusader a party fields ("The Rift's Adventurers", 2026-10-09). Fielded as
-- `character_adv_crusader@<race>` (models/adventurers.lua); `race` below is only the class's first
-- leaning race, so the base blueprint loads. On the fighter table, as the exemplar is; the fighter
-- template with a point more armour.
--
-- HE HEALS ON EVERY KILL (Field Dressing, the Purge, the Shieldwall). The Tabard heals him on a kill and
-- banks Zeal; Reckoning spends the Zeal and heals whoever stands beside him. So he hunts the body
-- closest to falling. No Smite: it is paid in mana, and the fighter's pool is five.
return {
    name = "Crusader",
    race = "human",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/crusader.png",
    class = "fighter",
    discipline = "crusader",
    archetype = "aggressive",
    stats = {
        health = 74, mana = 5, stamina = 25,
        staminaRegen = 2,
        damage = 18, magicDamage = 3,
        defense = 10, magicDefense = 6,
        movement = 4,
        speed = 3,
        skill = 5, luck = 3,
    },
    startingItems = {
        "weapon_iron_axe",        "utility_dawn_chrism", "armor_crusaders_tabard",
        "ability_zealous_charge", "ability_reckoning",   "consumable_healing_potion",
    },
    defaultAction = "weapon_iron_axe",
    signatureWeapon  = "weapon_iron_axe",
    signatureAbility = "ability_zealous_charge",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.4 } },
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
