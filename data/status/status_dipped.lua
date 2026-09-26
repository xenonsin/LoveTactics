-- DIPPED: the Dipped Cap is wet (data/traits/trait_dipped_cap.lua). The next strike on a foe below half health is
-- a certain critical (Combat.forcesCrit), and that landing spends it. It dries off after about five turns unused.
return {
    name = "Dipped",
    abbr = "Dip",
    description = "The next strike on a foe below half health is a certain critical.",
    color = { 0.690, 0.110, 0.130 }, -- badge tint (wet red)
    duration = 25,
}
