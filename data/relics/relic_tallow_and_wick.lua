-- UNCOMMON. Burn the body to keep the lamp lit: a deeper well of mana for the whole company, paid for
-- with a tenth of every health ceiling.
--
-- THE PRICE IS A SHARE, not a flat figure, so it costs a knight what it costs a mage in proportion --
-- and it is a RULE rather than a negative maxBonus because a share of a ceiling is not a number a bag
-- can add (Combat.unreservedMax applies it, after the Whetted Vow's divisor). Paid once; the mana
-- climbs per copy.
return {
    name = "Tallow and Wick",
    blurb = "+%d maximum mana for the whole company.",
    tier = "uncommon", mark = "Tw",
    cost = "-10% maximum health. (Paid once, however many are held.)",
    scale = { 6, 3 },
    maxBonus = { mana = 6 },
    maxBonusStep = { mana = 3 },
    rules = { maxHealthCut = true },
    ruleScale = { maxHealthCut = { 0.10, 0 } },
}
