-- SEETHING: Wrath's slime rule, as a badge (data/traits/trait_boil_over.lua). Its magnitude IS the Damage
-- it adds; the trait counts the stacks and erupts when it boils over.
return {
    name = "Seething",
    abbr = "Seeth",
    description = "Seething: more Damage with every hit taken, until it boils over.",
    color = { 0.851, 0.325, 0.180 }, -- badge tint (ember)
    duration = math.huge,
    hideDuration = true,
    magnitude = 2,
    magnitudeStat = "damage",
}
