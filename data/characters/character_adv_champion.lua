-- ADVENTURER: the race-free Champion a party fields ("The Rift's Adventurers", 2026-10-09). Fielded as
-- `character_adv_champion@<race>` (models/adventurers.lua); `race` below is only the class's first
-- leaning race, so the base blueprint loads. On the fighter table, as the exemplar is; the fighter
-- template leaned toward the knight's armour.
--
-- HE IS BUILT TO BE ATTACKED (the Bait, Open the Line, Bottom of the Cup). He walks up and Provokes
-- whoever is not already taunted onto him, and Reprisal strikes back at every foe beside him each time
-- one of them bites. He is not built to win alone, which is why the page says to ignore him.
return {
    name = "Champion",
    race = "orc",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/champion.png",
    class = "fighter",
    discipline = "champion",
    archetype = "aggressive",
    stats = {
        health = 78, mana = 5, stamina = 25,
        staminaRegen = 2,
        damage = 16, magicDamage = 3,
        defense = 11, magicDefense = 6,
        movement = 4,
        speed = 3,
        skill = 5, luck = 3,
    },
    startingItems = {
        "weapon_iron_axe",  "ability_provoke",  "ability_defiant_stand",
        "utility_reprisal", "armor_leather_armor", "consumable_healing_potion",
    },
    defaultAction = "weapon_iron_axe",
    signatureWeapon  = "weapon_iron_axe",
    signatureAbility = "ability_provoke",
    ai = {
        { priority = "high", act = "cast", item = "ability_provoke",
          when = { subject = "nearest_foe", test = "lacks_status", value = "status_taunt" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
