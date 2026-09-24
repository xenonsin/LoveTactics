-- OWED: what the Usurer's Scale writes on a foe (data/traits/trait_usurers_scale.lua). Each stack is one
-- more point of damage from every blow, physical or magical, up to six -- the debt compounds for as long
-- as the same body keeps being hit.
return {
    name = "Owed",
    abbr = "Owe",
    description = "In debt: takes 1 more damage from every hit for each stack.",
    color = { 0.811, 0.700, 0.335 }, -- badge tint (coin gold, greed's colour)
    duration = 15,
    debuff = true,
    magnitude = 1,
    stacks = 6,
    hideDuration = true,
    vulnerable = { physical = 1, magical = 1 },
    vulnerableScales = true,
}
