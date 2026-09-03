-- Druid exemplar (hunter subclass). Wildshape: swap the whole kit for a beast form for N turns. Met
-- as a wild shapeshifter, a mentor. Kit from data/disciplines/druid.lua.
return {
    name = "Druid",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/druid.png",
    class = "hunter",
    discipline = "druid",
    -- Shifts to bear and wades in, raven to reposition (models/ai.lua `aggressive` once in a form).
    archetype = "aggressive",
    stats = {
        health = 96, mana = 30, stamina = 18,
        staminaRegen = 2,
        damage = 16, magicDamage = 8,
        defense = 9, magicDefense = 8,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 4,
    },
    startingItems = {
        "weapon_iron_bow",       "ability_wild_shape_bear", "ability_wild_shape_wolf",
        "ability_wild_shape_raven", "ability_thicketing",   "armor_stalkers_pelt",
        "consumable_healing_potion", "utility_borrowed_pelt",                false,
    },
    defaultAction = "weapon_iron_bow",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_iron_bow",
    signatureAbility = "ability_wild_shape_bear",
    -- Shift to bear when a foe closes, then wade in.
    ai = {
        { priority = "high", act = "cast", item = "ability_wild_shape_bear",
          when = { subject = "any_foe", test = "within", value = 3 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
