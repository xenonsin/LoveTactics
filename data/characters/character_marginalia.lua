-- MARGINALIA: Pride's mini sin, and the body that holds the Arcanum's first stair.
--
-- IT REPLACES A BORROWED SLOT. Descent.SINS gave this floor to character_battlemage -- a sound body, and
-- the softest touch in the game for a stratum's centrepiece (18 damage at level 17, measured). A
-- centrepiece should BE the sin one rank down.
--
-- WHAT A MINI SIN IS. A lesser embodiment of the same sin, carrying a cut-down version of its general's
-- rule, which turns up in full at half health:
--
--   from the bell   Answered Once: the FIRST spell aimed at it is unravelled, and no others
--   at 50%          it calls in its rank, which is the other thing a Pride body does
--   ...and Sublimitas deflects every spell she can pay for, on a ten-tick cooldown
--
-- See data/items/utility/utility_marginal_note.lua. Marginalia is the lesser writing beside the real
-- text, in somebody else's hand: named for the object rather than for the mechanic.
--
-- `referenceLevel` because the circles are dealt fresh every run; `boss = true` keeps it off the execute
-- and Charm tables. Health sits between its circle's line body and its general.
return {
    name = "Marginalia",
    kind = "humanoid",
    tier = 4,
    sprite = "assets/chars/marginalia.png",
    referenceLevel = 13,
    boss = true,
    stats = {
        health = 162, mana = 60, stamina = 20,
        staminaRegen = 2,
        damage = 10, magicDamage = 16,
        defense = 9, magicDefense = 14,
        movement = 3,
        speed = 4,
    },
    startingItems = { "weapon_gilded_pike", "utility_marginal_note" },
    defaultAction = "weapon_gilded_pike",
    archetype = "defensive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
