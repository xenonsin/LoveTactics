-- RENOWN: the Elf-Lord's, as a badge (data/traits/trait_renown.lua; 2026-09-30, "Pride's Bestiary"). Every kill an
-- elf of his side makes is told to his credit: +2 Damage and +1 Speed a stack, for the fight. His elves within 3
-- take +1 Damage a stack off it (the trait's presence), so the court grows with the count.
--
-- Capped at 5. The review set no ceiling; five is the Laurel's, and a company of four rarely feeds more.
return {
    name = "Renown",
    abbr = "Rnwn",
    description = "Renown: increases damage by 2 and speed by 1 for each kill told to your credit.",
    color = { 0.860, 0.760, 0.380 }, -- badge tint (laurel gold)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 5,
    statBonus = { damage = 2, speed = 1 },
    statBonusScales = true,
}
