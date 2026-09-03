-- Per-level stat gains for a body growing on CREATURE kit -- natural weapons and a demon's own art.
-- Applied by models/growth.lua when this is the character's most-used class.
--
-- Flat and unremarkable on purpose. Nothing in the player's company grows here: creature gear is
-- `noSteal` and never reaches a grid, so the only bodies that tally it are the ones swinging their own
-- teeth, and those do not level. This table exists so that the lookup has an answer rather than to
-- shape anything -- see data/classes/creature.lua on why the class exists at all.
return {
    health = 5,
    damage = 2,
    defense = 1,
}
