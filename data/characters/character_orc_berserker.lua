-- THE ORC BERSERKER, rung 2: can't stop once it starts (approved as pitched, 2026-09-26, "The Orcs of Wrath").
--
-- Blood Up (utility_blood_up): each turn in a row it lands a hit, +3 Damage; once it has struck it must strike
-- every turn, and with no foe in reach it hits the nearest body, orc included; the first turn it lands nothing it
-- is Spent. The answer is to step out of reach for a turn and let it hit a Grunt or waste itself.
--
-- A BARBARIAN on the fighter table, carrying the barbarian's Bloodlock Bracing -- a passive, so it never spends a
-- turn that would break its own streak. It drops the streak without the compulsion: the Unbroken Axe and Warpaint.
return {
    name = "Orc Berserker",
    race = "orc",
    tier = 2,
    class = "fighter",
    discipline = "barbarian",
    sprite = "assets/chars/orc_berserker.png",
    archetype = "aggressive",
    stats = {
        health = 58, mana = 0, stamina = 26,
        staminaRegen = 4,
        damage = 11, magicDamage = 0,
        defense = 3, magicDefense = 2,
        movement = 4,
        speed = 4,
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_iron_axe", "utility_blood_up", "utility_bloodlock_bracing",
        false,             false,              false,
        false,             false,              false,
    },
    drops = { "weapon_unbroken_axe", "utility_warpaint" },
    defaultAction = "weapon_iron_axe",
    signatureWeapon = "weapon_iron_axe",
}
