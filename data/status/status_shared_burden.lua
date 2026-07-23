-- Shared Burden: a bond. Half of every wound this unit takes is borne by whoever swore it instead
-- (Combat.shareBurden, run just past mitigation in the damage core) -- wherever in the field that
-- swearer happens to be standing.
--
-- The runtime instance carries `.bonded`, the unit on the other end, stamped by the ability that
-- swore it (the same way Shout stamps `.taunter` onto a Taunt). Without one the status does nothing at
-- all, which is the correct behaviour for a promise nobody made.
--
-- Distance is deliberately not a condition. The knight's other guard verbs -- Oathward, Martyr's Vow
-- (data/traits/) -- are both ADJACENCY: they buy an ally's safety with the knight's body, and a body
-- has to be standing there. A bond is the version that survives the line breaking, and that is exactly
-- what makes it worth an ability slot next to two traits that do something similar for free. The price
-- of the reach is that the knight cannot parry, dodge or armor its half away: the toll lands raw
-- (see Combat.shareBurden), so a bond spread over a fragile knight is a way to lose two units.
--
-- A BUFF on the warded unit -- Cure will not strip it, and the ward does not get to refuse the gift.
-- It ends on its own duration, or the moment the swearer falls.
return {
    name = "Shared Burden",
    abbr = "Bnd",
    description = "Bonded: half of every wound taken is borne by the one who swore it.",
    color = { 0.72, 0.76, 0.88 }, -- badge tint (pale steel)
    duration = 30, -- ~6 turns at Status.TICKS_PER_TURN: a promise with a fight's worth of life in it
    sharesDamage = 0.5,
}
