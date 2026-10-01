-- THE ELF RETAINER, rung 1: the elves' filler, as the gilded page is the Rank's (approved 2026-09-30, "Pride's
-- Bestiary").
--
-- Nothing but the race rule and a spear. Unblemished, it is a real spear (+4 Damage and a tile of reach on the
-- thrust); marked once, it is a thin body with a pole. Which makes it the cheapest lesson on the spire: a blow that
-- marks three of them is worth more than one that kills one.
--
-- It drops the Livery of the House. On the fighter table: a knight table walls a line body at depth.
return {
    name = "Elf Retainer",
    race = "elf",
    tier = 1,
    class = "fighter",
    sprite = "assets/chars/elf_retainer.png",
    archetype = "aggressive",
    stats = {
        health = 24, mana = 0, stamina = 16,
        staminaRegen = 3,
        damage = 4, magicDamage = 0, -- 8 while Unblemished
        defense = 2, magicDefense = 2,
        movement = 4,
        speed = 4,
        skill = 2, luck = 3, -- 4 after the race
    },
    startingItems = {
        "weapon_iron_spear", false, false,
        false,               false, false,
        false,               false, false,
    },
    drops = { "armor_livery_of_the_house" },
    defaultAction = "weapon_iron_spear",
    signatureWeapon = "weapon_iron_spear",
}
