-- THE WYRMLING, rung 1: what a Dragon Egg hatches (trait_clutch), and in the Clutch and the Nest sometimes
-- what is already standing there ("Can have already hatched in the encounter", round-1 note). A bite and a
-- short breath on a cooldown. A DRAGON (data/races/dragon.lua), so the kobolds within 3 of it fight under
-- the Dragon's Eye, a blow it survives rallies them, and killing it breaks them. It is not a kobold, so it
-- carries none of their rules; the Godling is what one grows into.
--
-- THE HIDE is the dragon's, on the body because the bestiary reads it off the blueprint: a blade and a
-- club turn, and a point finds the bare patch (+1 slash, +1 impact, -2 pierce). Fire comes off the race.
return {
    name = "Wyrmling",
    race = "dragon",
    tier = 1,
    sprite = "assets/chars/wyrmling.png",
    archetype = "aggressive",
    stats = {
        health = 26, mana = 0, stamina = 18,
        staminaRegen = 3,
        damage = 10, magicDamage = 6,
        defense = 3, magicDefense = 3,
        movement = 4,
        speed = 4,
        skill = 5, luck = 5,
    },
    resist = { slash = 1, impact = 1, pierce = -2 },
    startingItems = {
        "weapon_fangs", "ability_kindling_breath", false,
        false,          false,                     false,
        false,          false,                     false,
    },
    drops = {},
    defaultAction = "weapon_fangs",
    signatureWeapon = "weapon_fangs",
    ai = {
        { priority = "high", act = "attack", item = "ability_kindling_breath",
          when = { subject = "nearest_foe", test = "within", value = 2 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
