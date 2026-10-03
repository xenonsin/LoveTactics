-- THE EVIL EYE: one of Envy's one-off families, on both of the Ribstone Waste's floors ("Envy's Bestiary", round 1,
-- page v5). The eye that falls on good fortune: a demon that is nothing but a look.
--
--   THE EYE FALLS   at the start of its turn it looks at the Fairest -- the body of the company holding the most
--                   blessings (models/fairest.lua) -- and, if it can see that body, sours one of its blessings
--                   into Rattled (trait_the_eye_falls; models/envy_oneoffs.lua)
--   IT FLOATS       the `flying` tag on its organ
--   ITS GAZE        a burning look at range 3, which needs the same line of sight
--
-- THE COUNTERPLAY, STATED, and it is the review's own: kill it from range, or keep the Fairest behind a ridge. It
-- is traffic that teaches the badge before either boss does.
--
-- A demon, so it takes holy the harder (the race line) and its look burns.
return {
    name = "Evil Eye",
    race = "demon",
    tier = 2,
    sprite = "assets/chars/evil_eye.png",
    stats = {
        health = 40, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 0, magicDamage = 10,
        defense = 3, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 6, luck = 4,
    },
    -- A lidless eye in the air: a club glances off the curve of it, and a point goes straight in.
    resist = { impact = 2, pierce = -2 },
    startingItems = {
        "weapon_baleful_gaze", "utility_the_evil_eye", false,
        false,                 false,                  false,
        false,                 false,                  false,
    },
    drops = { "utility_nazar" },
    defaultAction = "weapon_baleful_gaze",
    archetype = "skirmish", -- it keeps its distance: the look works from across the sand
}
