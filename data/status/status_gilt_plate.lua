-- GILT PLATE: Gilt Plating's two plates (trait_shed_plate). +2 Defense each; an impact blow knocks one
-- off as a coin heap beside the wearer, and walking back over that heap puts the plate back on.
return {
    name = "Gilt Plate",
    abbr = "Gilt",
    description = "Gilt plates: increase defense per plate. An impact blow knocks one off; step on it to put it back.",
    color = { 0.886, 0.760, 0.345 }, -- badge tint (leaf gold)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 2,
    statBonus = { defense = 2 },
    statBonusScales = true,
}
