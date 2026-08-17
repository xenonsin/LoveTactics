-- Garan, the Battlemage the Hiring Hall offers. A version of the battlemage exemplar
-- (data/characters/character_battlemage.lua, the spell-and-steel veteran), which stays put.
--
-- The Folded Word (data/items/utility/utility_folded_word.lua) puts the working into the swing for three
-- blows. Battle Casting is the loop underneath it -- a physical blow hands mana back, so the swings pay
-- for the cast that reloads the relic.
return {
    name = "Garan",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/garan.png",
    class = "mage",
    discipline = "battlemage",
    archetype = "aggressive",
    stats = {
        health = 104, mana = 80, stamina = 18,
        staminaRegen = 2,
        damage = 18, magicDamage = 18,
        defense = 10, magicDefense = 10,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_sword",  "ability_arcane_cleave", "utility_battle_casting",
        "utility_resonant_grip", "utility_folded_word", "utility_spellstrike",
        "armor_chainmail",    "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_sword",
    signatureWeapon  = "weapon_iron_sword",
    signatureAbility = "utility_folded_word",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
