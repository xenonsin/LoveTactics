-- The demon that leads the raiding party on the flight leg -- the capstone the whole tutorial ends on
-- (states/prologue.lua's FLIGHT_QUEST objective, won by `assassinate`: cut the champion down and the
-- fight is over). A step above the Demon Grunt (66 health) and well below the Demon Lord it serves
-- (420, the finale) -- the first foe the game frames as a real BOSS, and the one that asks the player
-- to spend the whole toolkit the road handed them.
--
-- Its fight is THREE STAGES, and they are its relic, not its stats. The Ascendant Sigil
-- (data/items/utility/utility_demon_sigil.lua, bound in the center) carries the data-driven phase
-- system (data/traits/trait_boss_phases.lua) AND the melee counter-guard, and the three stages each
-- pose a distinct problem the road taught an answer to:
--   1  (100-66%)  Warded advance: the Sigil ripostes reckless melee, and it winds up a telegraphed
--                 Cleave down the lane. Answer: the bow from the high ground, and brace / step the Cleave.
--   2  (66-33%)   The Roar: a telegraphed channel that calls self-destruct Bomblets and quickens it.
--                 Answer: Stun or shove to break the channel; AoE to pop the Bomblets at range.
--   3  (33-0%)    The Fixation: fast and enraged, it hunts your softest body. Answer: Taunt it onto the
--                 knight, defang it (Disarm), intercept (Oathward), sustain (Heal), finish (a wall-slam).
-- Heave is a GENERIC throw (data/items/ability/ability_heave.lua) it merely uses -- to lob an adjacent
-- Bomblet at your line -- not a demon-only trick; players can carry the same verb.
--
-- `boss = true` marks it a quest objective: immune to instant execution (Coup de Grace), Charm and
-- Polymorph, so the assassinate win is earned by fighting it down rather than skipped by a finisher.
-- Health is ~115 (up from 92): the fuller toolkit kills 92 before the later stages can read. Reusable
-- as a mid-tier demon boss in later content -- the phase system is all in the Sigil.
return {
    name = "Demon Champion",
    boss = true,
    archetype = "aggressive", -- a slow menace that hunts; explicit for readability
    sprite = "assets/chars/demon_grunt.png",
    stats = {
        health = 115, mana = 0, stamina = 24, -- stamina affords claws + Cleave + repeated Roars
        damage = 14, magicDamage = 0,          -- base; the stage-3 enrage adds up to +20 as it empties
        defense = 8, magicDefense = 4,
        movement = 3,
        speed = 3, -- deliberately slow: the stage-1 kite / brace lesson leans on it
    },
    -- Its loadout as the 3x3 grid (row-major; false = empty). The Sigil is the build-around in the
    -- center (bound, unstealable); the claws and its two abilities sit around it.
    startingItems = {
        "ability_heave", "ability_demon_roar",   "ability_demon_cleave",
        "weapon_great_claws", "utility_demon_sigil", false,
        false,           false,                  false,
    },
    defaultAction = "weapon_great_claws",
    -- Basic tactics (models/ai.lua), top-to-bottom, first match wins:
    ai = {
        -- Stage 2: wind up the Roar whenever the phase system has armed it (status_roaring at 66%).
        { priority = "high", act = "cast", item = "ability_demon_roar",
          when = { subject = "self", test = "has_status", value = "status_roaring" } },
        -- Stage 1: the telegraphed Cleave when a foe is in front of it.
        { priority = "high", act = "cast", item = "ability_demon_cleave",
          when = { subject = "nearest_foe", test = "in_reach" } },
        -- Stage 2+: throw an adjacent Bomblet at whoever it can't reach in melee (the anti-kite answer).
        { priority = "normal", act = "cast", item = "ability_heave",
          when = { subject = "self", test = "has_status", value = "status_roaring" } },
        -- Otherwise (and enraged in stage 3) press the softest body. Taunt overrides this via AI.preempt.
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
