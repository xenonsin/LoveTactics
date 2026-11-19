-- THE FLEDGLING, rung 2: a human newly turned (Wrath's vampires, 2026-09-26). A fighter, and a vampire on top of
-- that (`vampire = true`: undead, Grave-Cold, and the Thirst). NEWLY TURNED: it enters Bloodlust at 2 Thirst, not
-- 3 -- it has not learned to wait -- so a company that keeps it from drinking for two turns has it biting its own
-- ghouls by the third. Every vampire carries Wing-Swap (trade places with a Familiar) and Feed (drink from a
-- Blood-Ghoul beside it).
--
-- Drops the Hungering Fang (the wait made a weapon) and Bloodhound's Scent (Scent of Blood for the living).
--
-- ITS LEVER IS ORDER AND BRING (2026-11-19, the creature identity pass): A LONE FEEDER (`loneFeeder`,
-- Thirst.loneFeed). Of the two options the review offered -- leap to the nearest bleeding foe in Bloodlust, or
-- feed off a downed company body -- this is the one built, because Bleed is a badge the player already reads and
-- the planner already has the walk: in Bloodlust it crosses the board to the nearest BLEEDING foe instead of
-- biting whoever stands beside it, and only with no foe bleeding does it bite the nearest body. So the body you
-- let bleed is the body it hunts, and a cure for Bleed is the tool it asks for.
return {
    name = "Fledgling",
    race = "human",
    tier = 2,
    class = "fighter",
    vampire = true,
    newlyTurned = true,
    loneFeeder = true,
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
    ai = require("models.wrath_targeting").vampire, -- the faintest pulse (2026-11-19)
}
