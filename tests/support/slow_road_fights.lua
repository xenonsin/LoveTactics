-- THE ROAD FIGHTS THAT ARE NOT QUICK, with the number each one actually measures.
--
-- tests/skirmish_spec.lua's "an ordinary road fight is over quickly" holds every `kind = "combat"`
-- encounter to SKIRMISH_TURN_BUDGET. This is the recorded debt: the fights that do not meet it, each
-- pinned at what it measures today. It is a RATCHET, not a waiver -- a listed fight may get faster and
-- may not get slower, and the moment one drops under the budget the spec tells you to delete its row.
--
-- WHY THERE ARE TWENTY-FOUR OF THEM, AND WHY NOBODY KNEW. The case was green for a long time while
-- measuring almost nothing. It built ONE company and marched it through all thirty-eight ordinary
-- encounters back to back on a single health bar -- so the company was destroyed somewhere around the
-- second fight, and every encounter after that "resolved" in one or two unit-turns because there was
-- nobody left to fight it. Instrumented, the list read: 20, 23, 1, 1, 1, 1, ... The budget was being
-- met by a corpse.
--
-- Two things fell out of that, and the second is what surfaced it. Every number past the second fight
-- was noise; and the FIRST fight in id order was the only one measured honestly -- so authoring a new
-- encounter that sorted ahead of an old one silently moved the old one's result. Adding
-- encounter_bear (which sorts before encounter_boar) took the BOAR from 22 unit-turns to 23 without a
-- line of the boar changing, and the failure named the boar. That is what sent anyone looking.
--
-- THE BUDGET WAS RIGHT ALL ALONG, which is the happy half of this. Measured honestly, every plain road
-- animal is inside it -- boar 19, bear 20, wolf 20, wolf pack 20, sounder 19, stag 17, carrion 13-14.
-- The case is named "an ordinary road fight" and ordinary road fights pass it. What is listed below is
-- almost entirely CIRCLE and WARBAND content, which is set-piece material wearing the same `kind`
-- label as roadside stock. Whether the honest fix is to shorten these fights or to stop calling them
-- ordinary is a design question this file deliberately does not answer -- it only refuses to let the
-- answer be "nobody noticed".
--
-- THE THREE AT 400 ARE A DIFFERENT KIND OF ENTRY. 400 is Autobattle.run's own cap, so those fights did
-- not merely run long -- they did not resolve at all. No budget accommodates that, and they are the
-- rows to look at first. They are recorded here rather than left as a hard failure so the debt is
-- visible and bounded rather than blocking; that is a filing decision, not a verdict that they are
-- acceptable.
--
-- Measured 2026-09-19 at day 20, level 11, forest, one freshly built company per fight and the RNG
-- pinned per fight -- so re-running reproduces these exactly. Regenerate by printing `turns` in the
-- spec's loop; do not hand-edit a number upward to make a build pass.
--
-- ONE NUMBER HAS BEEN RAISED SINCE, and this is the argument for it, written here rather than left as
-- a nudge. THE ASSAY went 54 -> 64 on 2026-09-20, when models/ai.lua learned to score a status landed
-- on its own side (AI.WEIGHTS.BUFF). Before that a buff cast scored a flat 0 outcome and was refused
-- by the planner's own gate, so THE MAMMONITE'S SIGNATURE HAD NEVER ONCE BEEN CAST -- The Open Account
-- soaks each wound out of that body's 300-gold coffer at five coins a point, which is sixty points of
-- flesh it was authored to have and had never had. Two mammonites open the account twice between them
-- and the fight is ten unit-turns longer, because the enemy is finally as hard as its own data says.
-- That is not the decay this ratchet is here to catch; it is a set-piece that was being measured with
-- one of its bodies half switched off. The fight is still too long for the label it wears, and it was
-- already on this list for that reason -- see the header's note about warband content wearing the
-- `combat` tag.
return {
    -- Did not resolve inside Autobattle.run's 400-turn cap. Look here first.
    encounter_warband_beast_line    = 400,
    encounter_pride_the_colours     = 400,
    encounter_pride_the_rank        = 400,

    -- Resolves, but nowhere near an ordinary stop.
    encounter_warband_broken_column = 143,
    encounter_sloth_standing_watch  = 110,
    encounter_rival_company         = 77,
    encounter_gluttony_overstayed   = 57,
    encounter_warband_the_assay     = 64, -- was 54; see the header -- the mammonite's coffer ward started working
    encounter_pride_cited           = 53,
    encounter_warband_the_writ      = 50,
    encounter_warband_press_gang    = 41,
    encounter_greed_undercut        = 38,
    encounter_the_herd              = 37,
    encounter_envy_second_draught   = 36,
    encounter_ogre                  = 33,
    encounter_wrath_grudge          = 31,
    encounter_wyrmling_brood        = 29,
    encounter_wrath_ember_line      = 29,
    encounter_warband_the_summoning = 27,
    encounter_greed_the_assay       = 27,
    encounter_wrath_forge_pit       = 26,
    encounter_greed_the_chitters    = 24,
    encounter_lust_the_choir        = 24,
    encounter_sloth_the_sleepers    = 24,
}
