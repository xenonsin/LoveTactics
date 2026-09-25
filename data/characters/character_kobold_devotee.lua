-- THE KOBOLD DEVOTEE, rung 1: a worshipper that came to the Nest to be eaten. Not pitched as its own body
-- -- the review approved "worshippers walk in to be eaten" (2026-09-25, The Nest) -- and split from the
-- Skulker because a blueprint's posture is the blueprint's, not the body's: the Skulker fights, and a
-- worshipper that fought would stop walking to the Godling to swing at whoever was nearest.
--
-- The `devotee` posture (models/ai.lua): it never swings. It closes on the nearest dragon on its side and
-- stands beside it, where the Godling takes it at the end of its turn (trait_the_tithe) -- heals, and grows
-- a stack of Glut. So every Devotee the company does not cut down on the way in is a stack the Godling
-- gets, which is what makes the Nest a race rather than a brawl. It carries a dagger only so the bestiary
-- has something to call its hand; it has no rule that uses it.
return {
    name = "Kobold Devotee",
    race = "kobold",
    tier = 1,
    class = "fighter",
    sprite = "assets/chars/kobold_devotee.png",
    archetype = "devotee",
    stats = {
        health = 14, mana = 0, stamina = 10,
        staminaRegen = 2,
        damage = 4, magicDamage = 0,
        defense = 0, magicDefense = 0,
        movement = 4, -- 5 after the race
        speed = 4,    -- 5 after the race
        skill = 4, luck = 4,
    },
    startingItems = {
        "weapon_iron_dagger", false, false,
        false,                false, false,
        false,                false, false,
    },
    drops = {},
    defaultAction = "weapon_iron_dagger",
    signatureWeapon = "weapon_iron_dagger",
}
