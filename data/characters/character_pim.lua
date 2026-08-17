-- Pim, the Thief the Hiring Hall offers. A version of the thief exemplar
-- (data/characters/character_thief.lua, the guild fence), which stays where it is.
--
-- The Bag of Holding (data/items/utility/utility_bag_of_holding.lua) is why she is worth hiring: a
-- theft used to leave the fight for the stash, and now it lands somewhere she can reach this turn.
-- The grid is the taking -- Pickpocket, Shakedown, Sap to stop the robbed answering.
return {
    name = "Pim",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/pim.png",
    class = "rogue",
    discipline = "thief",
    archetype = "skirmish",
    stats = {
        health = 88, mana = 8, stamina = 22,
        staminaRegen = 2,
        damage = 15, magicDamage = 3,
        defense = 7, magicDefense = 5,
        movement = 4,
        speed = 5,
    },
    startingItems = {
        "weapon_cutpurse_knife", "ability_pickpocket", "ability_shakedown",
        "ability_sap",           "utility_bag_of_holding", "utility_cutpurse_tally",
        "armor_leather_armor",   "consumable_healing_potion", false,
    },
    defaultAction = "weapon_cutpurse_knife",
    signatureWeapon  = "weapon_cutpurse_knife",
    signatureAbility = "utility_bag_of_holding",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
