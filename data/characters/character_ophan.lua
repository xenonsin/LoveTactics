-- THE OPHAN, rung 3: the wheel (reviewed 2026-09-30, "Pride's Bestiary").
--
-- A wheel within a wheel, full of eyes. With a foe beside it, it turns -- every adjacent tile is struck, every
-- turn, and its blows cannot be avoided (the Wheel of Eyes, the Turning). Nothing surprises it: its eyes see the
-- hidden (Borrowed Eyes, the Oni Twins' piece, reused because it is exactly this). The review asked that it not be
-- flankable; this game has no flanking bonus, so there is nothing to refuse and nothing was built for it.
--
-- So the answer is reach: a body that never ends a turn beside it is never struck by it. A melee company has to
-- decide who stands in the ring, and the Ophan does not care which.
--
-- It carries its own drop, the Wheel of Eyes. On the skirmisher's table.
return {
    name = "Ophan",
    race = "angel",
    tier = 3,
    sprite = "assets/chars/ophan.png",
    archetype = "aggressive",
    stats = {
        health = 92, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 6, magicDamage = 0, -- the wheel is heavy; the arm behind it need not be
        defense = 6, magicDefense = 6,
        movement = 3,
        speed = 3,
        skill = 6, luck = 2,
    },
    startingItems = {
        "weapon_wheel_of_eyes", "utility_the_turning", "utility_borrowed_eyes",
        false,                  false,                 false,
        false,                  false,                 false,
    },
    drops = { "weapon_wheel_of_eyes" },
    defaultAction = "weapon_wheel_of_eyes",
}
