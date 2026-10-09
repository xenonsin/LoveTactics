-- THE BALOR: the Crown's great fire demon, a creature and not a person ("The Crown's Bestiary", slice B, approved
-- 2026-10-09). An elite, and a 2x2 body.
--
--   HELLFIRE RING   a telegraphed wind-up that burns every tile within 2 (ability_hellfire_ring)
--   DEATH THROES    when it dies, it explodes, striking every tile within 3, its own side included
--                   (utility_balor_throes; trait_hellfire_throes)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: step out of the ring when it winds up. Finish it from
-- range, or bring it down in the middle of its own escort. A demon, so its lash burns and it takes holy the harder.
--
-- Tier 4's band is 155 and up (Balance.HEALTH_BANDS), at the bottom of it: its death is half the fight.
return {
    name = "Balor",
    race = "demon",
    tier = 4,
    boss = true, -- off the execute and Charm tables, as every elite is
    sprite = "assets/chars/balor.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 170, mana = 0, stamina = 34,
        staminaRegen = 4,
        damage = 16, magicDamage = 10,
        defense = 8, magicDefense = 6,
        movement = 3,
        speed = 4,
        skill = 5, luck = 3, -- big, and easy to hit
    },
    -- A hide like slag: an arrow sticks and does nothing, a hammer cracks it. Made of fire, and afraid of ice.
    resist = { pierce = 3, impact = -3, fire = 5, ice = -4 },
    startingItems = {
        "weapon_flame_lash", "ability_hellfire_ring", "utility_balor_throes",
        false,               false,                   false,
        false,               false,                   false,
    },
    drops = { "utility_last_breath" },
    defaultAction = "weapon_flame_lash",
    archetype = "aggressive",
}
