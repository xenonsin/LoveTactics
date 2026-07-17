-- Magical Barrier: the arcane twin of physical_barrier. Swallows a MAGICAL hit whole and spends one
-- of its charges doing so (Combat.dealFlatDamage reads Status.barrierAgainst with the incoming school
-- and deals 0 on a match, then Status.consumeBarrier bills the ward). A physical hit passes straight
-- through it -- the two barriers are deliberately single-school, so covering an ally against both
-- takes both wards.
--
-- `magnitude` is how many blows it stands for, and it is the only number a ward like this HAS: an
-- effect that negates a hit outright cannot negate it harder, so the sole axis an upgrade can move is
-- coverage. The granting spell tunes it (ability_magical_barrier's `hits` per level) and passes it in;
-- the 1 here is the floor a bare application gets when nobody says otherwise.
return {
    name = "Magical Barrier",
    abbr = "MBar",
    description = "Warded: the next magical attack is negated.",
    color = { 0.80, 0.70, 0.92 }, -- badge tint (arcane violet)
    duration = 20, -- ~4 turns at Status.TICKS_PER_TURN: a ward that survives to be tested
    magnitude = 1, -- blows it swallows before it is spent; the granting spell raises it
    negates = "magical",
}
