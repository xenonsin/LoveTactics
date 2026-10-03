-- SHADE: one of Envy's one-off families, on both of the Ribstone Waste's floors ("Envy's Bestiary", round 1). A
-- shadow that left whoever cast it, and lives in the lee of the ridges.
--
--   CAST BY YOU   while it stands beside a wall or ridge it is Unseen (status_invisible: it cannot be targeted);
--                 on open sand it is Limned (trait_cast_by_you, status_cast_by_you; models/envy_oneoffs.lua)
--   ITS TOUCH     leaves the target Rattled
--
-- THE COUNTERPLAY, STATED, and it is the review's own: drive it into the open. The desert has more open ground than
-- any other board, and a shove that puts it there finds it the same instant. A Mark forbids the hiding outright, and
-- an area blast reaches it where it hides.
--
-- NEAR THE SABERTOOTH, AND NOT THE SAME: the wood's cat hides to pounce. This has no pounce; it hides to live.
-- Undead, so it takes holy the harder; a club spreads it thin.
return {
    name = "Shade",
    race = "undead",
    tier = 2,
    sprite = "assets/chars/shade.png",
    stats = {
        health = 36, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 0, magicDamage = 9,
        defense = 2, magicDefense = 6,
        movement = 5,
        speed = 5,
        skill = 6, luck = 6,
    },
    resist = { slash = 2, pierce = 1, impact = -3, holy = -3 },
    startingItems = {
        "weapon_shade_touch", "utility_cast_by_you", false,
        false,                false,                 false,
        false,                false,                 false,
    },
    drops = { "armor_shade_cloak" },
    defaultAction = "weapon_shade_touch",
    archetype = "aggressive",
}
