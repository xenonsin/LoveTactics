-- Covered in Gold: one stack per coin heap looted by a body carrying Every Hair Covered
-- (data/items/utility/utility_every_hair_covered.lua). +2 Defense a stack for the rest of the fight, no cap --
-- a count, the way Dragon-Sickness is one, and read the same way on the badge.
return {
    name = "Covered in Gold",
    abbr = "Gold",
    description = "Plated in looted gold: increase defense.",
    color = { 0.886, 0.760, 0.345 }, -- badge tint (leaf gold, as Gilded)
    duration = math.huge,
    hideDuration = true, -- the count is the story
    magnitude = 1,
    stacks = 99, -- a count, not a cap
    statBonus = { defense = 2 },
    statBonusScales = true,
}
