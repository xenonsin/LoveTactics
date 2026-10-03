-- THE ECHO: one of Envy's one-off families, on the waste's seat ("Envy's Bestiary", 2026-10-03, slice C). The
-- nymph who could only repeat what others said, faded until only the voice was left.
--
--   ONLY REPEATS  whenever a foe casts an ability within 3 of her, she repeats its blow at half power, from her
--                 own tile, at the caster (trait_only_repeats)
--
-- THE COUNTERPLAY, STATED: cast from range, or kill her first. A spell cast beside an Echo is a spell cast twice,
-- once at you. The player's Echo trait lends an ally's cast at half power; this is that rule turned on the company.
--
-- An elemental: a voice on the wind with an outline round it. Nothing solid to cut, and a club goes through.
return {
    name = "Echo",
    race = "elemental",
    tier = 2,
    sprite = "assets/chars/echo.png",
    stats = {
        health = 40, mana = 30, stamina = 10,
        staminaRegen = 2,
        damage = 0, magicDamage = 9,
        defense = 2, magicDefense = 6,
        movement = 4,
        speed = 5,
        skill = 6, luck = 6,
    },
    resist = { slash = 2, pierce = 1, impact = -3, wind = 2 },
    startingItems = {
        false,                   false,                  false,
        "weapon_borrowed_voice", "utility_only_repeats", false,
        false,                   false,                  false,
    },
    defaultAction = "weapon_borrowed_voice",
    -- ITS OWN PIECE (docs/drops.md): a foe's working, carried back as a free one.
    drops = { "utility_echoing_shell" },
    archetype = "aggressive",
}
