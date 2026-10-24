-- UNCOMMON. The Far Mark backwards: every reach a tile shorter, every aim a good deal truer. A company
-- that has to close to strike, and lands what it swings at when it gets there.
--
-- THE REACH IS THE SAME RULE THE FAR MARK BUYS, signed (`abilityRange`, which sums across sources --
-- Item.SUMMED_RULES), so the two cancel rather than one silently losing. Combat.abilityRange keeps a
-- shortened reach at 1 or more and never inside an ability's own dead zone, so a sword (reach 1) is
-- untouched and a bow keeps the band it can fire in. Paid once; the skill climbs.
return {
    name = "The Narrow Road",
    blurb = "+%d skill for the whole company.",
    tier = "uncommon", mark = "Nr",
    cost = "-1 reach on every ability, never under 1. (Paid once, however many are held.)",
    scale = { 3, 2 },
    bonus = { skill = 3 },
    bonusStep = { skill = 2 },
    rules = { abilityRange = true },
    ruleScale = { abilityRange = { -1, 0 } },
}
