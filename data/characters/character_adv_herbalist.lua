-- HERBALIST, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A
-- race-free body fielded as `character_adv_herbalist@<race>`; `race` names the first leaning race only so
-- the blueprint loads. Built on the generic archer (the hunter root the exemplar walks): 15 / 3 magic.
--
-- WHAT IT DOES ON THE BOARD (Green Hands, The Contagion): it takes the hazards off the ground -- a
-- bombardier's craters, a plague knight's poison -- and Distils them into reagents, which heal and cleanse
-- whoever it hands one to. Distil on bare ground does nothing, and the planner drops a cast that does
-- nothing, so the harvest happens only where the party has laid something to harvest. Field Brew is its
-- ground heal; there is no Field Still, whose reagent a turn would be a heal on a loop.
return {
    name = "Herbalist",
    race = "naga",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/herbalist.png",
    class = "hunter",
    discipline = "herbalist",
    archetype = "support",
    stats = {
        health = 52, mana = 15, stamina = 22,
        staminaRegen = 2,
        damage = 14, magicDamage = 3,
        defense = 4, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 8, luck = 4,
    },
    startingItems = {
        "weapon_iron_bow", "ability_distil", "ability_field_brew",
        "consumable_wildcraft_poultice", "utility_cullers_kit",
    },
    defaultAction = "weapon_iron_bow",
    signatureWeapon  = "weapon_iron_bow",
    signatureAbility = "ability_distil",
    -- 1. A poultice for an ally going down. 2. Harvest a hazard when there is one. 3. Shoot the wounded.
    ai = {
        { priority = "urgent", act = "support", item = "consumable_wildcraft_poultice", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.4 } },
        { priority = "high", act = "cast", item = "ability_distil",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
