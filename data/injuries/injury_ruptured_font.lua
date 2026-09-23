-- RUPTURED FONT: the caster's half of Torn Shoulder.
--
-- Three points off Magic Damage and a quarter of the mana pool sealed away. Without it the whole set is
-- priced against front-liners and a mage's injuries are all somebody else's -- a body that never swings
-- does not care what its Damage says, and Cracked Ribs is the only one of the other six that reaches it
-- at all.
--
-- THE MANA RESERVE IS THE HEAVIER HALF, deliberately. A mage's problem is rarely the size of the blow
-- and always how many of them there are before the pool is empty, so a quarter off the ceiling is what
-- a caster actually feels -- and it rides the same reservation machinery the health band does
-- (Combat.unreservedMax), so nothing new had to be taught to the pools.
--
-- ROLLS ONTO ANYBODY, gate denied at review -- see data/injuries/injury_burst_lung.lua for the whole of
-- that argument and why the health reserve is what keeps it honest on a body with five mana.
return {
    name = "Ruptured Font",
    description = "Ruptured Font: casts for less, and cannot fill the pool.",
    severity = 2,
    weight = 7,
    reserve = { health = 0.06, mana = 0.25 },
    effects = { { id = "status_ruptured_font" } },
}
