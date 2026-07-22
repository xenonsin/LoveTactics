-- A lesser demon: the antagonist the prologue introduces, and the step UP from the imps that open
-- the village attack (states/prologue.lua). Where an imp dies to one blow, this takes five between
-- two people -- it is the first thing in the game that has to be fought rather than swatted.
-- The Demon Lord it serves is named in the scene, not met (see docs/story.md).
--
-- ITS 66 HEALTH IS SPENT EXACTLY by the prologue's closing beat, and the whole column is written out
-- in data/tutorials/village.lua (under `spawn`) with tests/tutorial_spec.lua pinning it. The short
-- version: the lesson's last lesson is the turn order, so the grunt has to survive a parry, a mace,
-- and a Jolt still standing and still dangerous -- and then fall to exactly one blow each from Rowan
-- and the player, which is what the Jolt's stun buys them. Re-tune this and that beat stops landing.
--
-- WHICH IS WHY IT IS THE ONE BODY THE HEALTH REBALANCE SKIPPED. Every other character in data/characters/
-- had its pool cut to roughly 0.7 of what it was, to bring the hits-to-kill down across the game; this
-- one could not go with them. Its health is not a balance number at all -- it is the SUM of five
-- authored blows, and the blows did not change, because only health was rescaled. Cut it to 46 with
-- everything else and the choreography kills it on Rowan's second swing, a full beat before the
-- player's own finishing stroke, which is the one thing the whole prologue is built to hand them.
-- So it stays at 66 and is deliberately the sturdiest common enemy in the game. In the siege
-- encounters that field it in packs (data/encounters/encounter_siege_*.lua) that reads as the horde's
-- heavy rather than as an oversight, which is the one place the exemption is actually visible.
return {
    name = "Demon Grunt",
    sprite = "assets/chars/demon_grunt.png",
    stats = {
        health = 66, mana = 0, stamina = 40,
        damage = 8, magicDamage = 0,
        defense = 4, magicDefense = 2,
        movement = 3,
        speed = 2,
    },
    -- Its body IS its weapon, and that weapon is the point of the thing (see the file). It used to
    -- carry a borrowed iron sword, which cost the prologue twice over: a 6-damage swing at a 62-health
    -- avatar is not a reason to spend a whole mana pool delaying its turn, and the sword's Parry came
    -- along with it, so the blows that end the lesson all answered back.
    startingItems = { "weapon_rending_claws" },
    defaultAction = "weapon_rending_claws",
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
