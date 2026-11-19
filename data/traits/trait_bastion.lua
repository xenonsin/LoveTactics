-- Bastion: the bearer's barrier pool does not time out (Engine.grantBarrier reads the `barrierHolds`
-- flag and stretches the pool's clock past the end of any fight). Barricade: what the knight raises, it
-- keeps, until something spends it.
return {
    name = "Bastion",
    description = "Your barrier no longer wears off.",
    barrierHolds = true,
}
