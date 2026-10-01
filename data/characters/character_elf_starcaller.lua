-- THE ELF STARCALLER, rung 1: the elves' mage (approved 2026-09-30, "Pride's Bestiary"): BY STARLIGHT.
--
-- Reworked 2026-10-01. It was Born to the Height, hung on the spire's Exposure, which the arena places with no owner
-- and so does nothing to anyone. Now it brings its own light: Starlight lays Witchlight around a foe, and By
-- Starlight (utility_by_starlight) strikes a Limned foe for 3 more and casts a tile further out while any foe is
-- Limned -- on top of Unblemished's own +4 and tile. Step out of the light, or kill the one that lights it.
--
-- It drops the Skywalker's Sandals. On the mage table.
return {
    name = "Elf Starcaller",
    race = "elf",
    tier = 2,
    class = "mage",
    sprite = "assets/chars/elf_starcaller.png",
    archetype = "skirmish",
    stats = {
        health = 36, mana = 36, stamina = 12,
        staminaRegen = 2, manaRegen = 3,
        damage = 3, magicDamage = 7,
        defense = 1, magicDefense = 5,
        movement = 4,
        speed = 3,
        skill = 3, luck = 4,
    },
    startingItems = {
        "weapon_wand",          "ability_ice_bolt", "ability_starlight",
        "utility_by_starlight", false,              false,
        false,                        false,              false,
    },
    drops = { "armor_skywalkers_sandals" },
    defaultAction = "weapon_wand",
    signatureWeapon = "weapon_wand",
}
