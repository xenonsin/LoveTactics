-- Spellbreaker exemplar (knight x mage multiclass). Counterspell: interrupt channels, negate the next
-- nearby cast, burn mana. Met as an anti-mage sword-oath, a boss. Home shelf is knight (Silencing
-- Blade). Kit from data/disciplines/spellbreaker.lua.
return {
    name = "Spellbreaker",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/spellbreaker.png",
    boss = true,
    class = "knight",
    discipline = "spellbreaker",
    -- Hunts the caster; holds a leash and punishes the cast (models/ai.lua `guard`).
    archetype = "guard",
    stats = {
        health = 108, mana = 40, stamina = 18,
        staminaRegen = 2,
        damage = 18, magicDamage = 8,
        defense = 14, magicDefense = 12,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_silencing_blade", "ability_mana_sunder", "ability_null_field",
        "utility_dampening_oath", "utility_spell_eater", "utility_empty_vessel",
        "armor_chainmail",       "consumable_healing_potion", false,
    },
    defaultAction = "weapon_silencing_blade",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_silencing_blade",
    signatureAbility = "ability_mana_sunder",
    -- Sunder the mana of any caster it can close on.
    ai = {
        { priority = "high", act = "attack", item = "ability_mana_sunder",
          when = { subject = "any_foe", test = "within", value = 2 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
