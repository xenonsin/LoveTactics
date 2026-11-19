-- THE ELF LONGBOW, rung 1 (approved 2026-09-30, "Pride's Bestiary"): DRAWN STANCE.
--
-- Its Heartstring Longbow, drawn on a turn it has not moved, cannot be avoided and carries through to the body
-- behind its target. Unblemished adds a tile of reach on top of the longbow's five, so an untouched archer reaches
-- six and never needs to move to find a shot -- the stance and the race pay each other. Make it move, or mark it.
--
-- WOUNDED PRIDE (the creature identity pass, 2026-11-19; utility_wounded_pride, models/elf_court.lua): the blow that
-- marks it Taunts it onto the striker for 2 turns -- and an archer driven at one body has stopped choosing its shot.
-- TARGETING: a caster winding up first (a rival's working is an insult it answers from six tiles), then the kill.
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
        "weapon_heartstring_longbow", "utility_wounded_pride", false,
        false,                        false,                   false,
        false,                        false, false,
    },
    drops = { "weapon_heartstring_longbow" },
    defaultAction = "weapon_heartstring_longbow",
    signatureWeapon = "weapon_heartstring_longbow",
    ai = {
        { priority = "high", act = "attack", targetPref = "channeling",
          when = { subject = "any_foe", test = "has_status", value = "status_channeling" } },
        { priority = "normal", act = "attack", targetPref = "lethal",
          when = { subject = "any_foe", test = "exists" } },
    },
}
