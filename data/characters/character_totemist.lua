-- Totemist exemplar (hunter x priest multiclass). Ward totems: planted totems projecting holy heal /
-- negate zones. Met as a ward-carver, a mentor. Home shelf is hunter. Kit from
-- data/disciplines/totemist.lua.
return {
    name = "Totemist",
    sprite = "assets/chars/totemist.png",
    class = "hunter",
    -- Raises totems and holds the ground they bless (models/ai.lua `support`).
    archetype = "support",
    stats = {
        health = 84, mana = 55, stamina = 15,
        staminaRegen = 2,
        damage = 12, magicDamage = 12,
        defense = 8, magicDefense = 11,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_iron_bow",      "ability_raise_totem", "ability_totem_of_mending",
        "ability_ley_line",     "ability_carved_stake", "utility_totem_carvers_kit",
        "consumable_healing_potion", false,           false,
    },
    defaultAction = "ability_totem_of_mending",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_iron_bow",
    signatureAbility = "ability_raise_totem",
    -- Raise a mending totem the moment an ally is hurt.
    ai = {
        { priority = "urgent", act = "support", item = "ability_totem_of_mending", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.7 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
