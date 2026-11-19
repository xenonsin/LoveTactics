-- THE ELF HIGHBORN, rung 1 (approved 2026-09-30, "Pride's Bestiary"): WILL NOT ADMIT THE WOUND.
--
-- The one elf whose Unblemished comes back: let it go a full round without being struck and it is Unblemished again,
-- and the badge returning is the tell (utility_will_not_admit). Marking it once is not enough; it has to be kept
-- marked, which is a promise of a blow every round for as long as it stands.
--
-- WOUNDED PRIDE (the creature identity pass, 2026-11-19; utility_wounded_pride, models/elf_court.lua): the blow that
-- marks it Taunts it onto the striker for 2 turns -- and since its Unblemished comes back, it is affronted afresh
-- every time it is marked again. Keep it marked with the same body and that body has a highborn on it for good.
-- TARGETING: the kill.
--
-- A buckler on the off hand, which a highborn carries to be seen guarding. It drops the Highborn Circlet. On the
-- fighter table.
return {
    name = "Elf Highborn",
    race = "elf",
    tier = 3,
    class = "fighter",
    sprite = "assets/chars/elf_highborn.png",
    archetype = "aggressive",
    stats = {
        health = 88, mana = 0, stamina = 26,
        staminaRegen = 4,
        damage = 9, magicDamage = 0,
        defense = 5, magicDefense = 4,
        movement = 4,
        speed = 3,
        skill = 5, luck = 5,
    },
    startingItems = {
        "weapon_iron_sword",     "utility_will_not_admit", "armor_buckler",
        "utility_wounded_pride", false,                    false,
        false,               false,                    false,
    },
    drops = { "utility_highborn_circlet" },
    defaultAction = "weapon_iron_sword",
    signatureWeapon = "weapon_iron_sword",
    ai = {
        { priority = "normal", act = "attack", targetPref = "lethal",
          when = { subject = "any_foe", test = "exists" } },
    },
}
