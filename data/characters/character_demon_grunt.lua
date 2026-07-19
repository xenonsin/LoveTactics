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
    startingItems = { "weapon_iron_sword" },
}
