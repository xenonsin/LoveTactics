-- THE ONI STUDENT, rung 1: the clan's small body (approved 2026-09-27, "The Oni of Wrath", round 2, on the note
-- "Create a Chaf oni"; the Ogre-Kin were cut in round 1 and must not come back).
--
-- A young sword-student: quick, fragile, named and horned, but with no restraint yet. It wears the whole racial
-- rule, so a clan death sends it Horn Out on the spot -- the body that turns one kill into a counter-rush. No drop:
-- chaff carries nothing worth carrying out.
--
-- ITS LEVER IS ORDER (2026-11-19, the creature identity pass): NO RESTRAINT YET. Where every other oni holds its
-- temper to half health, the Student goes Horn Out at its FIRST wound (`noRestraint`, read by trait_the_horn) and
-- goes for whoever drew it. So chipping one is a commitment: hit it with the body that can take the rush, or kill
-- it in one blow. It was the plain Oni's rule on less health before, and the audit could not tell them apart.
return {
    name = "Oni Student",
    race = "oni",
    noRestraint = true,
    tier = 1,
    class = "fighter",
    sprite = "assets/chars/oni_student.png",
    archetype = "aggressive",
    stats = {
        health = 26, mana = 0, stamina = 18,
        staminaRegen = 3,
        damage = 7, magicDamage = 0, -- 8 after the race
        defense = 2, magicDefense = 1,
        movement = 4,
        speed = 4,
        skill = 3, luck = 3, -- 5 after the race
    },
    startingItems = {
        "weapon_iron_sword", false, false,
        false,               false, false,
        false,               false, false,
    },
    defaultAction = "weapon_iron_sword",
    signatureWeapon = "weapon_iron_sword",
    ai = require("models.wrath_targeting").oni, -- the marked, else the nearest (2026-11-19)
}
