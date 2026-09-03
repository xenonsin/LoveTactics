-- Sentinel exemplar (knight subclass). Intercept: redirect adjacent allies' incoming hits onto
-- yourself. Met as a mentor -- the Knight in Grey shows this discipline in its unlock quest, but that
-- body (character_grey_knight) is a deliberately minimal, story-disguised encounter unit, so the
-- discipline exemplar is authored here with the full Sentinel kit. Kit from data/classes/sentinel.lua.
return {
    name = "Sentinel",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/sentinel.png",
    class = "knight",
    discipline = "sentinel",
    -- Stands between the foe and the wounded ally; holds until the fight comes (models/ai.lua `defensive`).
    archetype = "defensive",
    stats = {
        health = 100, mana = 20, stamina = 16,
        staminaRegen = 2,
        damage = 14, magicDamage = 4,
        defense = 15, magicDefense = 9,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 4, luck = 2,
    },
    startingItems = {
        "weapon_iron_sword",   "ability_shared_burden", "ability_single_combat",
        "ability_straw_sentry", "utility_lent_aegis",   "utility_unyielding_seal",
        "armor_bulwark_shield", "consumable_healing_potion", "armor_standing_debt",
    },
    defaultAction = "weapon_iron_sword",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_iron_sword",
    signatureAbility = "ability_shared_burden",
    -- Take the wounded ally's burden onto itself before anything else.
    ai = {
        { priority = "urgent", act = "support", item = "ability_shared_burden", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.6 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
