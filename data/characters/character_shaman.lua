-- Shaman exemplar (hunter x mage multiclass). Spirit totems: summoned spirits bound to hazards. Met as
-- a spirit-caller, a mentor. Home shelf is hunter. Kit from data/disciplines/shaman.lua.
return {
    name = "Shaman",
    sprite = "assets/chars/shaman.png",
    class = "hunter",
    -- Calls spirits, binds them to hazards, and drives them in from a kept distance (skirmish).
    archetype = "skirmish",
    stats = {
        health = 88, mana = 50, stamina = 16,
        staminaRegen = 2,
        damage = 14, magicDamage = 14,
        defense = 8, magicDefense = 10,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_iron_bow",      "ability_call_spirit", "ability_bind_spirit",
        "utility_spirit_fetish", "utility_ancestor_mask", "utility_ghost_wind",
        "consumable_healing_potion", false,           false,
    },
    defaultAction = "weapon_iron_bow",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_iron_bow",
    signatureAbility = "ability_call_spirit",
    -- Keep a spirit on the board, then shoot from range.
    ai = {
        { priority = "high", act = "cast", item = "ability_call_spirit",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
