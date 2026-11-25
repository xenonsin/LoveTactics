-- Encounter blueprint. THE HOIST: a basket on a rope, up a shaft to the city (2026-11-24).
--
-- Guaranteed on every floor (models/descent.lua's Descent.sendUpStops, which also makes the floor a stop
-- bigger to seat it) and never rolled: weight 0 keeps it out of the random draw, as the Rest's does.
--
-- WHAT IT IS FOR. The bag has no bottom and a wipe empties it, so a run's haul is a stake that grows
-- with every floor. The hoist sends up to SendUp.HOIST_LIMIT pieces from the bag to the town stash, and
-- then it is spent (models/send_up.lua). One stop, one short list: what out of everything you are
-- carrying is worth making safe now. Leaving without sending keeps it for later on the floor.
return {
    name = "The Hoist",
    kind = "hoist",
    weight = 0,
    depth = 1,
}
