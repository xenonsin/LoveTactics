-- THE ONI GENERAL: the clan's alpha, and the lead of the Black-Flame Court on Wrath's seat (approved 2026-09-26/27,
-- "The Oni of Wrath"; round 1 cut its naming with the ogres, and round 2 gave it all three of the verbs offered).
--
-- It escalates the clan in KIND:
--   BLACK-FLAME DOME   a 3x3 marked for a turn, then closed: Rooted and Burning inside
--   CALL TO VENGEANCE  every oni with its horn whole goes Horn Out at the foe it points at
--   BESTOW             an oni ally gains +2 to every stat, and its horn cannot be snapped while the General stands
--   THE CLAN STANDS    while it stands, a felled oni within 2 of it stays up for one more action, once
-- Kill the General and all four go with it.
--
-- THE CLAN STANDS HAS A REACH NOW (2026-11-19, the creature identity pass). It held the whole board up, which made
-- the General one of six Wrath alphas pulling the same kill-the-head lever. Within 2 it is POSITION as well: draw
-- the clan off the General and its oni fall like anybody else's.
--
-- It drops the Black-Flame Dome. A warlord on the fighter table.
return {
    name = "Oni General",
    race = "oni",
    tier = 3,
    class = "fighter",
    discipline = "warlord",
    sprite = "assets/chars/oni_general.png",
    archetype = "aggressive",
    stats = {
        health = 110, mana = 26, stamina = 28,
        staminaRegen = 4, manaRegen = 2,
        damage = 13, magicDamage = 9,
        defense = 6, magicDefense = 5,
        movement = 4,
        speed = 3,
        skill = 6, luck = 5,
    },
    startingItems = {
        "weapon_iron_greatsword", "ability_black_flame_dome", "ability_call_to_vengeance",
        "ability_bestow",         "utility_the_clan_stands",  false,
        false,                    false,                      false,
    },
    drops = { "ability_black_flame_dome" },
    defaultAction = "weapon_iron_greatsword",
    signatureWeapon = "weapon_iron_greatsword",
    ai = require("models.wrath_targeting").oni, -- the marked, else the nearest (2026-11-19)
}
