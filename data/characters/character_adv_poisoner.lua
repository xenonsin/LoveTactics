-- ADVENTURER: the race-free Poisoner a party fields ("The Rift's Adventurers", 2026-10-09). Fielded as
-- `character_adv_poisoner@<race>` (models/adventurers.lua); `race` below is only the class's first
-- leaning race, so the base blueprint loads. The alchemist template, with a little more behind the
-- blade it fights with.
--
-- THE COATED BLADE WEARS ONE OF YOURS DOWN (the Contract, the Contagion, Green Hands). Envenom and the
-- Crawler Mucus sit on either side of the lancet in the grid, so every cut Poisons and Roots. She
-- closes rather than kites: a coating is only worth anything on a blade that lands.
return {
    name = "Poisoner",
    race = "goblin",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/poisoner.png",
    class = "alchemist",
    discipline = "poisoner",
    archetype = "aggressive",
    stats = {
        health = 54, mana = 45, stamina = 16,
        staminaRegen = 1,
        damage = 9, magicDamage = 12,
        defense = 6, magicDefense = 9,
        movement = 4,
        speed = 4,
        skill = 7, luck = 3,
    },
    startingItems = {
        "weapon_apothecarys_lancet", "consumable_envenom",     "armor_leather_armor",
        "consumable_crawler_mucus",  "utility_spiteful_ichor", "consumable_healing_potion",
    },
    defaultAction = "weapon_apothecarys_lancet",
    signatureWeapon  = "weapon_apothecarys_lancet",
    signatureAbility = "consumable_envenom",
    ai = {
        { priority = "high", act = "attack", item = "weapon_apothecarys_lancet", targetPref = "nearest",
          when = { subject = "any_foe", test = "lacks_status", value = "status_poison" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
