-- WHO WRATH'S FAMILIES GO FOR (2026-11-19, the creature identity pass, its targeting half).
--
-- The audit found that only 2 of Wrath's 53 bodies carried an AI rule (the Arc and the Redcap), so every other
-- body chose its mark by the posture's default scoring: bodies on this circle differed in WHAT they did, never in
-- WHO they chose. This module is one preference per FAMILY, each from the planner's closed vocabulary
-- (AI.TARGET_PREF_ORDER) and each read off the family's own theme, so that a company that has met one oni or one
-- orc can predict who the next one walks at:
--
--   ONI        MARKED, else NEAREST. The clan converges on whatever its Shadow threaded (Steel Thread lays Mark),
--              and with nothing marked an oni faces whoever stands before it and does not walk past them.
--              The Horn's avenging and the Witch's Taint still come first (AI.preempt): this is what is left.
--   ORCS       LETHAL. An orc is Proven by a kill, so it goes for the blow that finishes somebody.
--   GOBLINS    HEMMED. A warband piles onto the body with the fewest open tiles round it -- the one in the
--              corridor, the one backed into a corner. Blood Feud still comes first (AI.preempt).
--   ASURA      CHANNELLING. A monk reads the breath: whoever is winding up a cast is the one it strikes.
--   VAMPIRES   LOWEST HEALTH, the faintest pulse (Scent of Blood already pulls the brood toward the bleeding:
--              movement and damage, models/thirst.lua). The brood's thrall and its bats ride with it.
--   ELEMENTALS NEAREST, as the Arc already was: fire and lightning take what is closest.
--
-- One rule each, at the NORMAL band, with no gate: a preference is a bias (+AI.WEIGHTS.TARGET_PREF), never a
-- filter, so a lethal blow on somebody else still wins and a family whose preferred mark is absent simply plays
-- the posture's own attack. Gated rules sit at HIGH where the gate says the mark is on the board.
--
-- LEFT WITHOUT ONE, on purpose: the SUPPORT bodies (the Oni Priestess, the War-Drummer, the Blood-Caller, the
-- Communicant), because an attack rule at the normal band would outrank their posture's heal; the bodies a model
-- already steers outright (the Minotaur's Labyrinth, the War Ogre's chain, the Goblin Fanatic's unsteered spin);
-- the Blood Basin, which is a prop; the Arc and the Redcap, whose authored rules already make sense; and the two
-- slimes, which belong to another pass.
--
-- Shared tables: AI.rulesFor never writes through a rule (it carries the resolved item beside it), so one table
-- per family is safe to hand to every blueprint in it.
local T = {}

T.oni = {
    { priority = "high", act = "attack", targetPref = "marked",
      when = { subject = "any_foe", test = "has_status", value = "status_mark" } },
    { act = "attack", targetPref = "nearest", when = { subject = "any_foe", test = "exists" } },
}

T.orc = {
    { act = "attack", targetPref = "lethal", when = { subject = "any_foe", test = "exists" } },
}

T.goblin = {
    { act = "attack", targetPref = "hemmed", when = { subject = "any_foe", test = "exists" } },
}

T.asura = {
    { act = "attack", targetPref = "channeling", when = { subject = "any_foe", test = "exists" } },
}

T.vampire = {
    { act = "attack", targetPref = "lowest_hp", when = { subject = "any_foe", test = "exists" } },
}

T.elemental = {
    { act = "attack", targetPref = "nearest", when = { subject = "any_foe", test = "exists" } },
}

-- Which family every Wrath body that carries one belongs to, for tests/identity_wrath_spec.lua to hold the
-- blueprints to this table rather than to a list typed out a second time.
T.FAMILIES = {
    oni = { "character_oni_general", "character_oni_student", "character_oni", "character_oni_greatblade",
            "character_oni_shadow", "character_oni_swordmaster", "character_oni_horned_twin",
            "character_oni_hornless_twin" },
    orc = { "character_orc_grunt", "character_orc_veteran", "character_orc_spear_hurler", "character_orc_berserker",
            "character_orc_pit_fighter", "character_orc_beast_handler", "character_orc_warchief" },
    goblin = { "character_goblin_cutter", "character_goblin_hexer", "character_goblin_brute",
               "character_goblin_firebrand", "character_goblin_sapper", "character_goblin_wolf_rider",
               "character_hobgoblin", "character_goblin_king", "character_bugbear" },
    asura = { "character_asura_acolyte", "character_asura_adept", "character_asura_three_faced",
              "character_asura_agyo", "character_asura_ungyo", "character_general_wrath" },
    vampire = { "character_blood_ghoul", "character_familiar", "character_swarm_familiar", "character_fledgling",
                "character_goblin_fledgling", "character_vampire_duelist", "character_hemomancer", "character_the_sire",
                "character_the_blood_countess", "character_the_gorged" },
    elemental = { "character_blaze" },
}

return T
