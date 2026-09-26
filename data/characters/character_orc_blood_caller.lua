-- THE ORC BLOOD-CALLER, rung 2 (approved as pitched, 2026-09-26, "The Orcs of Wrath"; the heal on Keno's round-2
-- note). The warband's priest, except that what it gives is its own blood: Blood Offering pays 15% of its health to
-- heal an orc within 4 by that much and make it Proven without a kill. Kill it first, or leave it and it bleeds
-- itself down. A shaman on the mage table, as the goblin Hexer is. It drops Blood Offering.
return {
    name = "Orc Blood-Caller",
    race = "orc",
    tier = 2,
    class = "mage",
    discipline = "shaman",
    sprite = "assets/chars/orc_blood_caller.png",
    archetype = "support",
    stats = {
        health = 42, mana = 50, stamina = 10,
        staminaRegen = 2,
        damage = 4, magicDamage = 10,
        defense = 2, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_iron_crook", "ability_blood_offering", false,
        false,               false,                    false,
        false,               false,                    false,
    },
    drops = { "ability_blood_offering" },
    defaultAction = "weapon_iron_crook",
    signatureWeapon = "weapon_iron_crook",
}
