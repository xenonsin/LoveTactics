-- MIRAGE: Envy's one-off elite of illusions, on the Ribstone Waste's approach ("Envy's Bestiary", round 1). The
-- heat off the sand, given a body and three more that are not there.
--
--   WHICH ONE IS REAL   it fights as four identical bodies. Three are illusions: any blow fells one, and their own
--                       blows land nothing. Once a round, when the real one is struck, it trades places with an
--                       illusion (trait_which_one_is_real; models/envy_oneoffs.lua)
--   THE DESERT'S TELL   illusions weigh nothing, so only the real one is Mired in quicksand
--
-- THE COUNTERPLAY, STATED: area attacks and Limned sort them out, and so does watching who sinks.
--
-- The illusions are Summon.copy doubles, sustained by the real one, so killing it clears the board. Elemental
-- heat: fire turns aside, ice goes in. Tier 3 and `boss`, off the execute and Charm tables like every elite.
return {
    name = "Mirage",
    race = "elemental",
    tier = 3,
    boss = true,
    sprite = "assets/chars/mirage.png",
    stats = {
        health = 96, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 0, magicDamage = 14,
        defense = 5, magicDefense = 7,
        movement = 4,
        speed = 4,
        skill = 6, luck = 6,
    },
    -- Heat given an outline: an edge passes through the shimmer, a blow lands on all of it, and it is fire.
    resist = { fire = 4, ice = -4, slash = 2, impact = -2 },
    startingItems = {
        false,                 false,                       false,
        "weapon_heat_shimmer", "utility_which_one_is_real", false,
        false,                 false,                       false,
    },
    drops = { "ability_mirage_step" },
    defaultAction = "weapon_heat_shimmer",
    archetype = "aggressive",
}
