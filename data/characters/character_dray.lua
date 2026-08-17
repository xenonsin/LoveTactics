-- Dray, the Vanguard the Hiring Hall offers. A version of the vanguard exemplar
-- (data/characters/character_vanguard.lua, the shieldbreaker turncoat), which stays put.
--
-- The Wedge (data/items/utility/utility_the_wedge.lua) drives a lane and leaves everything in it open.
-- Breaker's Wedge is the engine under it -- with that charm carried every shove Sunders, and Sunder is
-- rare enough (five things in the catalog) that the charm is what makes the discipline exist.
return {
    name = "Dray",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/dray.png",
    class = "knight",
    discipline = "vanguard",
    archetype = "aggressive",
    stats = {
        health = 118, mana = 15, stamina = 22,
        staminaRegen = 2,
        damage = 22, magicDamage = 4,
        defense = 13, magicDefense = 7,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_mace",   "ability_shieldbreak",  "ability_pry_open",
        "utility_breakers_wedge", "utility_the_wedge", "utility_stripped_plate",
        "armor_breakers_harness", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_mace",
    signatureWeapon  = "weapon_iron_mace",
    signatureAbility = "utility_the_wedge",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
