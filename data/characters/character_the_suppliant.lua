-- THE SUPPLIANT: Lust's mini sin, and the body that holds the Cathedral's first stair.
--
-- IT REPLACES A BORROWED SLOT. Descent.SINS gave this floor to character_inquisitor -- a discipline
-- exemplar standing in for a sin. A stratum's centrepiece should BE the sin one rank down.
--
-- WHAT A MINI SIN IS. A lesser embodiment of the same sin, carrying a cut-down version of its general's
-- rule, which turns up in full at half health:
--
--   from the bell   The Unasked: it drains whoever ENDED THEIR TURN having spent nothing
--   at 50%          it drains regardless, which is Luxuria's baseline
--   ...and Luxuria  drains every hit, unconditionally, from her opening bell
--
-- The gate is what makes the lesson learnable: a player can see which of their units it fired on and
-- work backwards to why. Hold a turn and you are drained; spend and you are not. See
-- data/items/utility/utility_offered_nothing.lua.
--
-- She is the Unbidden -- the one who was never asked. This one asks: named for the office rather than
-- for the mechanic. `referenceLevel` because the circles are dealt fresh every run; `boss = true` keeps
-- it off the execute and Charm tables.
return {
    name = "The Suppliant",
    kind = "demon",
    tier = 4,
    sprite = "assets/chars/the_suppliant.png",
    referenceLevel = 13,
    boss = true,
    stats = {
        health = 180, mana = 60, stamina = 22,
        staminaRegen = 3,
        damage = 11, magicDamage = 15,
        defense = 10, magicDefense = 14,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 6,
    },
    startingItems = { "weapon_petal_touch", "utility_offered_nothing" },
    defaultAction = "weapon_petal_touch",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
