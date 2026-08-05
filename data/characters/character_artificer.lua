-- Artificer exemplar (mage x alchemist multiclass). Constructs: deploy autonomous sentries / turrets.
-- Met as a sentry-engine builder, a boss/mentor. Home shelf is mage. Kit from
-- data/disciplines/artificer.lua.
return {
    name = "Artificer",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/artificer.png",
    boss = true,
    class = "mage",
    discipline = "artificer",
    -- Deploys turrets, hangs back, and overcharges the line (models/ai.lua `skirmish`).
    archetype = "skirmish",
    stats = {
        health = 88, mana = 70, stamina = 14,
        staminaRegen = 1,
        damage = 8, magicDamage = 16,
        defense = 7, magicDefense = 10,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_wand",           "ability_field_assembly", "ability_emplace_sentry",
        "ability_recall_construct", "ability_overcharge",  "utility_salvage_rig",
        "armor_silk_robes",      "consumable_healing_potion", false,
    },
    defaultAction = "weapon_wand",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_wand",
    signatureAbility = "ability_emplace_sentry",
    -- Emplace a sentry as a foe comes into range, then let it work.
    ai = {
        { priority = "high", act = "cast", item = "ability_emplace_sentry",
          when = { subject = "any_foe", test = "within", value = 6 } },
        { priority = "normal", act = "attack", item = "weapon_wand", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
