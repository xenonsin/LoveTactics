-- THE WAR OGRE, rung 3: the orcs' beast on a chain (approved as pitched, 2026-09-26, "The Orcs of Wrath"). Built on
-- the reference 2x2 body (character_ogre, which stays the footprint fixture the specs use) and fielded at last.
--
-- The Chain (utility_the_chain): while its Beast-Handler lives it stays within 3 and attacks what the Handler
-- strikes; with the Handler dead it is Unchained, +50% Damage, and attacks the nearest body each turn, orc or not.
-- A beast, so no class and no shelf; it drops nothing.
return {
    name = "War Ogre",
    race = "beast",
    tier = 3,
    sprite = "assets/chars/war_ogre.png",
    footprint = { w = 2, h = 2 },
    archetype = "aggressive",
    stats = {
        health = 136, mana = 0, stamina = 16,
        staminaRegen = 2,
        damage = 18, magicDamage = 0,
        defense = 9, magicDefense = 3,
        movement = 4,
        speed = 1,
        skill = 4, luck = 5,
    },
    -- The ogre's own hide (character_ogre): four tiles of animal, and a spear is the weapon for a large target.
    resist = { impact = 4, pierce = -4 },
    startingItems = { "weapon_stone_fists", "utility_the_chain" },
}
