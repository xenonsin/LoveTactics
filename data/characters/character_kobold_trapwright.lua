-- THE KOBOLD TRAPWRIGHT, rung 1: the line's trap-maker. Approved as a body in round 1 (2026-09-24); its
-- trap changed in round 2 ("Change the trap itself") from the Tripline to the DEADFALL
-- (ability_deadfall): a rigged 3x3 that a foe springs by stepping in, and that lands a turn later. It rigs
-- the ground near itself early, and every planner -- its own included -- walks round the rig after.
--
-- A TRAPPER (hunter root). Drops the Deadfall. Brittle by its own line, as every kobold is.
return {
    name = "Kobold Trapwright",
    race = "kobold",
    tier = 1,
    class = "hunter",
    discipline = "trapper",
    sprite = "assets/chars/kobold_trapwright.png",
    archetype = "skirmish",
    stats = {
        health = 22, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 7, magicDamage = 0,
        defense = 1, magicDefense = 2,
        movement = 4, -- 5 after the race
        speed = 4,    -- 5 after the race
        skill = 6, luck = 5,
    },
    startingItems = {
        "weapon_iron_dagger", "ability_deadfall", false,
        false,                false,              false,
        false,                false,              false,
    },
    drops = { "ability_deadfall" },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon = "weapon_iron_dagger",
    ai = {
        -- Rig the ground first, while the company is still walking in.
        { priority = "high", act = "cast", item = "ability_deadfall",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
