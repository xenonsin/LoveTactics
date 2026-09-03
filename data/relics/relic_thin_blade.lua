-- UNCOMMON. Two gains for one loss, and the loss is the RUN's currency rather than a combat stat: a
-- lowered ceiling is health no camp gives back, where a point of defense is only ever missing during a
-- fight. That is what makes it a heavier trade than The Keen Edge despite the smaller numbers.
return {
    name = "The Thin Blade",
    blurb = "+%d damage and skill for the whole company.",
    tier = "uncommon", mark = "Tb",
    cost = "-%d maximum health, for the run.",
    costScale = { 8, 6 },
    scale = { 2, 2 },
    bonus = { damage = 2, skill = 2 },
    bonusStep = { damage = 2, skill = 2 },
    maxBonus = { health = -8 },
    maxBonusStep = { health = -6 },
}
