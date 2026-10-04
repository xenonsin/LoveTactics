-- THE SANDMAN: Sloth's mini boss, on floor 9's stair ("Sloth's Bestiary", slice G, 2026-10-04; designed from the
-- circle's brief, every rule approved on review). A tall dream-thing who pours sand from his own hands and puts the
-- world to bed. He is the general's herald: his sleep is the first taste of hers.
--
-- AN ELEMENTAL, picked over a demon: he is sand given an outline, and the elemental record is the one that asks a
-- body to say what it is made of and nothing else (data/races/elemental.lua) -- no race grant to work around, no
-- clan rule. A demon would have brought Binsfeld's holy line and a burning bite, and nothing in a dream burns.
--
-- HIS RULES ride on three organs (a blueprint's own `traits` field is never collected), and models/sandman.lua argues
-- them in full: Sand in the Eyes (a cross, a ring, a row, sown a turn ahead; what stands on it falls Asleep, either
-- side), Run Through the Glass (a foe ending its turn beside him sends him to his marked tile, and the tile he left
-- sleeps whoever stops on it) and Bad Dreams (woken from his sleep by a blow, Rattled until the end of its next turn).
--
-- SIZED AS A LIEUTENANT: tier 4, 190 health, 63% of the general's 300 (the 60-85% band tests/sloth_circle_spec.lua
-- holds the stair to). `referenceLevel` like every stair centrepiece, so these are his numbers on his own floor and a
-- shallower meeting is a smaller him. `boss`, off the execute and Charm tables as every stair body is.
return {
    name = "The Sandman",
    race = "elemental",
    tier = 4,
    referenceLevel = 13,
    boss = true,
    sprite = "assets/chars/the_sandman.png",
    stats = {
        health = 190, mana = 0, stamina = 30,
        staminaRegen = 5,
        damage = 8, magicDamage = 14,
        defense = 6, magicDefense = 12,
        movement = 4,
        speed = 4,
        skill = 5, luck = 6,
    },
    -- Sand: a blade passes through it and a hammer scatters it, and water makes mud of it. A redistribution, summing
    -- to zero across the physical three (docs/bestiary.md).
    resist = { slash = 2, impact = -2, water = -4 },
    startingItems = {
        false, "weapon_sand_from_his_hands", false,
        "utility_sand_in_the_eyes", "utility_run_through_the_glass", "utility_bad_dreams",
        false, false, false,
    },
    -- His stair pays his own pieces: his sowing as a Trapper's, his hourglass as a Ninja's. Descent.DROPS.sloth.minor
    -- pays the same list on his stair.
    drops = { "ability_sandmans_pouch", "utility_the_hourglass" },
    defaultAction = "weapon_sand_from_his_hands",
    archetype = "defensive",
}
