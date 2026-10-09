-- THE GREATER ARCHON: the court's line caster, on the Crown's floor ("The Crown's Bestiary", slice A, 2026-10-09).
-- Humanoid, robed, and senior.
--
--   THE KILLING MAGIC   a beam 5 tiles long that strikes every body in the line and passes through barriers
--                       (ability_killing_magic)
--   WARD                when an Archon within 3 is struck while it stands, it casts a Magical Barrier on that Archon,
--                       on a cooldown, and it opens every fight under one itself (utility_ward_of_the_court)
--   SPIRIT BODY         the race (data/races/archon.lua)
--
-- HOW YOU BEAT IT, the review's own: don't stand in a line with each other. Kill it first: its wards keep the rest of
-- the court standing, and your barriers won't save you from its beam.
--
-- It drops Killing Magic, a Mage's -- the very piece it casts, which a humanoid may carry.
return {
    name = "Greater Archon",
    race = "archon",
    tier = 2,
    class = "priest",
    sprite = "assets/chars/greater_archon.png",
    archetype = "aggressive",
    stats = {
        health = 31, mana = 42, stamina = 20,
        staminaRegen = 3, manaRegen = 3,
        damage = 4, magicDamage = 10,
        defense = 3, magicDefense = 4, -- 6 after the race
        movement = 4,
        speed = 4,
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_mana_cut_blade",     "ability_killing_magic", false,
        "utility_ward_of_the_court", false,                   false,
        false,                       false,                   false,
    },
    drops = { "ability_killing_magic" },
    defaultAction = "weapon_mana_cut_blade",
    signatureWeapon = "weapon_mana_cut_blade",
}
