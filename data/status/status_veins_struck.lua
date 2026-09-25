-- VEINS STRUCK: how many times this fight Veinfinder has been used. Twice a fight is the whole allowance
-- (round 1); the ability's `usable` reads the count.
return {
    name = "Veins Struck",
    abbr = "Vein",
    description = "Veinfinder has been used this many times this fight (twice at most).",
    color = { 0.760, 0.620, 0.300 },
    duration = math.huge,
    hideDuration = true,
    hideLog = true,
    magnitude = 1,
    stacks = 2,
}
