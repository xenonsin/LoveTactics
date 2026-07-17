-- Physical Barrier: a ward that swallows a PHYSICAL blow whole. Unlike Defending (which shaves a flat
-- amount off every physical hit for a while), a barrier negates a hit OUTRIGHT and spends a charge
-- doing so -- Combat.dealFlatDamage consumes it and deals 0 (see Status.barrierAgainst, the read the
-- damage core and the damage preview both make, and Status.consumeBarrier, which bills it). The
-- `negates` field names the school it eats; a magical hit passes straight through a physical barrier.
--
-- It grants no statBonus: its whole effect is the negation, so it must reach the damage core through
-- `negates` rather than flatStat. The duration is a generous window -- the ward is meant to be spent
-- by a blow, not to wear off -- but it can time out if the blow never lands.
--
-- `magnitude` is how many blows it stands for, and it is the only number a ward like this HAS: an
-- effect that negates a hit outright cannot negate it harder, so the sole axis an upgrade can move is
-- coverage. The granting spell tunes it (ability_physical_barrier's `hits` per level) and passes it
-- in; the 1 here is the floor a bare application gets when nobody says otherwise.
return {
    name = "Physical Barrier",
    abbr = "PBar",
    description = "Warded: the next physical attack is negated.",
    color = { 0.70, 0.78, 0.90 }, -- badge tint (steely blue)
    duration = 20, -- ~4 turns at Status.TICKS_PER_TURN, matching the magical barrier
    magnitude = 1, -- blows it swallows before it is spent; the granting spell raises it
    negates = "physical",
}
