-- THE TALLY: Greed's mini sin, and the body that holds the Undercroft's first stair.
--
-- IT REPLACES A BORROWED SLOT. Descent.SINS gave this floor to character_mammonite -- a discipline
-- exemplar standing in for a sin. A stratum's centrepiece should BE the sin one rank down.
--
-- WHAT A MINI SIN IS. A lesser embodiment of the same sin, carrying a cut-down version of its general's
-- rule, which turns up in full at half health:
--
--   from the bell   it takes COIN off what it hits, and is worth more for what you are carrying
--   at 50%          it starts taking gear, which is Aurea's baseline
--   ...and Aurea    lifts an ITEM off an adjacent body from her opening bell
--
-- The lesson is the same either way -- do not stand beside it -- taught first at a price you can survive.
-- See data/items/utility/utility_the_reckoning.lua.
--
-- A tally is a record of what is owed, kept by somebody else: named for the object rather than for the
-- mechanic. `referenceLevel` because the circles are dealt fresh every run; `boss = true` keeps it off
-- the execute and Charm tables.
return {
    name = "The Tally",
    kind = "demon",
    tier = 4,
    sprite = "assets/chars/the_tally.png",
    referenceLevel = 13,
    boss = true,
    stats = {
        health = 176, mana = 40, stamina = 24,
        staminaRegen = 3,
        damage = 14, magicDamage = 10,
        defense = 12, magicDefense = 11,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 6,
    },
    startingItems = { "weapon_cutpurse_nip", "utility_the_reckoning" },
    defaultAction = "weapon_cutpurse_nip",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
