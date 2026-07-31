-- Druid exemplar (hunter subclass). Wildshape: swap the whole kit for a beast form for N turns. Met
-- as a wild shapeshifter, a mentor. Kit from data/disciplines/druid.lua.
return {
    name = "Shapeshifter",
    sprite = "assets/chars/druid.png",
    class = "hunter",
    -- Shifts to bear and wades in, raven to reposition (models/ai.lua `aggressive` once in a form).
    archetype = "aggressive",
    stats = {
        health = 96, mana = 30, stamina = 18,
        staminaRegen = 2,
        damage = 16, magicDamage = 8,
        defense = 9, magicDefense = 8,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_iron_bow",       "ability_wild_shape_bear", "ability_wild_shape_wolf",
        "ability_wild_shape_raven", "ability_thicketing",   "armor_stalkers_pelt",
        "consumable_healing_potion", false,                false,
    },
    defaultAction = "weapon_iron_bow",
    -- Shift to bear when a foe closes, then wade in.
    ai = {
        { priority = "high", act = "cast", item = "ability_wild_shape_bear",
          when = { subject = "any_foe", test = "within", value = 3 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
