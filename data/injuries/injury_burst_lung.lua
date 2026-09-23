-- BURST LUNG: the body can still do everything it could -- just not as often.
--
-- A point off Stamina regeneration and a fifth of the stamina pool reserved. Every other injury in the
-- set is priced against the TURN; this one is priced against the fight, and it is the only thing in the
-- system that makes a long fight cost more than a short one.
--
-- A POINT IS HALF OF WHAT A FRONT-LINER REGENERATES (a fighter's `staminaRegen` is 2), which is why it
-- is only a point: the stat is small, authored at 1-3 across the roster, and the floor at a quarter of
-- base catches a body that takes this twice before the number reaches zero and a weapon stops working
-- altogether.
--
-- IT ROLLS ONTO ANYBODY, including a body with no stamina worth losing, and that was a decision rather
-- than an oversight -- the design review denied a `fits` gate on the roll. So the 6% health reserve
-- below is not decoration: it is what stops a mage's Burst Lung being a roll that cost nothing, which
-- would read as a bug rather than as luck. Every kind takes something from every body.
return {
    name = "Burst Lung",
    description = "Burst Lung: recovers stamina slowly, and cannot fill the pool.",
    severity = 1,
    weight = 8,
    reserve = { health = 0.06, stamina = 0.20 },
    effects = { { id = "status_burst_lung" } },
}
