-- Bombardier exemplar (alchemist subclass). Scatter bombs: thrown consumables that seed hazards and
-- chain-detonate. Met as a counterfeit-bomb runner, a boss. Kit from data/disciplines/bombardier.lua.
return {
    name = "Bombardier",
    sprite = "assets/chars/bombardier.png",
    boss = true,
    class = "alchemist",
    -- Lobs into clusters and keeps clear of the blast (models/ai.lua `skirmish`).
    archetype = "skirmish",
    stats = {
        health = 86, mana = 40, stamina = 18,
        staminaRegen = 2,
        damage = 8, magicDamage = 14,
        defense = 6, magicDefense = 9,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_vitriol_wand", "ability_powder_keg",  "ability_blast_charge",
        "ability_held_reaction", "consumable_acid_bomb", "consumable_ice_bomb",
        "consumable_lightning_bomb", "consumable_healing_potion", false,
    },
    defaultAction = "ability_blast_charge",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_vitriol_wand",
    signatureAbility = "ability_blast_charge",
    -- Lob the keg into a cluster of two or more; otherwise a single blast charge.
    ai = {
        { priority = "high", act = "cast", item = "ability_powder_keg",
          when = { subject = "any_foe", test = "count_at_least", value = 2 } },
        { priority = "normal", act = "attack", item = "ability_blast_charge", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
