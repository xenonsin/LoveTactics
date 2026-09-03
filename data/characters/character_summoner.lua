-- Summoner exemplar (mage subclass). Reserve court: bank mana to field independent elementals. Met as
-- a conjurer with an elemental court, a boss. Kit from data/classes/summoner.lua.
return {
    name = "Summoner",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/summoner.png",
    boss = true,
    class = "mage",
    discipline = "summoner",
    -- Hangs back and keeps an elemental court on the board (models/ai.lua `skirmish`).
    archetype = "skirmish",
    stats = {
        health = 84, mana = 100, stamina = 10,
        staminaRegen = 1,
        damage = 5, magicDamage = 19,
        defense = 5, magicDefense = 12,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 7, luck = 4,
    },
    startingItems = {
        "weapon_staff",                  "ability_summon_earth_elemental", "ability_summon_ice_elemental",
        "ability_summon_lightning_elemental", "ability_summon_water_elemental", "ability_summon_wind_elemental",
        "ability_doppelganger",          "utility_mana_wellspring",        "utility_court_kept_waiting",
    },
    defaultAction = "weapon_staff",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_staff",
    signatureAbility = "ability_summon_lightning_elemental",
    -- Keep a court fielded; call a fresh elemental whenever a foe is on the board.
    ai = {
        { priority = "high", act = "cast", item = "ability_summon_lightning_elemental",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "normal", act = "attack", item = "weapon_staff", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
