-- THE HIGHWING: the wyvern line's elite, and the one that can STAY up there and only lands to kill.
-- A rung-2 spare of the wood (encounter_the_high_glade, billed beside the Sow and the Stag in
-- Descent.SINS); the Sated stays the seat's named elite.
--
-- THE LINE, each rung the one below plus one sentence:
--   Wyvern         it keeps its distance, and it comes down only for whoever stands alone
--   Alpha Wyvern   ...and the whole flight rides its wind
--   The Highwing   ...and it can stay up there, and only lands to kill
--
-- WHAT THE RUNG ADDS is High Wind (status_high_wind): three turns riding high -- still on the board and
-- still a target, unlike Take Wing's hiding, but +30 Avoid on top of its Tailwind, a tile more on its
-- Wind Shear, and no Root takes. It comes down in a Stoop (ability_stoop) cast straight out of the wind,
-- the line's dive without the wind-up; and it carries the whole line besides, Lead the Wind included, so
-- the escort flies in its wind.
--
-- ITS ANSWER is to aim well while it is up (Mark cuts Luck, and Luck is Avoid), to keep the company in
-- pairs so the dive finds nobody to lift, and to be ready for the turn it lands. 1x1, not 2x2: every
-- lift-and-land in models/stoop.lua is written for one tile, and the seat already stands two wide bodies.
--
-- THE DEVIATION FROM THE REVIEW, stated: High Wind was approved as ending "in a forced Stoop". The line's
-- dive is forced by being a wind-up; this one is cast from inside the wind, and nothing in the engine can
-- make a body spend a turn it has not started. So the Highwing stoops when its planner finds a body worth
-- it (the forecast only pays on a lone mark), and otherwise the wind simply drops it when the three turns
-- run out.
return {
    name = "The Highwing",
    race = "beast",
    tier = 3,
    boss = true, -- off the execute and Charm tables, as the wood's other elites
    sprite = "assets/chars/the_highwing.png",
    stats = {
        health = 112, mana = 0, stamina = 28,
        staminaRegen = 4,
        damage = 17, magicDamage = 0,
        defense = 7, magicDefense = 6,
        movement = 6,
        speed = 6,
        skill = 6, luck = 8,
    },
    resist = { slash = 4, impact = -4, wind = 4 },
    startingItems = {
        "weapon_wind_shear",       "ability_take_wing",       "ability_high_wind",
        "ability_stoop",           "utility_tailwind",        "utility_lead_the_wind",
        "utility_manticore_wings", "utility_feral_instinct",  false,
    },
    -- Its takeoff as a person's escape, and its carry as the chase. Shallow to deep.
    drops = { "ability_skyward", "ability_bear_away" },
    defaultAction = "weapon_wind_shear",
    archetype = "skirmish",
    ai = {
        { priority = "high", act = "cast", item = "ability_high_wind",
          when = { subject = "self", test = "lacks_status", value = "status_high_wind" } },
        { priority = "high", act = "cast", item = "ability_stoop",
          when = { subject = "self", test = "has_status", value = "status_high_wind" } },
        { priority = "high", act = "cast", item = "ability_take_wing",
          when = { subject = "nearest_foe", test = "within", value = 1 } },
    },
}
