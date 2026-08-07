-- Herbalist exemplar (hunter x alchemist multiclass). Field brewing: convert field hazards / plants
-- into consumables mid-fight, to heal or to poison. Met as a field-apothecary, a recruit. Home shelf
-- is hunter. Kit from data/disciplines/herbalist.lua.
return {
    name = "Herbalist",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/herbalist.png",
    class = "hunter",
    discipline = "herbalist",
    -- Harvests the field, brews, and heals or poisons from it (models/ai.lua `support`).
    archetype = "support",
    stats = {
        health = 66, mana = 45, stamina = 16,
        staminaRegen = 2,
        damage = 12, magicDamage = 10,
        defense = 7, magicDefense = 8,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_iron_bow",      "ability_field_brew", "ability_distil",
        "consumable_wildcraft_poultice", "consumable_bitterroot_draught", "utility_cullers_kit",
        "consumable_healing_potion", false,          false,
    },
    defaultAction = "weapon_iron_bow",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_iron_bow",
    signatureAbility = "ability_field_brew",
    -- Heal the most wounded ally with a poultice before anything else.
    ai = {
        { priority = "urgent", act = "support", item = "consumable_wildcraft_poultice", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.6 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
