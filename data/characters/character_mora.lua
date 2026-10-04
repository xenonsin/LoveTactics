-- MORA, THE TOLLKEEPER: Sloth's seat-floor elite ("Sloth's Bestiary", 2026-10-04, slice F; mora is Latin for delay).
-- A 2x2 toll-gate demon, fielded with Toll-Collectors and a Bailiff.
--
--   TOLL OF HOURS  every ability used within 4 of her costs its user its next move as well, so it is Rooted on its
--                  next turn (utility_toll_of_hours, models/toll.lua)
--   SHE NEVER STRIKES  Mora never attacks, only her collectors do: no weapon, and `unarmed = false` so not even a
--                  fist. Her Exit Fee is carried and never collected, for the same reason.
--   PASSAGE PAID   a body that spends a whole turn doing nothing on a gate tile -- any tile edge-on to her -- is let
--                  through and leaves the board safe. If every living body of the company passes, the fight is won
--                  without her falling, but she pays her drop only if she falls
--   EXIT FEE, and WHAT IT WAS OWED, as every Tollkeeper (utility_exit_fee): she lets a Due out when she falls
--
-- THE COUNTERPLAY, STATED: pay or fight. Pay in turns at her gate under her collectors' pikes, or fight through a
-- braced line with every spell you cast costing you a step.
--
-- `boss`, off the execute and Charm tables like every elite; tier 4 by the circle's other seat elites. She holds her
-- ground: a gate does not walk.
return {
    name = "Mora, the Tollkeeper",
    race = "demon",
    tier = 4,
    boss = true,
    sprite = "assets/chars/mora.png",
    footprint = { w = 2, h = 2 },
    unarmed = false,
    stats = {
        health = 180, mana = 0, stamina = 20,
        staminaRegen = 2,
        damage = 0, magicDamage = 0,
        defense = 9, magicDefense = 8,
        movement = 2, -- never spent: she holds her ground (the posture is rooted)
        speed = 3,
        skill = 4, luck = 5,
    },
    resist = { slash = 2, pierce = 2, impact = -4 },
    startingItems = {
        false, "utility_toll_of_hours", false,
        false, "utility_exit_fee",      false,
        false, false,                   false,
    },
    -- HER OWN PIECE (docs/drops.md): the ledger, paid only if she falls (models/toll.lua withholds it otherwise).
    drops = { "utility_toll_ledger" },
    archetype = "holdGround",
}
