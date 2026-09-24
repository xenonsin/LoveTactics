-- THE SATED: Gluttony's seat apex, a 2x2 body, and the fight whose weight is a count you can read. Reviewed
-- over two rounds on 2026-09-23 ("The Sated and the Flight"); every rule below is one a line approved.
--
-- IT OPENS HOLDING THREE MEALS (status_full, carried by the Distended Hide's Three Meals). A meal is weight:
-- +3 Damage, +3 Defense, -1 Movement and -1 Speed apiece. So the numbers below are the Sated EMPTY, and at
-- the bell it reads:
--
--     meals   damage  defense  move  speed
--       3       18      13       1     2      at the bell: a door across the dry line
--       2       15      10       2     3
--       1       12       7       3     4
--       0        9       4       4     5      empty: a large, quick, soft animal that chases
--
-- HOW THE COUNT MOVES, and none of it is read off its health bar (round one's note: "just like lose more"):
--   SPENT    Retch (a bile cone that sets Acid) and Settle (a two-tile heave of the whole body) each cost
--            a meal. Glutted Bulk, its sweep, is free.
--   KNOCKED  a critical hit knocks a meal loose.
--   EATEN    anything, of either side, that dies beside it is eaten and puts one back, to three. A hawk
--            mantling a body that dies beside it is eaten with the body.
--
-- THE COUNTERPLAY, STATED: keep bodies from falling at its feet. Its hawks are its larder, so kill them
-- away from it; do not go down beside it; bring a critical build to empty it on your schedule; and let it
-- spend itself -- every Retch and every Settle leaves it softer.
--
-- FOOTPRINT 2x2, the second body in the game to use it after the ogre. It blocks all four tiles, is struck
-- from beside any of them, and eats an area blast once rather than four times.
--
-- WHAT IT HANDS OVER, shallow to deep: the Retch as a Bombardier's (Bile Sac); the Eat as a Barbarian's
-- (Bottomless Gut); the whole fight turned around as a Bulwark's coat (Distended Girth); a devoured corpse
-- as a Necromancer's (Second Helping); and being full, as a Paladin's (Sated).
return {
    name = "The Sated",
    race = "beast",
    tier = 3,
    boss = true, -- the fight is it: off the execute and Charm tables (tests/charm_balance_spec.lua)
    sprite = "assets/chars/the_sated.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 152, mana = 0, stamina = 30,
        staminaRegen = 3,
        -- EMPTY. Three meals put +9 / +9 / -3 / -3 on top at the bell (status_full).
        damage = 9, magicDamage = 0,
        defense = 4, magicDefense = 5,
        movement = 4,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 4, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   It is fed, and everything it ate is between your blow and anything that matters.
    --   So open it: an edge goes in where a hammer only sinks.
    resist = { impact = 4, slash = -4 },
    startingItems = {
        "weapon_glutted_bulk", "utility_distended_hide", "ability_retch",
        "ability_settle",      false,                    false,
        false,                 false,                    false,
    },
    drops = { "ability_bile_sac", "utility_bottomless_gut", "armor_distended_girth",
              "ability_second_helping", "utility_sated_charm" },
    defaultAction = "weapon_glutted_bulk",
    -- Basic tactics (models/ai.lua): it swings at whatever is in reach, which for a three-wide sweep off
    -- a four-tile body is usually more than one thing. Retch and Settle are planned on their forecasts,
    -- and their meal cost gates them (`usable`), so an empty Sated simply stops reaching for them.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
