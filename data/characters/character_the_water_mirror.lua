-- THE WATER MIRROR: the Faceless line's elite on Envy's seat, and the Frieren test (reviewed 2026-10-01..03,
-- "Envy's Bestiary": "This fight should be like Frieren doppelganger test"). A still pool at the bottom of a ruin,
-- and the thing that lives in it. In its lore the Faceless are what the mirror makes when nobody stands in front
-- of it -- so it is of the race, and wears no face: it makes them.
--
-- AT THE OPENING BELL IT MAKES AN EXACT COPY OF EVERY BODY IN THE COMPANY: items, stats and tactics
-- (Summon.copyOf, with the tactics carried on top). The copies fight.
--   * THE POOL NEVER MOVES, and can't be hurt while a copy stands.
--   * A COPY KNOWS ITS ORIGINAL: it takes nothing from its own original's attacks, and goes for it first.
--   * When the last copy falls, the pool can be struck.
-- The answer is to swap opponents: nobody can beat themselves, but everybody knows a friend's weakness.
--
-- The Second Self stays beside it on the same floor (round 2 kept both). It drops Still Water, on the summoner's
-- shelf (round 3 moved it off the mage's).
return {
    name = "The Water Mirror",
    race = "faceless",
    tier = 3,
    boss = true, -- the fight is it: off the execute and Charm tables, like the Second Self
    sprite = "assets/chars/the_water_mirror.png",
    stats = {
        health = 110, mana = 60, stamina = 10,
        staminaRegen = 1, manaRegen = 5,
        damage = 0, magicDamage = 10,
        defense = 6, magicDefense = 10,
        movement = 0, -- a pool: it never moves (the Still Pool's rule rides beside this)
        speed = 3,
        skill = 5, luck = 5,
    },
    startingItems = {
        "utility_still_pool", "ability_water_ball", "ability_still_water",
        false,                false,                false,
        false,                false,                false,
    },
    drops = { "ability_still_water" },
    defaultAction = "ability_water_ball",
    unarmed = false, -- a pool has no fists
    archetype = "defensive",
    ai = {
        { priority = "normal", act = "cast", item = "ability_water_ball" },
    },
}
