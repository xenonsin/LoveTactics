-- Poisoner exemplar (alchemist subclass). Coatings: depleting weapon infusions applied between swings.
-- Met as a vat-master, a boss. Kit from data/disciplines/poisoner.lua.
return {
    name = "Poisoner",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/poisoner.png",
    boss = true,
    class = "alchemist",
    discipline = "poisoner",
    -- Coats the blade, then knifes from a kept distance (models/ai.lua `skirmish`).
    archetype = "skirmish",
    stats = {
        health = 90, mana = 45, stamina = 18,
        staminaRegen = 2,
        damage = 15, magicDamage = 12,
        defense = 7, magicDefense = 9,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_envenomed_kris", "consumable_envenom",  "consumable_crawler_mucus",
        "consumable_thinblood_rime", "utility_miasma_flask", "utility_spiteful_ichor",
        "armor_leather_armor",   "consumable_healing_potion", false,
    },
    defaultAction = "weapon_envenomed_kris",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_envenomed_kris",
    signatureAbility = "consumable_envenom",
    -- Knife whatever is in reach; the coatings do the rest as the poison stacks.
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
