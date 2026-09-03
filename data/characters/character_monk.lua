-- Monk exemplar (priest subclass). Chi: unarmed strikes bank a charge spent on a burst. Met as a
-- fist-and-litany ascetic, a mentor. No weapon -- it fights bare-handed (that IS the discipline); the
-- fist charms scale the punches and chi feeds Flurry and Asura Strike. Kit from
-- data/disciplines/monk.lua.
return {
    name = "Monk",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/monk.png",
    class = "priest",
    discipline = "monk",
    -- Punches to build chi, then dumps it on a burst; walks straight in (models/ai.lua `aggressive`).
    archetype = "aggressive",
    stats = {
        health = 96, mana = 30, stamina = 20,
        staminaRegen = 2,
        damage = 14, magicDamage = 8,
        defense = 9, magicDefense = 10,
        movement = 4,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 5, luck = 6,
    },
    startingItems = {
        "utility_iron_fist",   "ability_flurry",     "utility_swift_fist",
        "utility_drunken_fist", "ability_asura_strike", "utility_shadow_fist",
        "armor_leather_armor", "consumable_healing_potion", "utility_unheld_hand",
    },
    defaultAction = "ability_flurry",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "utility_iron_fist",
    signatureAbility = "ability_flurry",
    -- Dump chi on Asura Strike against the wounded; otherwise Flurry whatever is adjacent.
    ai = {
        { priority = "urgent", act = "attack", item = "ability_asura_strike", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.4 } },
        { priority = "high", act = "attack", item = "ability_flurry",
          when = { subject = "any_foe", test = "within", value = 1 } },
    },
}
