-- THE ORC WAR-DRUMMER, rung 2: the whole line steps at once (approved as pitched, 2026-09-26, "The Orcs of Wrath").
--
-- The March (utility_the_march): every other turn the drum sounds and every orc takes one free step toward its
-- nearest foe; it wears Drumbeat the turn before, so the beat can be read. Step back on a drum turn and the step
-- lands them short; set a trap where they will step; or kill the Drummer.
--
-- A WARLORD on the fighter table, carrying War Drums. It drops Marching Drum.
return {
    name = "Orc War-Drummer",
    race = "orc",
    tier = 2,
    class = "fighter",
    discipline = "warlord",
    sprite = "assets/chars/orc_war_drummer.png",
    archetype = "support",
    stats = {
        health = 48, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 8, magicDamage = 0,
        defense = 4, magicDefense = 3,
        movement = 4,
        speed = 3,
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_iron_mace", "utility_the_march", "consumable_war_drums",
        false,              false,               false,
        false,              false,               false,
    },
    drops = { "ability_marching_drum" },
    defaultAction = "weapon_iron_mace",
    signatureWeapon = "weapon_iron_mace",
}
