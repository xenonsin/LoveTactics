-- Corin, the Warden the Hiring Hall offers. A version of the warden exemplar
-- (data/characters/character_warden.lua, the march-warden), which stays put.
--
-- The Bound Mile (data/items/utility/utility_bound_mile.lua) makes the hold permanent, and its census
-- counts bodies already held -- so Warding Line and The Grasping Hollow are the gate. A warden who has
-- laid nothing cannot press it, and the moment the holds lapse it shuts again.
return {
    name = "Corin",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/corin.png",
    class = "knight",
    discipline = "warden",
    archetype = "defensive",
    stats = {
        health = 102, mana = 15, stamina = 18,
        staminaRegen = 2,
        damage = 16, magicDamage = 4,
        defense = 14, magicDefense = 9,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_spear",   "ability_warding_line", "ability_grasping_hollow",
        "ability_beat_the_bounds", "utility_bound_mile", "utility_wardens_writ",
        "utility_marchstone",  "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_spear",
    signatureWeapon  = "weapon_iron_spear",
    signatureAbility = "utility_bound_mile",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
