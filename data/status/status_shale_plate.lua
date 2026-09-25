-- SHALE PLATE: what Shale Plating grows on its wearer each fight (trait_shed_plate). Three plates, +1
-- Defense each; an impact blow sheds one as a rubble wall behind the wearer. Grows back between fights.
return {
    name = "Shale Plate",
    abbr = "Shale",
    description = "Plates of shale: increase defense per plate. An impact blow sheds one as rubble behind you.",
    color = { 0.470, 0.470, 0.500 }, -- badge tint (slate)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 3,
    statBonus = { defense = 1 },
    statBonusScales = true,
}
