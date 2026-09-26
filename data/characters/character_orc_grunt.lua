-- THE ORC GRUNT, rung 1: the orc line's rank and file (approved as pitched, 2026-09-26, "The Orcs of Wrath").
--
-- A heavy chopper, the race and nothing else. Proven needs a plain body to show on: a Grunt with two scars is a
-- different threat from a fresh one without a single extra rule. It is also the Blood Ring's crowd -- the Pit-
-- Fighter's trait sits the Grunts he brings on the ring's edge -- and the Veterans open the fight already scarred.
--
-- The fighter table and no discipline (the kobold round's finding: a lighter table lags the enemy scaling at
-- depth; the vanguard it was pitched as descends from knight and rogue, not fighter). It drops Orc Scars, the
-- race's rule in a player's hand.
return {
    name = "Orc Grunt",
    race = "orc",
    tier = 1,
    class = "fighter",
    sprite = "assets/chars/orc_grunt.png",
    archetype = "aggressive",
    stats = {
        health = 28, mana = 0, stamina = 18,
        staminaRegen = 3,
        damage = 8, magicDamage = 0, -- 9 after the race
        defense = 3, magicDefense = 1, -- 4 after the race
        movement = 4,
        speed = 3,
        skill = 4, luck = 3,
    },
    startingItems = {
        "weapon_iron_axe", "ability_shieldbreak", false,
        false,             false,                 false,
        false,             false,                 false,
    },
    drops = { "utility_orc_scars" },
    defaultAction = "weapon_iron_axe",
    signatureWeapon = "weapon_iron_axe",
}
