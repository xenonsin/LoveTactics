-- THE SIRE, rung 3: the vampires' alpha, in The Sire's Brood (Wrath's approach). Wrath's vampires, 2026-09-26. A
-- human battlemage who made every vampire it leads.
--
--   BLOOD BOND      while it stands no vampire of its side can enter Bloodlust -- their Thirst stops at 2 -- and
--                   when it falls every one of them enters Bloodlust at once (trait_blood_bond)
--   TITHE           it heals 10% of every drink its brood takes
--   CALL THE BLOOD  every 3 turns, every bleeding foe within 5 is pulled 2 tiles toward it, bleeding every tile
--
-- The fight's question is the order: kill the Sire first and the brood turns loose on whoever is nearest, its own
-- ghouls included; kill the brood first and the Sire keeps drinking their tithe. It never cowers.
--
-- A fighter on the fighter table carrying the battlemage's Battle Casting, so the discipline it claims is on it.
-- Drops the Sire's Signet and the Box of Grave-Earth.
return {
    name = "The Sire",
    race = "human",
    tier = 3,
    class = "fighter",
    discipline = "battlemage",
    vampire = true,
    sprite = "assets/chars/the_sire.png",
    archetype = "aggressive",
    stats = {
        health = 110, mana = 20, stamina = 30,
        staminaRegen = 5,
        damage = 13, magicDamage = 8,
        defense = 5, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 7, luck = 6,
    },
    startingItems = {
        "weapon_iron_greatsword", "utility_blood_bond", "ability_call_the_blood",
        "utility_battle_casting", "ability_wing_swap",  "ability_feed",
        false,                    false,                false,
    },
    drops = { "utility_sires_signet", "utility_box_of_grave_earth" },
    defaultAction = "weapon_iron_greatsword",
    signatureWeapon = "weapon_iron_greatsword",
}
