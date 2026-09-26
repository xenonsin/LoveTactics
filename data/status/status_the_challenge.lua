-- THE CHALLENGE: the orc Pit-Fighter's rule (data/traits/trait_the_blood_ring.lua). He takes half damage from
-- every body but his challenger -- the company body with the most health, named again each turn he ends. The
-- instance's `exempt` is the challenger (Status.damageTakenScale).
return {
    name = "The Challenge",
    abbr = "Chlg",
    description = "Takes half damage from everyone but its challenger.",
    color = { 0.720, 0.560, 0.200 }, -- badge tint (arena sand)
    duration = math.huge,
    hideDuration = true,
    damageTakenScaleExcept = 0.5,
}
