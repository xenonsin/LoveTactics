-- STONE PLATE: an Earth Golem's slabs (trait_shed_plate). Three to begin, +2 Defense each, and a blow of
-- weight knocks one off into a rubble wall beside it (round 1, "Shed Plate"). A bare golem is soft.
return {
    name = "Stone Plate",
    abbr = "Plate",
    description = "Slabs of rock: increase defense per plate. An impact blow knocks one off as rubble.",
    color = { 0.560, 0.540, 0.500 }, -- badge tint (quarried stone)
    duration = math.huge,
    hideDuration = true, -- the count is the story
    magnitude = 1,
    stacks = 3,
    statBonus = { defense = 2 },
    statBonusScales = true,
}
