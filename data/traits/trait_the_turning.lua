-- THE TURNING: the Ophan's compulsion (reviewed 2026-09-30, "Pride's Bestiary"). A wheel does not decide to turn.
-- With a foe beside it the Ophan strikes every adjacent tile with its wheel and does nothing else (models/choir.lua,
-- read from AI.preempt); with none, it rolls toward one. The flag names the weapon it turns with.
--
-- A rule for the AI only, so it binds no body the company drives.
return {
    name = "The Turning",
    description = "With a foe beside it, it strikes every adjacent tile, every turn.",
    turns = "weapon_wheel_of_eyes",
}
