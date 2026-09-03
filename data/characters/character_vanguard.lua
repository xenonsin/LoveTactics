-- Vanguard exemplar (knight x rogue multiclass). Breach: knockback that strips guard / armor, opening
-- the line. Met as a shieldbreaker turncoat, a boss. Home shelf is knight. Kit from
-- data/disciplines/vanguard.lua.
return {
    name = "Vanguard",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/vanguard.png",
    boss = true,
    class = "knight",
    discipline = "vanguard",
    -- Shatters guard first, then pours through the gap (models/ai.lua `aggressive`).
    archetype = "aggressive",
    stats = {
        health = 118, mana = 10, stamina = 22,
        staminaRegen = 2,
        damage = 22, magicDamage = 4,
        defense = 13, magicDefense = 7,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 5, luck = 2,
    },
    startingItems = {
        "weapon_mailpiercer",  "ability_shieldbreak", "ability_pry_open",
        "utility_breakers_wedge", "utility_stripped_plate", "armor_breakers_harness",
        "consumable_healing_potion", "utility_the_wedge",          false,
    },
    defaultAction = "weapon_mailpiercer",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_mailpiercer",
    signatureAbility = "ability_shieldbreak",
    -- Break the guard of whatever it can reach, then pour through.
    ai = {
        { priority = "high", act = "attack", item = "ability_shieldbreak",
          when = { subject = "any_foe", test = "within", value = 1 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
