-- Cael, the Necromancer the Hiring Hall offers. A version of the necromancer exemplar
-- (data/characters/character_necromancer.lua, the Adept of the inner circle), which stays put.
--
-- The Second Reading (data/items/utility/utility_second_reading.lua) spends the undead he raised to
-- bring back one of the living -- so Raise Dead and Early Rites stop being rivals for the same corpses
-- and become the only things that mint what the relic costs.
return {
    name = "Cael",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/cael.png",
    class = "mage",
    discipline = "necromancer",
    archetype = "skirmish",
    stats = {
        health = 82, mana = 80, stamina = 10,
        staminaRegen = 1,
        damage = 5, magicDamage = 18,
        defense = 5, magicDefense = 12,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_the_unreturning", "ability_raise_dead",   "ability_early_rites",
        "ability_knell",          "utility_second_reading", "ability_sever_the_thread",
        "utility_charnel_reliquary", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_the_unreturning",
    signatureWeapon  = "weapon_the_unreturning",
    signatureAbility = "utility_second_reading",
    ai = {
        { priority = "high", act = "cast", item = "ability_raise_dead",
          when = { subject = "any_foe", test = "exists" } },
    },
}
