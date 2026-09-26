-- THE GOBLIN CUTTER, rung 1: the goblin line's chaff (approved as pitched, 2026-09-26, "The Goblins of Wrath").
--
-- It chops in melee, and when the Feud is out of reach it THROWS the axe beside its Toss (ability_toss) rather
-- than wait -- then fights bare-handed until it walks over and picks it back up. Distance does not stop it, but
-- the rage costs it the weapon: pull the Feud away and the Cutters throw themselves bare. What it IS comes off
-- the race: Blood Feud, and Mob Courage (data/races/goblin.lua).
--
-- A SKIRMISHER on the fighter table, the kobold round's finding: a lighter table lags the enemy scaling at
-- depth, and Wrath sits at floors seven and eight. Also what a Wolf-Rider becomes when its wolf is cut down.
return {
    name = "Goblin Cutter",
    race = "goblin",
    tier = 1,
    class = "fighter",
    discipline = "skirmisher",
    sprite = "assets/chars/goblin_cutter.png",
    archetype = "aggressive",
    stats = {
        health = 22, mana = 0, stamina = 18,
        staminaRegen = 3,
        damage = 8, magicDamage = 0, -- 9 after the race
        defense = 2, magicDefense = 1,
        movement = 4,
        speed = 4, -- 5 after the race
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_iron_axe", "ability_toss", false,
        false,             false,          false,
        false,             false,          false,
    },
    drops = { "ability_toss" },
    defaultAction = "weapon_iron_axe",
    signatureWeapon = "weapon_iron_axe",
}
