-- Sela, the Trapper the Hiring Hall offers. A version of the trapper exemplar
-- (data/characters/character_trapper_ambusher.lua), which stays where it is as the woodland ambusher.
--
-- The Patient Line (data/items/utility/utility_patient_line.lua) widens every trap she has laid AND
-- every trap she lays afterwards, so pressing it early is correct. The grid is nothing but ground: the
-- more of it she buys, the bigger the relic, which is the cleanest build-around on the roster.
return {
    name = "Sela",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/sela.png",
    class = "hunter",
    discipline = "trapper",
    archetype = "skirmish",
    stats = {
        health = 84, mana = 15, stamina = 16,
        staminaRegen = 2,
        damage = 13, magicDamage = 3,
        defense = 7, magicDefense = 5,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_iron_bow",     "ability_bear_trap",    "ability_snare_stake",
        "ability_blightstake", "utility_patient_line", "utility_trap_sense",
        "utility_caltrop_greaves", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_bow",
    signatureWeapon  = "weapon_iron_bow",
    signatureAbility = "utility_patient_line",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
