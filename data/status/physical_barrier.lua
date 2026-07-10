-- Physical Barrier: a ward that swallows the next PHYSICAL blow whole. Unlike Defending (which
-- shaves a flat amount off every physical hit for a while), a barrier negates ONE hit outright and
-- is then spent -- Combat.dealFlatDamage consumes it and deals 0 (see Status.barrierAgainst, the
-- read the damage core and the damage preview both make). The `negates` field names the school it
-- eats; a magical hit passes straight through a physical barrier.
--
-- It grants no statBonus: its whole effect is the negation, so it must reach the damage core through
-- `negates` rather than flatStat. The duration is a generous window -- the ward is meant to be spent
-- by a blow, not to wear off -- but it can time out if the blow never lands.
return {
    name = "Physical Barrier",
    abbr = "PBar",
    description = "Warded: the next physical attack is negated.",
    color = { 0.70, 0.78, 0.90 }, -- badge tint (steely blue)
    duration = 14,
    negates = "physical",
}
