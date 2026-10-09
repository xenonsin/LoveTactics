-- HELLHOUND: the Crown's line hound ("The Crown's Bestiary", slice C, approved 2026-10-09). The dogs at the bottom of
-- the rift, and Cerberus's kennel.
--
--   HEARTH-BORN   its breath (a 2-tile cone) leaves fire on the ground. A hellhound standing in fire heals instead
--                 of burning and hits for +3 (trait_hearth_born, ability_hellfire_breath)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: douse the fire or make it Wet, pull the fight off its burning
-- ground, and kill it off the fire. A hound is not hard to kill; a hound standing in its own fire is.
--
-- A DEMON, chosen over a beast: its blows burn and holy hurts it, which is what docs/bestiary.md says a demonic thing
-- is, and a hound bred in the fire is that. NOT WRATH'S BLAZE: the Blaze mends at a turn's end in LAVA (trait_of_the_
-- flows) and spreads fire it does not stand in; the Goblin Firebrand's Fire-Fed is the +3 alone. This is the first
-- body the fire HEALS.
return {
    name = "Hellhound",
    race = "demon",
    tier = 2,
    sprite = "assets/chars/hellhound.png",
    stats = {
        health = 52, mana = 0, stamina = 26,
        staminaRegen = 3,
        damage = 10, magicDamage = 6,
        defense = 3, magicDefense = 4,
        movement = 5,
        speed = 5,
        skill = 5, luck = 4,
    },
    -- Its own fire is its own, and a hide over coals: an edge and a point slip on it, a club finds the ribs.
    resist = { fire = 3, slash = 1, pierce = 1, impact = -2 },
    startingItems = {
        "weapon_hellhound_bite", "ability_hellfire_breath", "utility_hearth_born",
        false,                   false,                     false,
        false,                   false,                     false,
    },
    drops = { "utility_hellhound_collar" },
    defaultAction = "weapon_hellhound_bite",
    archetype = "aggressive",
}
