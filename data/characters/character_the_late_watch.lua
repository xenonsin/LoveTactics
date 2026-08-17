-- THE LATE WATCH: Sloth's mini sin, and the body that holds the Bastion's first stair.
--
-- IT REPLACES A BORROWED SLOT. Descent.SINS gave this floor to character_forsworn_captain -- a sound
-- body, but a line soldier standing in for a sin. A stratum's centrepiece should BE the sin one rank
-- down.
--
-- WHAT A MINI SIN IS. A lesser embodiment of the same sin, carrying a cut-down version of its general's
-- rule, which turns up in full at half health:
--
--   from the bell   Torpor: ONE pair sworn, on its own turn (data/traits/trait_torpor.lua)
--   at 50%          it braces itself and its line, which is Acedia's Oathkeeper half
--   ...and Acedia   swears the WHOLE party, at the opening bell, before anybody moves
--
-- See data/items/utility/utility_unkept_watch.lua. `referenceLevel` because the circles are dealt fresh
-- every run; `boss = true` keeps it off the execute and Charm tables. Health sits between its circle's
-- line body and its general (Balance.HEALTH_BANDS floors the boss rung at 155).
return {
    name = "The Late Watch",
    kind = "humanoid",
    tier = 4,
    sprite = "assets/chars/the_late_watch.png",
    referenceLevel = 13,
    boss = true,
    stats = {
        health = 168, mana = 20, stamina = 26,
        staminaRegen = 3,
        damage = 13, magicDamage = 8,
        defense = 14, magicDefense = 11, -- it is mostly armour and disinclination
        movement = 3,
        speed = 3,
    },
    startingItems = { "weapon_drift_touch", "utility_unkept_watch" },
    defaultAction = "weapon_drift_touch",
    -- Basic tactics (models/ai.lua): defensive. A body whose second phase is "stop intending to move"
    -- should not be charging in its first.
    archetype = "defensive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
