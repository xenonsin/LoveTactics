-- Warden exemplar (knight x hunter multiclass). Lockdown zone: mark an area; entrants are Rooted /
-- Halted. Met as a march-warden, a mentor. Home shelf is knight. Kit from data/disciplines/warden.lua.
return {
    name = "March-Warden",
    sprite = "assets/chars/warden.png",
    class = "knight",
    -- Lays the ground down, then denies it (models/ai.lua `defensive`).
    archetype = "defensive",
    stats = {
        health = 102, mana = 25, stamina = 18,
        staminaRegen = 2,
        damage = 16, magicDamage = 6,
        defense = 14, magicDefense = 9,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_spear",   "ability_march_wardens_standard", "ability_warding_line",
        "ability_beat_the_bounds", "utility_wardens_writ", "utility_marchstone",
        "armor_chainmail",     "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_spear",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_iron_spear",
    signatureAbility = "ability_warding_line",
    -- Lay a warding line across the ground a foe is crossing.
    ai = {
        { priority = "high", act = "cast", item = "ability_warding_line",
          when = { subject = "any_foe", test = "within", value = 4 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
