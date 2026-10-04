-- THE OLD SLOTH: a Megatherium, the ground sloth's grandmother, an elite on the tundra's approach ("Sloth's
-- Bestiary", slice A, 2026-10-04). Four tiles of animal (`footprint`, the ogre's 2x2).
--
--   DORMANT   it opens the fight Dormant (status_dormant) with a full bank of 5. A blow wakes it, into Rude
--             Awakening.
--   BANKED    as the Ground Sloth's, held to 5 (utility_deep_bank), and spent as RING SWEEPS: each banked turn
--             sweeps every foe beside it, and once more for the turn itself (weapon_megatherium_sweep). A blow that
--             lands on it knocks a turn out. It moves 1.
--
-- THE COUNTERPLAY, STATED, and it is the review's own: wake it from range and chip the bank down before anyone
-- stands in its ring. It must be killed -- the circle's "sleepers count as passed" was denied on review -- so the
-- question is never whether to wake it, only from where.
return {
    name = "The Old Sloth",
    race = "beast",
    tier = 3,
    sprite = "assets/chars/old_sloth.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 140, mana = 0, stamina = 40,
        staminaRegen = 5,
        damage = 12, magicDamage = 0,
        defense = 8, magicDefense = 4,
        movement = 1,
        speed = 2,
        skill = 4, luck = 2,
    },
    resist = { slash = 3, impact = -3 },
    startingItems = {
        "weapon_megatherium_sweep", "utility_deep_bank", false,
        false,                      false,               false,
        false,                      false,               false,
    },
    drops = { "armor_hibernal_hide" },
    defaultAction = "weapon_megatherium_sweep",
    archetype = "aggressive",
}
