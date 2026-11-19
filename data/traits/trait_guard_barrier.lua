-- Guard Barrier: a blow the bearer takes FOR an ally (an intercept, Combat.tryRedirect) adds what it took
-- to the bearer's barrier pool (Engine.onGuarded reads the `guardBarrier` flag). The Sentinel's
-- compound of the knight's Rampart: guarding is how a Sentinel builds.
return {
    name = "Guard Barrier",
    description = "A hit you take for an ally adds that much to your barrier.",
    guardBarrier = true,
}
