-- Brimming: healing the bearer casts that goes past full becomes barrier on the body it was cast on
-- (Engine.overheal reads the `overhealBarrier` flag; the barrier is the pooled amount the knight's
-- Rampart also builds). No heal is wasted: a priest topping up a full ally is raising a shield.
return {
    name = "Brimming",
    description = "Healing past full becomes barrier on the healed ally.",
    overhealBarrier = true,
}
