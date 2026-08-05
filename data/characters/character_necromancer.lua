-- Necromancer exemplar (mage subclass). Corpse-raise: the slain rise as your undead; corpses feed
-- Corpse Burst. Met as an Adept of the inner circle, a boss. Kit from data/disciplines/necromancer.lua.
return {
    name = "Necromancer",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/necromancer.png",
    boss = true,
    class = "mage",
    discipline = "necromancer",
    -- Hangs back, raises the fallen, and spends corpses (models/ai.lua `skirmish`).
    archetype = "skirmish",
    stats = {
        health = 82, mana = 95, stamina = 10,
        staminaRegen = 1,
        damage = 5, magicDamage = 18,
        defense = 5, magicDefense = 12,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_the_unreturning", "ability_raise_dead",    "ability_corpse_burst",
        "ability_knell",          "ability_sever_the_thread", "ability_veil_of_night",
        "utility_charnel_reliquary", "armor_silk_robes",   "consumable_healing_potion",
    },
    defaultAction = "weapon_the_unreturning",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_the_unreturning",
    signatureAbility = "ability_raise_dead",
    -- Toll the Knell on a nearby foe; raising the dead is the payoff.
    ai = {
        { priority = "high", act = "cast", item = "ability_knell",
          when = { subject = "any_foe", test = "within", value = 6 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
