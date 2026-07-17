-- Smoke Screen: the reaction a Smoke Bomb grants. It declares no hook -- the pre-hit reflex lives in
-- Trait.trySmoke, consulted in Combat.dealFlatDamage BEFORE mitigation (beside the Dodge reflex),
-- which reads these two flags: `blocksNextHit` arms it, `blink` is how many tiles it flings the bearer
-- straight away from the attacker. A once-per-battle charge, latched on the trait's `stacks` (0 -> 1)
-- exactly like Second Wind, so a smoke bomb saves its bearer precisely once.
return {
    name = "Smoke Screen",
    description = "The first attack that would hit you is lost in smoke, and you blink two tiles clear.",
    blocksNextHit = true,
    blink = 2,
}
