-- Sentinel exemplar (knight subclass). Intercept: redirect adjacent allies' incoming hits onto
-- yourself. Met as a mentor -- the Knight in Grey shows this discipline in its unlock quest, but that
-- body (character_grey_knight) is a deliberately minimal, story-disguised encounter unit, so the
-- discipline exemplar is authored here with the full Sentinel kit. Kit from data/disciplines/sentinel.lua.
return {
    name = "Sentinel",
    sprite = "assets/chars/knight.png",
    class = "knight",
    -- Stands between the foe and the wounded ally; holds until the fight comes (models/ai.lua `defensive`).
    archetype = "defensive",
    stats = {
        health = 100, mana = 20, stamina = 16,
        staminaRegen = 2,
        damage = 14, magicDamage = 4,
        defense = 15, magicDefense = 9,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_sword",   "ability_shared_burden", "ability_single_combat",
        "ability_straw_sentry", "utility_lent_aegis",   "utility_unyielding_seal",
        "armor_bulwark_shield", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_sword",
    -- Take the wounded ally's burden onto itself before anything else.
    ai = {
        { priority = "urgent", act = "support", item = "ability_shared_burden", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.6 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
