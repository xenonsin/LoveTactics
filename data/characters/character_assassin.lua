-- Assassin exemplar (rogue subclass). Blink-execute: teleport to a wounded target, guarantee the
-- finish, return. Met as a killer sent for the player, a boss. Kit from data/disciplines/assassin.lua.
return {
    name = "Assassin",
    sprite = "assets/chars/assassin.png",
    boss = true,
    class = "rogue",
    -- Opens from stealth and darts on the wounded, giving up ground to keep the opening (skirmish).
    archetype = "skirmish",
    stats = {
        health = 92, mana = 12, stamina = 24,
        staminaRegen = 2,
        damage = 21, magicDamage = 4,
        defense = 8, magicDefense = 6,
        movement = 4,
        speed = 6,
    },
    startingItems = {
        "weapon_quietus",      "ability_coup_de_grace", "ability_shadow_strike",
        "ability_stillshade",  "ability_dual_wield",    "utility_greyveil_cloak",
        "armor_leather_armor", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_quietus",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_quietus",
    signatureAbility = "ability_coup_de_grace",
    -- Execute anything under half; otherwise strike from the shadows.
    ai = {
        { priority = "urgent", act = "attack", item = "ability_coup_de_grace", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
