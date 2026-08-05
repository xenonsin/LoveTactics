-- Smoke Screen: the reaction a Smoke Bomb grants. It declares no hook -- the pre-hit reflex lives in
-- Trait.trySmoke, consulted in Combat.dealFlatDamage BEFORE mitigation (beside the Dodge reflex),
-- which reads these two flags: `blocksNextHit` arms it, `blink` is how many tiles it flings the bearer
-- straight away from the attacker.
--
-- How MANY times it answers is not the trait's business but the granting item's, and Trait.trySmoke
-- reads it off there: a consumable stack (the bomb) spends one of itself per escape, so the crate is
-- the charge count; anything else (the Smokecloth Wrap, an innate or relic copy) gets one latched
-- charge for the battle, like Second Wind.
return {
    name = "Smoke Screen",
    description = "An attack that would hit you is lost in smoke, and you blink two tiles clear.",
    blocksNextHit = true,
    blink = 2,
}
