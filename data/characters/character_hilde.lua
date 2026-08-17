-- Hilde, the Warbrewer the Hiring Hall offers. A version of the warbrewer exemplar
-- (data/characters/character_warbrewer.lua, the berserker-draught brawler), which stays put.
--
-- Last Call (data/items/utility/utility_last_call.lua) banks what she DRANK rather than what she did,
-- which is why the tally exists at all -- the two diverge the moment she swings. Field Still brews one
-- into her grid every turn, so waiting is accumulating.
return {
    name = "Hilde",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/hilde.png",
    class = "alchemist",
    discipline = "warbrewer",
    archetype = "aggressive",
    stats = {
        health = 120, mana = 45, stamina = 24,
        staminaRegen = 2,
        damage = 22, magicDamage = 12,
        defense = 11, magicDefense = 7,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_axe",      "consumable_berserkers_brew", "consumable_battle_tonic",
        "utility_field_still",  "utility_last_call",          "utility_brawlers_bandolier",
        "utility_round_for_the_house", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_axe",
    signatureWeapon  = "weapon_iron_axe",
    signatureAbility = "utility_last_call",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
