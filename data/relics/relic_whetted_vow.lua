-- RARE. The exception on the rung, and the model the other seven are measured against: BOTH halves are
-- numbers, so both climb. Damage x(1+n), maximum health /(1+n).
--
-- Three copies is a company hitting for quadruple that dies to a stiff breeze. That is legible, it is
-- entirely the player's decision, and it is the clearest single object in the game we borrowed the
-- stacking arithmetic from -- which is exactly why it earns the one slot where the inversion is itself a
-- magnitude.
--
-- Resolves FIRST among the health-pool rares (Relic.RULE_ORDER): maxima are adjusted before anything
-- pools or pins them.
return {
    name = "The Whetted Vow",
    blurb = "The company deals %dx damage.",
    tier = "rare", mark = "Wv",
    -- Both halves are the SAME ladder, so the price says the same number the gain does: x2 damage for
    -- 1/2 the health, x3 for 1/3, x4 for 1/4. Stated as the divisor rather than as "halved again",
    -- which is a rule the player would have to apply themselves to find out what they hold.
    cost = "Maximum health divided by %d.",
    costScale = { 2, 1 },
    scale = { 2, 1 },
    -- ONE NUMBER, DECLARED TWICE, because it is doing two jobs and an implicit second reader would be a
    -- mechanic nobody could find: `halveMaxHealth` is the DIVISOR on the ceiling and `damageMultiplier`
    -- is the multiplier on the blow, and they are deliberately the same ladder -- 2x damage for half the
    -- health, 3x for a third. Both resolve through Relic.resolvedRules; the multiplier composes with the
    -- other relics that carry one, the divisor does not.
    rules = { halveMaxHealth = true, damageMultiplier = true },
    ruleScale = { halveMaxHealth = { 2, 1 }, damageMultiplier = { 2, 1 } },
}
