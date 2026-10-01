-- THE ELF LONGBOW, rung 1 (approved 2026-09-30, "Pride's Bestiary"): DRAWN STANCE.
--
-- Its Heartstring Longbow, drawn on a turn it has not moved, cannot be avoided and carries through to the body
-- behind its target. Unblemished adds a tile of reach on top of the longbow's five, so an untouched archer reaches
-- six and never needs to move to find a shot -- the stance and the race pay each other. Make it move, or mark it.
--
-- It drops the Heartstring Longbow. On the hunter table.
return {
    name = "Elf Longbow",
    race = "elf",
    tier = 2,
    class = "hunter",
    sprite = "assets/chars/elf_longbow.png",
    archetype = "skirmish",
    stats = {
        health = 40, mana = 0, stamina = 24,
        staminaRegen = 4,
        damage = 6, magicDamage = 0,
        defense = 2, magicDefense = 3,
        movement = 4,
        speed = 3,
        skill = 4, luck = 4,
    },
    startingItems = {
        "weapon_heartstring_longbow", false, false,
        false,                        false, false,
        false,                        false, false,
    },
    drops = { "weapon_heartstring_longbow" },
    defaultAction = "weapon_heartstring_longbow",
    signatureWeapon = "weapon_heartstring_longbow",
}
