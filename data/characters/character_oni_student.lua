-- THE ONI STUDENT, rung 1: the clan's small body (approved 2026-09-27, "The Oni of Wrath", round 2, on the note
-- "Create a Chaf oni"; the Ogre-Kin were cut in round 1 and must not come back).
--
-- A young sword-student: quick, fragile, named and horned, but with no restraint yet. It wears the whole racial
-- rule, so a clan death sends it Horn Out on the spot -- the body that turns one kill into a counter-rush. No drop:
-- chaff carries nothing worth carrying out.
return {
    name = "Oni Student",
    race = "oni",
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
}
