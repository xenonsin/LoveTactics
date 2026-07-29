-- Theurge exemplar (mage x priest multiclass). Channelled miracle: wind-up holy spells that scale with
-- the turns channelled. Met as a channelling divine, a mentor. Home shelf is mage. Kit from
-- data/disciplines/theurge.lua.
return {
    name = "Theurge",
    sprite = "assets/chars/priest.png",
    class = "mage",
    -- Channels behind the line; the longer the wind-up, the greater the miracle (models/ai.lua `support`).
    archetype = "support",
    stats = {
        health = 80, mana = 90, stamina = 10,
        staminaRegen = 1,
        damage = 5, magicDamage = 17,
        defense = 6, magicDefense = 12,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_litany_staff", "ability_invocation",   "ability_benediction",
        "ability_the_long_prayer", "utility_vigil_beads", "armor_silk_robes",
        "consumable_healing_potion", false,            false,
    },
    defaultAction = "weapon_litany_staff",
    -- Burst a channelled heal over the party when someone drops; otherwise open a divine channel.
    ai = {
        { priority = "urgent", act = "support", item = "ability_benediction", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.6 } },
        { priority = "high", act = "cast", item = "ability_invocation",
          when = { subject = "any_foe", test = "within", value = 5 } },
    },
}
