-- Sunho, the Monk the Hiring Hall offers. A version of the monk exemplar
-- (data/characters/character_monk.lua, the fist-and-litany ascetic), which stays put.
--
-- The Unheld Hand (data/items/utility/utility_unheld_hand.lua) is the POOL rather than another way to
-- spend it: it refills the chi that Flurry and Asura Strike run on, so the relic is what those two are
-- bought for. He carries no weapon on purpose -- the four fist charms are the weapon.
return {
    name = "Sunho",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/sunho.png",
    class = "priest",
    discipline = "monk",
    archetype = "aggressive",
    stats = {
        health = 96, mana = 70, stamina = 20,
        staminaRegen = 2,
        damage = 14, magicDamage = 12,
        defense = 9, magicDefense = 10,
        movement = 4,
        speed = 5,
    },
    startingItems = {
        "utility_iron_fist",  "ability_flurry",       "utility_swift_fist",
        "utility_drunken_fist", "utility_unheld_hand", "ability_asura_strike",
        "utility_shadow_fist", "consumable_healing_potion", false,
    },
    defaultAction = "ability_flurry",
    signatureAbility = "utility_unheld_hand",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
