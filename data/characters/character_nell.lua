-- Nell, the Exorcist the Hiring Hall offers. A version of the exorcist exemplar
-- (data/characters/character_exorcist.lua), which stays put.
--
-- The Rite Unspoken (data/items/utility/utility_rite_unspoken.lua) is Banish said over an area rather
-- than a body: everything summoned within three tiles goes, and the ground it stood on goes with it.
-- Hers included -- a rite that spared its own conjurings would be a spell.
return {
    name = "Nell",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/nell.png",
    class = "priest",
    discipline = "exorcist",
    archetype = "support",
    stats = {
        health = 82, mana = 70, stamina = 12,
        staminaRegen = 2,
        damage = 5, magicDamage = 12,
        defense = 8, magicDefense = 14,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_censer",       "ability_banish",       "ability_dispel_illusions",
        "ability_silence",     "utility_rite_unspoken", "utility_cleansing_ward",
        "ability_heal",        "consumable_healing_potion", false,
    },
    defaultAction = "ability_heal",
    signatureWeapon  = "weapon_censer",
    signatureAbility = "utility_rite_unspoken",
    ai = {
        { priority = "high", act = "support", item = "ability_heal", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.6 } },
    },
}
