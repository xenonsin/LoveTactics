-- Monk exemplar (priest subclass). Chi: unarmed strikes bank a charge spent on a burst. Met as a
-- fist-and-litany ascetic, a mentor. No weapon -- it fights bare-handed (that IS the discipline); the
-- fist charms scale the punches and chi feeds Flurry and Asura Strike. Kit from
-- data/disciplines/monk.lua.
return {
    name = "Ascetic",
    sprite = "assets/chars/priest.png",
    class = "priest",
    -- Punches to build chi, then dumps it on a burst; walks straight in (models/ai.lua `aggressive`).
    archetype = "aggressive",
    stats = {
        health = 96, mana = 30, stamina = 20,
        staminaRegen = 2,
        damage = 14, magicDamage = 8,
        defense = 9, magicDefense = 10,
        movement = 4,
        speed = 5,
    },
    startingItems = {
        "utility_iron_fist",   "ability_flurry",     "utility_swift_fist",
        "utility_drunken_fist", "ability_asura_strike", "utility_shadow_fist",
        "armor_leather_armor", "consumable_healing_potion", false,
    },
    defaultAction = "ability_flurry",
    -- Dump chi on Asura Strike against the wounded; otherwise Flurry whatever is adjacent.
    ai = {
        { priority = "urgent", act = "attack", item = "ability_asura_strike", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.4 } },
        { priority = "high", act = "attack", item = "ability_flurry",
          when = { subject = "any_foe", test = "within", value = 1 } },
    },
}
