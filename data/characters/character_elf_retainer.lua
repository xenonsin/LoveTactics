-- THE ELF RETAINER, rung 1: the elves' filler, as the gilded page is the Rank's (approved 2026-09-30, "Pride's
-- Bestiary").
--
-- Unblemished, it is a real spear (+4 Damage and a tile of reach on the thrust); marked once, it is a thin body with
-- a pole.
--
-- THE RETAINER'S OATH (the creature identity pass, 2026-11-19). It used to be nothing but the race rule and a stock
-- spear, and the audit failed it for that. Now it is SWORN: beside an Unblemished elf of its side, it takes every
-- blow meant for that elf (utility_sworn_retainer; models/elf_court.lua), and the elf wears Retained. So the court's
-- old answer -- one wide first hit that marks everybody -- lands on the retainers instead, and the order is: break
-- the retainers, then mark the court. It never swears to another retainer, so two of them do not trade a blow back
-- and forth.
--
-- `aggressive` still, and that was measured: `defensive` kept the retainers home beside their charges and the Ring and
-- the Elf Patrol ran 29 and 27 unit-turns against the skirmish budget of 22 (tests/skirmish_spec.lua). A retainer
-- that walks out leaves its charge bare, which is the opening the company is meant to look for.
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
        "weapon_iron_spear", "utility_sworn_retainer", false,
        false,               false, false,
        false,               false, false,
    },
    drops = { "armor_livery_of_the_house" },
    defaultAction = "weapon_iron_spear",
    signatureWeapon = "weapon_iron_spear",
    -- TARGETING (2026-11-19): whatever is already within its spear's reach first, so it strikes from beside its charge
    -- when it can rather than walking off to find somebody.
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
