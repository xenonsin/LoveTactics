-- Burst Lung: the regeneration half of data/injuries/injury_burst_lung.lua. The pool it also reserves is
-- not here -- a reservation rides `char.injuryShare` and Combat.unreservedMax, never a status.
--
-- A POINT, BECAUSE THE STAT IS SMALL. `staminaRegen` is authored at 1-3 across the whole roster (a
-- fighter's is 2), so one point is a third to a half of a body's recovery -- and the floor
-- Injury.combatEffects clamps against (never below a quarter of base, never below 1) is what stops a
-- body that takes this twice arriving at zero, where a stamina weapon simply stops working and the
-- injury has silently become a rule change.
--
-- IT IS THE ONLY THING IN THE SET PRICED AGAINST THE LENGTH OF A FIGHT rather than against a turn, which
-- is why it keeps its own badge instead of folding into Torn Shoulder's: the body swings for exactly
-- what it always did, and runs out sooner.
--
-- See data/status/status_shattered_leg.lua for why `debuff = false`.
return {
    name = "Burst Lung",
    abbr = "Lung",
    description = "Burst Lung: recovers stamina slowly, and cannot fill the pool.",
    color = { 0.373, 0.478, 0.471 }, -- badge tint (cold breath)
    duration = 9999,
    debuff = false,
    statBonus = { staminaRegen = -1 },
}
