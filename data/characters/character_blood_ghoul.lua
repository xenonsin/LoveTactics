-- THE BLOOD-GHOUL, rung 1: a vampire's thrall (Wrath's vampires, round 1: the ghoul is a PICK, and it came back the
-- LIVING thrall rather than Greed's undead Ghoul). A human fighter kept alive to be drunk from: a vampire beside it
-- may Feed on it (ability_feed) -- its Thirst resets and it heals, and the ghoul takes the wound. When it dies,
-- every living body beside it Bleeds (trait_thrall).
--
-- NOT UNDEAD. That is the whole of it: it has blood, so it is the one body on a vampire's side a vampire can drink
-- from, and the one a vampire in Bloodlust will bite. Kill the ghouls first and the brood goes thirsty; kill them
-- in the middle of your own line and you bleed for it.
return {
    name = "Blood-Ghoul",
    race = "human",
    tier = 1,
    class = "fighter",
    sprite = "assets/chars/blood_ghoul.png",
    archetype = "aggressive",
    stats = {
        health = 26, mana = 0, stamina = 16,
        staminaRegen = 3,
        damage = 8, magicDamage = 0,
        defense = 2, magicDefense = 1,
        movement = 4,
        speed = 3,
        skill = 4, luck = 3,
    },
    startingItems = {
        "weapon_iron_sword", "utility_thrall", false,
        false,               false,            false,
        false,               false,            false,
    },
    drops = { "consumable_vitae" },
    defaultAction = "weapon_iron_sword",
    signatureWeapon = "weapon_iron_sword",
}
