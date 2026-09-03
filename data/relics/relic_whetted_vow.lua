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
    -- THE DIVISOR IS THE RULE; THE SHARE IS WHAT THE PLAYER READS. "Maximum health divided by 3" is the
    -- mechanic stated exactly, and it is still arithmetic the player has to do before this card can be
    -- compared with any other price on the shelf -- every one of which is already a straight figure off
    -- a stat. So the line says the same ladder as the share it takes: 50% at one copy, 67% at two, 75%
    -- at three.
    --
    -- A share of a pool the divisor keeps shrinking does NOT climb in a straight line, so this is the
    -- one ladder on the shelf authored as a function rather than as { base, step } -- 100 - 100/(1+n),
    -- the exact inverse of the divisor in `ruleScale` below.
    cost = "-%d%% maximum health.",
    costScale = function(n) return math.floor(100 - 100 / (1 + n) + 0.5) end,
    scale = { 2, 1 },
    -- ONE NUMBER, DECLARED TWICE, because it is doing two jobs and an implicit second reader would be a
    -- mechanic nobody could find: `halveMaxHealth` is the DIVISOR on the ceiling and `damageMultiplier`
    -- is the multiplier on the blow, and they are deliberately the same ladder -- 2x damage for half the
    -- health, 3x for a third. Both resolve through Relic.resolvedRules; the multiplier composes with the
    -- other relics that carry one, the divisor does not.
    rules = { halveMaxHealth = true, damageMultiplier = true },
    ruleScale = { halveMaxHealth = { 2, 1 }, damageMultiplier = { 2, 1 } },
}
