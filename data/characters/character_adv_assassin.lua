-- ADVENTURER: the race-free Assassin a party fields ("The Rift's Adventurers", 2026-10-09). Fielded as
-- `character_adv_assassin@<race>` (models/adventurers.lua); `race` below is only the class's first
-- leaning race, so the base blueprint loads. The rogue template, a step quicker.
--
-- HE ONLY ACTS ON A WOUNDED BODY (the Contract, the Purge, Hold and Loose). Under a quarter he finishes
-- it with Coup de Grace (the dagger beside it in the grid is what it needs); under half he steps in
-- with Shadow Strike and is back where he started. Nobody under half and he waits, which is the
-- counter the party page names: keep your wounded topped up and he stands idle.
return {
    name = "Assassin",
    race = "oni",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/assassin.png",
    class = "rogue",
    discipline = "assassin",
    archetype = "skirmish",
    stats = {
        health = 56, mana = 8, stamina = 24,
        staminaRegen = 2,
        damage = 16, magicDamage = 3,
        defense = 6, magicDefense = 5,
        movement = 4,
        speed = 6,
        skill = 8, luck = 7,
    },
    startingItems = {
        "weapon_iron_dagger",  "ability_coup_de_grace",     "ability_shadow_strike",
        "ability_shadow_step", "armor_leather_armor",       "consumable_healing_potion",
    },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon  = "weapon_iron_dagger",
    signatureAbility = "ability_coup_de_grace",
    ai = {
        { priority = "urgent", act = "attack", item = "ability_coup_de_grace", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.25 } },
        { priority = "high", act = "attack", item = "ability_shadow_strike", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
        { priority = "normal", act = "wait",
          when = { subject = "foe_lowest_hp", test = "hp_pct_above", value = 0.5 } },
    },
}
