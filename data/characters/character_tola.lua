-- Tola, the Beastmaster the Hiring Hall offers. A version of the beastmaster exemplar
-- (data/characters/character_beastmaster.lua), which stays where it is.
--
-- The Second Leash (data/items/utility/utility_second_leash.lua) counts beasts standing, so the grid is
-- how the count gets there and Beastlord's Bond is how it stays. It pays in durability rather than in
-- an extra turn, which is what keeps it off the win-more shape.
return {
    name = "Tola",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/tola.png",
    class = "hunter",
    discipline = "beastmaster",
    archetype = "skirmish",
    stats = {
        health = 90, mana = 15, stamina = 15,
        staminaRegen = 2,
        damage = 15, magicDamage = 3,
        defense = 8, magicDefense = 8,
        movement = 4,
        speed = 5,
    },
    startingItems = {
        "weapon_iron_longbow",  "ability_summon_wolf",  "utility_companion_whistle",
        "utility_hunting_horn", "utility_second_leash", "utility_beastlords_bond",
        "armor_stalkers_pelt",  "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_longbow",
    signatureWeapon  = "weapon_iron_longbow",
    signatureAbility = "utility_second_leash",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
