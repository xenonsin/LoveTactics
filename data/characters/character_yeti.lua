-- YETI: the thing in the whiteout, on the tundra's approach ("Sloth's Bestiary", slice A, 2026-10-04).
--
--   WHITEOUT ROAR   at the start of its turn it roars: each foe within 4 with no ally beside it is Rooted, frozen
--                   with fear (utility_whiteout_roar, trait_whiteout_roar; models/sloth_beasts.lua)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: move in pairs.
--
-- A thick pelt over a heavy frame: a club sinks in, a point goes through to something.
return {
    name = "Yeti",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/yeti.png",
    stats = {
        health = 56, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 11, magicDamage = 0,
        defense = 5, magicDefense = 4,
        movement = 4,
        speed = 4,
        skill = 5, luck = 3,
    },
    resist = { impact = 2, pierce = -2 },
    startingItems = {
        "weapon_yeti_claws", "utility_whiteout_roar", false,
        false,               false,                   false,
        false,               false,                   false,
    },
    drops = { "armor_yeti_hide_mantle" },
    defaultAction = "weapon_yeti_claws",
    archetype = "aggressive",
}
