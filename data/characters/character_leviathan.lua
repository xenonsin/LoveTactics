-- LEVIATHAN: Envy's mini boss, on floor 11's stair (reviewed 2026-10-01..03, "Envy's Bestiary"; rows lv_body,
-- lv_under, lv_rise, lv_sea, lv_tail and lv_drops, all approved). A serpent too long to see whole: this is its
-- head, two by two, and the rest of it is under the waste.
--
-- A DEMON, picked over a beast on the review's own framing: Leviathan is the demon prince of Envy in Binsfeld's
-- classification, so it takes holy the harder (data/races/demon.lua) and its bite burns, as every demon's does.
-- `revivable = false` says the other half of that.
--
-- ITS RULE rides on its organ (utility_under_the_sand; a blueprint's own `traits` field is never collected), and
-- models/leviathan.lua argues the cycle: Underground between surfacings; at the end of a turn under, it marks the
-- 3x3 under the Fairest with a Ripple; at the start of the next it rises there -- a heavy blow to every foe in it,
-- everyone shoved out, the 3x3 quicksand for the rest of the fight -- and stays up for a round before it dives.
-- Below half health its tail marks a second 3x3 under the next-Fairest every turn.
--
-- IT FIGHTS OVER A SWARM OF GLASS-MOTES: the stair's filler (Descent.SINS' `minor.filler`, the coordinator's
-- wiring), and the motes are half the rule -- they strip blessings, so they move the mark.
--
-- SIZED AS A LIEUTENANT: tier 4, 220 health, 81% of the general's 271 (the 60-85% band the Pride stair holds
-- Sublimitas to). `referenceLevel` like every stair centrepiece, so these are its numbers on its own floor and
-- a shallower meeting is a smaller it. `boss`, off the execute and Charm tables as every stair body is.
return {
    name = "Leviathan",
    race = "demon",
    tier = 4,
    referenceLevel = 13,
    boss = true,
    revivable = false,
    sprite = "assets/chars/leviathan.png",
    -- FOUR TILES, the Chimera's and Avaritia's footprint: it blocks all four, is struck from beside any of them,
    -- and comes up through a 3x3 with room to spare.
    footprint = { w = 2, h = 2 },
    stats = {
        health = 220, mana = 0, stamina = 30,
        staminaRegen = 5,
        damage = 16, magicDamage = 0,
        defense = 8, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 6, luck = 4,
    },
    -- Scale that turns an edge and takes a club: a redistribution, summing to zero (docs/bestiary.md).
    resist = { slash = 2, impact = -2 },
    startingItems = {
        false, "weapon_leviathan_jaws", false,
        false, "utility_under_the_sand", false,
        false, false, false,
    },
    -- Each stair pays its own pieces (lv_drops): its rising as an elementalist's spell, its wake as a vanguard's
    -- coat. The coordinator's Descent.DROPS.envy.minor pays the same list on its stair.
    drops = { "ability_undertow", "armor_leviathans_wake" },
    defaultAction = "weapon_leviathan_jaws",
    archetype = "aggressive",
}
