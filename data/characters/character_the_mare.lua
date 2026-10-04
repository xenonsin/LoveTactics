-- THE MARE, rung 3: the night-hag that sits on a sleeper's chest ("Sloth's Bestiary", 2026-10-04, approved). Sloth's
-- seat.
--
--   HAG-RIDDEN  it climbs onto an Asleep body: while it rides, blows do not wake the sleeper, and the sleeper takes
--               the Mare's damage at the top of each of its turns (weapon_hags_weight, trait_hag_ridden,
--               status_hag_ridden).
--   COUNTER     wake the sleepers before it reaches them, or strike or shove the Mare off. It can be struck while
--               it rides, and it cannot walk off the body it sits on.
--
-- THE DEPARTURE: the review had it share the sleeper's tile; no two bodies share a tile in this engine, so it sits
-- BESIDE the sleeper and pins itself there (status_riding), the hawk's Mantling shape.
--
-- UNDEAD, by the author's leave to choose: a mare is a dead thing that will not lie down at night, and the holy line
-- gives a priest the lever on it. Smoke more than flesh -- an edge and a point pass through it, and a hammer
-- scatters it.
--
-- It drops the Mare's Bridle, on the assassin table.
return {
    name = "The Mare",
    race = "undead",
    tier = 3,
    sprite = "assets/chars/the_mare.png",
    archetype = "aggressive",
    stats = {
        health = 86, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 10, magicDamage = 0,
        defense = 3, magicDefense = 6,
        movement = 5,
        speed = 5,
        skill = 5, luck = 4,
    },
    resist = { slash = 2, pierce = 2, impact = -4, holy = -6 },
    startingItems = {
        "weapon_hags_weight", false, false,
        false,                false, false,
        false,                false, false,
    },
    drops = { "utility_mares_bridle" },
    defaultAction = "weapon_hags_weight",
    signatureWeapon = "weapon_hags_weight",
    -- The sleeper first: it does nothing to a body that is awake that a club would not.
    ai = {
        { priority = "high", act = "attack", targetPref = "sleeping",
          when = { subject = "any_foe", test = "has_status", value = "status_sleep" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
