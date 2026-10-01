-- LAURELS: the Laurel of Renown's, as a badge (data/traits/trait_laurel_of_renown.lua; 2026-09-30, "Pride's
-- Bestiary"). The Elf-Lord's Renown in a company's hands, made smaller and shared: a kill by the wearer or any
-- ally lays +1 Damage on the wearer and every ally within 3, up to 5, for the fight.
return {
    name = "Laurels",
    abbr = "Lrls",
    description = "Laurels: increases damage by 1 for each kill your side has made, up to 5.",
    color = { 0.560, 0.700, 0.340 }, -- badge tint (bay leaf)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 5,
    statBonus = { damage = 1 },
    statBonusScales = true,
}
