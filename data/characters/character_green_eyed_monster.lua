-- THE GREEN-EYED MONSTER: one of Envy's one-off families, on the Ribstone Waste's approach ("Envy's Bestiary",
-- round 2). Iago's monster, "which doth mock the meat it feeds on". It hates closeness.
--
--   WHICH DOTH MOCK THE MEAT   +2 damage on every blow for each pair of the company standing side by side
--                              (trait_mocks_the_meat)
--   GREEN-EYED ROAR            every pair of the company standing side by side is shoved apart, each body 1 tile
--                              from the other (ability_green_eyed_roar; its planner roars whenever there is a pair)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: fight it spread out -- the opposite of what the Weighers and
-- a shield wall ask, which is the point.
--
-- NOT PRIDE'S RANK AND FILE, though both read adjacency: that rule guards Pride's own bodies, and this one punishes
-- yours. A demon, so its claws burn and it takes holy the harder.
return {
    name = "Green-Eyed Monster",
    race = "demon",
    tier = 3,
    sprite = "assets/chars/green_eyed_monster.png",
    stats = {
        health = 100, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 13, magicDamage = 0,
        defense = 6, magicDefense = 4,
        movement = 4,
        speed = 4,
        skill = 5, luck = 3,
    },
    resist = { slash = 2, pierce = 1, impact = -3 },
    startingItems = {
        "weapon_jealous_claws", "ability_green_eyed_roar", "utility_mocks_the_meat",
        false,                  false,                     false,
        false,                  false,                     false,
    },
    drops = { "ability_jealous_roar" },
    defaultAction = "weapon_jealous_claws",
    archetype = "aggressive",
}
