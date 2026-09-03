-- UNCOMMON. Trades ACROSS pools rather than within one, so it can never simply net out against a
-- defensive relic the way a damage-for-defense swap can. You act first and you run out sooner, and those
-- are two different fights arriving at two different moments.
--
-- The stamina half is a RULE read at cost-resolution rather than a stat, because "every ability costs
-- more" is not a thing the flat-stat bag can say. See Relic.rules.
return {
    name = "The Quick Draw",
    blurb = "+%d speed for the whole company.",
    tier = "uncommon", mark = "Qd",
    cost = "+%d stamina on every ability.",
    costScale = { 2, 1 },
    scale = { 3, 2 },
    bonus = { speed = 3 },
    bonusStep = { speed = 2 },
    rules = { staminaSurcharge = true },
    ruleScale = { staminaSurcharge = { 2, 1 } },
}
