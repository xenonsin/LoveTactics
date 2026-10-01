-- THE ELF STARCALLER, rung 1: the elves' mage (approved 2026-09-30, "Pride's Bestiary"): BORN TO THE HEIGHT.
--
-- The spire's Exposure does nothing to it, and standing on it, it casts for +3 Magic Damage from a tile further out
-- (utility_born_to_the_height) -- on top of Unblemished's own +4 and tile. So the open span is where it wants to
-- be, and the open span is where the company least wants to go and get it.
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
        "weapon_wand",                "ability_ice_bolt", false,
        "utility_born_to_the_height", false,              false,
        false,                        false,              false,
    },
    drops = { "armor_skywalkers_sandals" },
    defaultAction = "weapon_wand",
    signatureWeapon = "weapon_wand",
}
