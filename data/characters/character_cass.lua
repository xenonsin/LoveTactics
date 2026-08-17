-- Cass, the Mammonite the Hiring Hall offers. A version of the mammonite exemplar
-- (data/characters/character_mammonite.lua, the Collections Contractor), which stays where it is.
--
-- With Interest (data/items/utility/utility_with_interest.lua) does not refund: the coin is gone, and
-- the blow is what it bought. So the grid is the spenders -- the earners are what let her keep
-- affording to fill it, and the decision is which of the two the turn goes on.
return {
    name = "Cass",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/cass.png",
    class = "rogue",
    discipline = "mammonite",
    archetype = "skirmish",
    stats = {
        health = 105, mana = 8, stamina = 26,
        staminaRegen = 2,
        damage = 12, magicDamage = 3,
        defense = 10, magicDefense = 8,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_iron_dagger",   "ability_gilded_wound", "ability_blood_money",
        "ability_grease_palms", "utility_with_interest", "ability_price_on_the_head",
        "armor_cutpurse_coat",  "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon  = "weapon_iron_dagger",
    signatureAbility = "utility_with_interest",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
