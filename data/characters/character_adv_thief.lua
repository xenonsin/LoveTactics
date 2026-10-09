-- THE ADVENTURER THIEF ("The Rift's Adventurers", approved 2026-10-09; models/adventurers.lua). A
-- race-free body: fielded as `character_adv_thief@<race>`; `race` is only the class's first leaning
-- race, so the bare blueprint loads.
--
-- Larceny from the thief's own shelf: Pickpocket takes an item off the body beside it, Sap takes its
-- Damage as Stolen Strength, and the Cutpurse Knife drains its stamina on every cut. What the shelf does
-- NOT stock is a blow that takes a buff (Stripped Bare's line), so this body steals what it can and the
-- gap is reported rather than filled from somebody else's trophy.
return {
    name = "Thief",
    race = "goblin",
    tier = 2,
    adventurer = true,
    class = "rogue",
    discipline = "thief",
    sprite = "assets/chars/thief.png",
    archetype = "skirmish",
    stats = {
        health = 55, mana = 8, stamina = 24,
        staminaRegen = 2,
        damage = 14, magicDamage = 3,
        defense = 5, magicDefense = 5,
        movement = 4,
        speed = 5,
        skill = 8, luck = 8,
    },
    startingItems = {
        "weapon_cutpurse_knife", "ability_pickpocket", "ability_sap",
        "ability_shakedown", "utility_cutpurse_tally", "armor_leather_armor",
        "consumable_healing_potion",
    },
    defaultAction = "weapon_cutpurse_knife",
    signatureWeapon = "weapon_cutpurse_knife",
    signatureAbility = "ability_pickpocket",
    ai = {
        { priority = "high", act = "attack", item = "ability_pickpocket",
          when = { subject = "any_foe", test = "within", value = 1 } },
        { priority = "high", act = "attack", item = "ability_sap",
          when = { subject = "any_foe", test = "lacks_status", value = "status_sapped" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
