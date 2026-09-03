-- Theurge exemplar (mage x priest multiclass). Channelled miracle: wind-up holy spells that scale with
-- the turns channelled. Met as a channelling divine, a mentor. Home shelf is mage. Kit from
-- data/classes/theurge.lua.
return {
    name = "Theurge",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/theurge.png",
    class = "mage",
    discipline = "theurge",
    -- Channels behind the line; the longer the wind-up, the greater the miracle (models/ai.lua `support`).
    archetype = "support",
    stats = {
        health = 80, mana = 90, stamina = 10,
        staminaRegen = 1,
        damage = 5, magicDamage = 17,
        defense = 6, magicDefense = 12,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 4, luck = 4,
    },
    startingItems = {
        "weapon_litany_staff", "ability_invocation",   "ability_benediction",
        "ability_the_long_prayer", "utility_vigil_beads", "armor_silk_robes",
        "consumable_healing_potion", "utility_unbroken_vigil",            false,
    },
    defaultAction = "weapon_litany_staff",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_litany_staff",
    signatureAbility = "ability_invocation",
    -- Burst a channelled heal over the party when someone drops; otherwise open a divine channel.
    ai = {
        { priority = "urgent", act = "support", item = "ability_benediction", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.6 } },
        { priority = "high", act = "cast", item = "ability_invocation",
          when = { subject = "any_foe", test = "within", value = 5 } },
    },
}
