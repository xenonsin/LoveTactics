-- CERBERUS'S HEAD: a head, not a body (Combat.spawnHeads). Grown at the bell off utility_cerberus_head on Cerberus's
-- grid ("The Crown's Bestiary", slice C), it stands on no tile, reads its position through the body, and dies with it.
--
-- `timeless`, AND THAT IS WHAT SETS IT APART FROM THE CHIMERA'S. Its goat and serpent take turns of their own; these
-- take none, because the review's dog bites with every head on ITS turn (weapon_three_mouths counts the heads awake).
-- So a head never enters the turn order: it is a third of the bar that can be aimed at, put to sleep, and broken.
--
-- 60 health is a placeholder: at the bell the body's bar is cut into its heads (GatePit.split), so a deep Cerberus's
-- heads are a third of a deep Cerberus. Its defence and hide are the body's, so a blow on the body (which lands on a
-- head) reads the armour the forecast quoted.
return {
    name = "Cerberus's Head",
    race = "demon",
    tier = 2,
    timeless = true,
    sprite = "assets/chars/cerberus_head.png",
    unarmed = false, -- it bites through the body's mouths, not its own
    stats = {
        health = 60, mana = 0, stamina = 10,
        staminaRegen = 0,
        damage = 0, magicDamage = 0,
        defense = 6, magicDefense = 6,
        movement = 0, -- it goes where the dog goes
        speed = 5,
        skill = 5, luck = 4,
    },
    resist = { fire = 3, slash = 1, pierce = 1, impact = -2 },
    startingItems = {
        "utility_honey_cake", false, false,
        false,                false, false,
        false,                false, false,
    },
    archetype = "defensive",
}
