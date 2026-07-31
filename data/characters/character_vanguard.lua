-- Vanguard exemplar (knight x rogue multiclass). Breach: knockback that strips guard / armor, opening
-- the line. Met as a shieldbreaker turncoat, a boss. Home shelf is knight. Kit from
-- data/disciplines/vanguard.lua.
return {
    name = "Shieldbreaker",
    sprite = "assets/chars/vanguard.png",
    boss = true,
    class = "knight",
    -- Shatters guard first, then pours through the gap (models/ai.lua `aggressive`).
    archetype = "aggressive",
    stats = {
        health = 118, mana = 10, stamina = 22,
        staminaRegen = 2,
        damage = 22, magicDamage = 4,
        defense = 13, magicDefense = 7,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_mailpiercer",  "ability_shieldbreak", "ability_pry_open",
        "utility_breakers_wedge", "utility_stripped_plate", "armor_breakers_harness",
        "consumable_healing_potion", false,          false,
    },
    defaultAction = "weapon_mailpiercer",
    -- Break the guard of whatever it can reach, then pour through.
    ai = {
        { priority = "high", act = "attack", item = "ability_shieldbreak",
          when = { subject = "any_foe", test = "within", value = 1 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
