-- THE ORC BEAST-HANDLER, rung 2: it holds the War Ogre's chain (approved as pitched, 2026-09-26, "The Orcs of
-- Wrath"). Whatever it strikes, the ogre goes for next, and it Goads the ogre into acting again at once. Kill it and
-- the ogre is Unchained, striking whoever is nearest -- the company decides where that happens
-- (utility_holding_the_chain, character_war_ogre). A beastmaster on the hunter table. It drops Goad.
return {
    name = "Orc Beast-Handler",
    race = "orc",
    tier = 2,
    class = "hunter",
    discipline = "beastmaster",
    sprite = "assets/chars/orc_beast_handler.png",
    archetype = "skirmish",
    stats = {
        health = 46, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 9, magicDamage = 0,
        defense = 4, magicDefense = 2,
        movement = 4,
        speed = 4,
        skill = 6, luck = 4,
    },
    startingItems = {
        "weapon_iron_spear", "ability_goad", "utility_holding_the_chain",
        false,               false,          false,
        false,               false,          false,
    },
    drops = { "ability_goad" },
    defaultAction = "weapon_iron_spear",
    signatureWeapon = "weapon_iron_spear",
}
