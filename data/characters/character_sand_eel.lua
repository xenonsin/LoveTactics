-- SAND-EEL: one of Envy's one-off families, on both of the Ribstone Waste's floors ("Envy's Bestiary", round 3).
-- Leviathan's brood, at the size of a dog.
--
--   EEL SURGE   it goes Underground and comes up where the Fairest stood, biting whoever is still standing there,
--               then dives again next turn (weapon_eel_surge; its planner aims at the Fairest,
--               models/envy_oneoffs.lua)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: hit them in the round they're up, or keep the Fairest moving.
-- They teach Leviathan's mark before the stair.
--
-- The small fry of the waste, and the lightest body on it. A hide slick enough to turn a point a little.
return {
    name = "Sand-Eel",
    race = "beast",
    tier = 1,
    sprite = "assets/chars/sand_eel.png",
    stats = {
        health = 22, mana = 0, stamina = 20,
        staminaRegen = 4,
        damage = 9, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 4,
        speed = 5,
        skill = 4, luck = 4,
    },
    resist = { pierce = 1, impact = -1 },
    startingItems = {
        "weapon_eel_surge", false, false,
        false,              false, false,
        false,              false, false,
    },
    drops = { "armor_eel_skin_boots" },
    defaultAction = "weapon_eel_surge",
    archetype = "aggressive",
}
