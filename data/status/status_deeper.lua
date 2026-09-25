-- DEEPER: delving deeper, literally. Each Delve this fight (data/items/ability/ability_delve.lua) adds
-- one: +1 Damage, to three. It lasts the fight, so a delver left alone keeps coming up harder, and the
-- answer is the round it surfaces.
return {
    name = "Deeper",
    abbr = "Dpr",
    description = "Each Delve this fight: increase damage.",
    color = { 0.470, 0.390, 0.300 }, -- badge tint (turned earth, as Underground)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 3,
    statBonus = { damage = 1 },
    statBonusScales = true,
}
