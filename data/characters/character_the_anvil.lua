-- THE ANVIL: Wrath's mini sin, and the body that holds the Colosseum's first stair.
--
-- IT REPLACES A BORROWED SLOT. Descent.SINS gave this floor to character_champion -- a real, correctly
-- built body carrying a Demon Sigil with two authored phases, and the worked example in
-- trait_boss_phases. It stays in the circle as Ira's lieutenant would have been and stays the authoring
-- pattern; it simply stops standing in for a sin. A stratum's centrepiece should BE the sin, one rank
-- down, rather than an arena fighter who happens to be nearby.
--
-- WHAT A MINI SIN IS. A lesser embodiment of the same sin, carrying a cut-down version of its general's
-- rule, which turns up in full at half health:
--
--   from the bell   Kindling: +2 damage a blow taken, stopping at 12
--   at 50%          the cap comes off and the missing-health curve arrives -- Ira's baseline
--
-- See data/items/utility/utility_cold_forge.lua. An anvil is a thing that exists to be struck and is
-- improved by it: named for the object rather than for the mechanic, which is how the whole tier is
-- named.
--
-- `referenceLevel` because the circles are dealt fresh every run, so these numbers are what it is at the
-- depth it was written for and Growth scales them DOWN toward the shallows. `boss = true` keeps it off
-- the execute and Charm tables. Health sits near 60% of a general (they run 266-327).
return {
    name = "The Anvil",
    kind = "demon",
    tier = 4,
    sprite = "assets/chars/the_anvil.png",
    referenceLevel = 13,
    boss = true,
    stats = {
        health = 174, mana = 0, stamina = 28,
        staminaRegen = 3,
        damage = 13, magicDamage = 0, -- it opens SOFT. Everything it becomes, you did to it
        defense = 13, magicDefense = 8,
        movement = 3,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 6,
    },
    startingItems = { "weapon_cinder_brand", "utility_cold_forge" },
    defaultAction = "weapon_cinder_brand",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
