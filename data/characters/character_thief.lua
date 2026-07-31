-- Thief exemplar (rogue subclass). Larceny: strikes steal an item, buff, or stat. Met as a guild
-- fence, a recruit/mentor. Kit from data/disciplines/thief.lua.
return {
    name = "Fence",
    sprite = "assets/chars/thief.png",
    class = "rogue",
    -- Hit-and-run: rob before the kill, then slip out of reach (models/ai.lua `skirmish`).
    archetype = "skirmish",
    stats = {
        health = 60, mana = 10, stamina = 22,
        staminaRegen = 2,
        damage = 15, magicDamage = 4,
        defense = 6, magicDefense = 5,
        movement = 4,
        speed = 5,
    },
    startingItems = {
        "weapon_cutpurse_knife", "ability_pickpocket", "ability_sap",
        "ability_shakedown",     "ability_charm",      "utility_cutpurse_tally",
        "armor_leather_armor",   "consumable_healing_potion", false,
    },
    defaultAction = "weapon_cutpurse_knife",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_cutpurse_knife",
    signatureAbility = "ability_pickpocket",
    -- Rob whatever is in reach before finishing it.
    ai = {
        { priority = "high", act = "cast", item = "ability_pickpocket",
          when = { subject = "any_foe", test = "in_reach" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
