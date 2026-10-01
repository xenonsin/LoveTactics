-- THE ELF-LORD: the elite of the spire's approach (approved 2026-09-30, "Pride's Bestiary"): RENOWN AS AN AURA.
--
-- Every kill any elf of his side makes is told to his credit -- a stack of Renown, +2 Damage and +1 Speed each, for
-- the fight -- and every elf within 3 of him fights for +1 Damage a stack (utility_renown). He is fielded with a
-- longbow, a bladedancer and retainers, so the court starts weak and grows with every body the company lets fall;
-- fell him and the count is gone from all of them at once.
--
-- He drops the Laurel of Renown. On the fighter table, in mail, with the greatsword a lord carries to be seen with.
return {
    name = "The Elf-Lord",
    race = "elf",
    tier = 3,
    boss = true,
    class = "fighter",
    sprite = "assets/chars/elf_lord.png",
    archetype = "aggressive",
    stats = {
        health = 120, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 11, magicDamage = 0,
        defense = 6, magicDefense = 5,
        movement = 4,
        speed = 3,
        skill = 6, luck = 6,
    },
    startingItems = {
        "weapon_iron_greatsword", "utility_renown", "armor_chainmail",
        false,                    false,            false,
        false,                    false,            false,
    },
    drops = { "utility_laurel_of_renown" },
    defaultAction = "weapon_iron_greatsword",
    signatureWeapon = "weapon_iron_greatsword",
}
