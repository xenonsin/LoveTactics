-- THE ELF BLADEDANCER, rung 1 (approved 2026-09-30, "Pride's Bestiary"): UNTOUCHABLE.
--
-- While it is Unblemished it evades every attack that rolls to hit (utility_untouchable). Only something that does
-- not ask the dice can mar it -- a spell, an area, a hazard, a blow that cannot be avoided -- and once marred it is
-- an ordinary swordsman with a light build. The fight asks whether the company brought anything that does not roll.
--
-- It drops the Dancer's Veil. On the fighter table.
return {
    name = "Elf Bladedancer",
    race = "elf",
    tier = 2,
    class = "fighter",
    sprite = "assets/chars/elf_bladedancer.png",
    archetype = "aggressive",
    stats = {
        health = 44, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 7, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 5,
        speed = 4,
        skill = 4, luck = 5,
    },
    startingItems = {
        "weapon_iron_sword", "utility_untouchable", false,
        false,               false,                 false,
        false,               false,                 false,
    },
    drops = { "armor_dancers_veil" },
    defaultAction = "weapon_iron_sword",
    signatureWeapon = "weapon_iron_sword",
}
