-- Encounter blueprint. THE TRANSLATION: you step, and you are somewhere else on this floor.
--
-- Wizardry's teleporter, and the thing that separates it from a door is that it does not tell you. You
-- do not get a prompt, a name, or a moment to decline -- the square looks like every other square until
-- the coordinates on your graph paper stop matching the walls, and then you are lost on a level you had
-- already mapped.
--
-- WHAT IT COSTS is the walk back, which is exactly the currency this mode runs on. A descent has no step
-- budget and no clock, so the only thing distance can take from a company is TIME and the health it
-- spends getting through whatever is between here and there. A translation across a fifteen-hundred-tile
-- warren is the biggest single bill the floor can hand out, and it hands it out for free.
--
-- ONTO GROUND THE COMPANY HAS ALREADY SEEN, and that is a deliberate softening of the reference. An
-- unseen destination is a party dropped into fog beside a fight they cannot read, which is not a
-- surprise but an ambush the board chose -- and this mode already spends its cruelty on permanent death.
-- Landing somewhere known keeps the cost honest: it is the walk, and only the walk.
--
-- `weight = 0`: authored-only. See encounter_dark.lua.
return {
    name = "The Translation",
    kind = "translation",
    weight = 0,
    minDay = 1,
}
