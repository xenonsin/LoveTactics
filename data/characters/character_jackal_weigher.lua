-- JACKAL WEIGHER: one of Envy's one-off families, on the Ribstone Waste's approach ("Envy's Bestiary", round 2).
-- Jackal-headed guardians of the desert dead, who weigh hearts.
--
--   THE WEIGHING   at the start of its turn a Weigher weighs two of the company against each other -- the two
--                  nearest it -- and the badges show the scale: the lighter heart (less current health) is Spared
--                  that turn, and the heavier is Weighed and struck by every Weigher (trait_the_weighing;
--                  models/envy_oneoffs.lua)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: balance your health. Heal the wrong one and you make it the
-- target, and a body brought low stops being hit.
--
-- A beast by the head, and it fights with a creature's copy of a khopesh. An edge turns on the hide; a club does not.
return {
    name = "Jackal Weigher",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/jackal_weigher.png",
    stats = {
        health = 50, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 11, magicDamage = 0,
        defense = 5, magicDefense = 4,
        movement = 4,
        speed = 4,
        skill = 5, luck = 3,
    },
    resist = { slash = 2, impact = -2 },
    startingItems = {
        "weapon_weighers_khopesh", "utility_the_weighing", false,
        false,                     false,                  false,
        false,                     false,                  false,
    },
    drops = { "utility_scale_of_hearts" },
    defaultAction = "weapon_weighers_khopesh",
    archetype = "aggressive",
}
