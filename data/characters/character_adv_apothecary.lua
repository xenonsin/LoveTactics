-- ADVENTURER: the race-free Apothecary a party fields ("The Rift's Adventurers", 2026-10-09). Fielded as
-- `character_adv_apothecary@<race>` (models/adventurers.lua); `race` below is only the class's first
-- leaning race, so the base blueprint loads. The alchemist template as it stands.
--
-- SHE KEEPS THE BAIT STANDING WITH DOSES (the Bait). Heal on whoever is worst off; Transfusion, paid in
-- her own health, once somebody is close to falling; the Shared Ledger lends her guard to anyone she
-- heals. She is the one sustain body her party is allowed, and the one the page says to kill first.
return {
    name = "Apothecary",
    race = "naga",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/apothecary.png",
    class = "alchemist",
    discipline = "apothecary",
    archetype = "support",
    stats = {
        health = 52, mana = 45, stamina = 14,
        staminaRegen = 1,
        damage = 6, magicDamage = 12,
        defense = 6, magicDefense = 9,
        movement = 4,
        speed = 4,
        skill = 7, luck = 3,
    },
    startingItems = {
        "weapon_apothecarys_lancet", "ability_heal",              "ability_transfusion",
        "utility_shared_ledger",     "consumable_healing_potion", "armor_leather_armor",
    },
    defaultAction = "weapon_apothecarys_lancet",
    signatureWeapon  = "weapon_apothecarys_lancet",
    signatureAbility = "ability_transfusion",
    ai = {
        { priority = "urgent", act = "support", item = "ability_transfusion", targetPref = "most_wounded",
          when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.35 } },
        { priority = "high", act = "support", item = "ability_heal", targetPref = "most_wounded",
          when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.65 } },
    },
}
