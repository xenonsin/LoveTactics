-- Mira, the Druid the Hiring Hall offers. A version of the druid exemplar
-- (data/characters/character_druid.lua, the wild shapeshifter), which stays where it is.
--
-- The Borrowed Pelt (data/items/utility/utility_borrowed_pelt.lua) gates on shapes she has already
-- taken, so the three Wild Shapes in her grid are the build rather than the prize -- and what they open
-- is a fourth body nothing on any shelf can grant (data/characters/character_wild_wyrm.lua).
return {
    name = "Mira",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/mira.png",
    class = "hunter",
    discipline = "druid",
    archetype = "aggressive",
    stats = {
        health = 96, mana = 15, stamina = 18,
        staminaRegen = 2,
        damage = 16, magicDamage = 3,
        defense = 9, magicDefense = 8,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_iron_bow",       "ability_wild_shape_bear", "ability_wild_shape_wolf",
        "ability_wild_shape_raven", "utility_borrowed_pelt", "ability_thicketing",
        "armor_stalkers_pelt",   "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_bow",
    signatureWeapon  = "weapon_iron_bow",
    signatureAbility = "utility_borrowed_pelt",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
