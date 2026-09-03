-- Saboteur exemplar (rogue x alchemist multiclass). Planted charges: stealth-place delayed bombs, then
-- detonate on cue. Met as a demolitions ghost, a recruit. Home shelf is rogue. Kit from
-- data/classes/saboteur.lua.
return {
    name = "Saboteur",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/saboteur.png",
    class = "rogue",
    discipline = "saboteur",
    -- Seeds charges from cover, then blows the line at once (models/ai.lua `skirmish`).
    archetype = "skirmish",
    stats = {
        health = 62, mana = 30, stamina = 20,
        staminaRegen = 2,
        damage = 14, magicDamage = 10,
        defense = 6, magicDefense = 7,
        movement = 4,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 7,
    },
    startingItems = {
        "weapon_iron_dagger",  "ability_set_charge", "ability_detonator",
        "ability_ghost_kit",   "ability_bring_it_down", "consumable_sappers_line",
        "consumable_healing_potion", "utility_the_signal",          false,
    },
    defaultAction = "ability_set_charge",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_iron_dagger",
    signatureAbility = "ability_set_charge",
    -- Plant a charge on an approaching foe; the detonator does the rest.
    ai = {
        { priority = "high", act = "cast", item = "ability_set_charge",
          when = { subject = "any_foe", test = "within", value = 5 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
