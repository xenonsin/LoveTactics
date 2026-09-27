-- THE FLEDGLING, rung 2: a human newly turned (Wrath's vampires, 2026-09-26). A fighter, and a vampire on top of
-- that (`vampire = true`: undead, Grave-Cold, and the Thirst). NEWLY TURNED: it enters Bloodlust at 2 Thirst, not
-- 3 -- it has not learned to wait -- so a company that keeps it from drinking for two turns has it biting its own
-- ghouls by the third. Every vampire carries Wing-Swap (trade places with a Familiar) and Feed (drink from a
-- Blood-Ghoul beside it).
--
-- Drops the Hungering Fang (the wait made a weapon) and Bloodhound's Scent (Scent of Blood for the living).
return {
    name = "Fledgling",
    race = "human",
    tier = 2,
    class = "fighter",
    vampire = true,
    newlyTurned = true,
    sprite = "assets/chars/fledgling.png",
    archetype = "aggressive",
    stats = {
        health = 44, mana = 0, stamina = 22,
        staminaRegen = 4,
        damage = 10, magicDamage = 0,
        defense = 3, magicDefense = 3,
        movement = 4,
        speed = 5,
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_iron_dagger", "ability_wing_swap", "ability_feed",
        false,                false,               false,
        false,                false,               false,
    },
    drops = { "weapon_hungering_fang", "utility_bloodhounds_scent" },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon = "weapon_iron_dagger",
}
