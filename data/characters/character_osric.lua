-- Osric, the Crusader the Hiring Hall offers. A version of the crusader exemplar
-- (data/characters/character_crusader.lua, the holy-blade zealot), which stays put.
--
-- The Marching Vow (data/items/armor/armor_marching_vow.lua) spends Zeal to lay consecrated ground
-- rather than swinging a bigger Smite -- ground that keeps working after the turn it was made in is
-- the thing neither parent shelf does. Vow of the March and the Tabard share the same pool.
return {
    name = "Osric",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/osric.png",
    class = "priest",
    discipline = "crusader",
    archetype = "aggressive",
    stats = {
        health = 106, mana = 70, stamina = 20,
        staminaRegen = 2,
        damage = 20, magicDamage = 12,
        defense = 12, magicDefense = 9,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_sword",  "ability_smite",         "ability_zealous_charge",
        "ability_reckoning",  "armor_marching_vow",    "utility_vow_of_the_march",
        "utility_censer_of_dawn", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_sword",
    signatureWeapon  = "weapon_iron_sword",
    signatureAbility = "armor_marching_vow",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
