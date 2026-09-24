-- PATIENT BLADE: one of the Glacier King's own (trait_patient_blade).
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Patient Blade",
    description = "+3 Damage on a turn after one you didn't move.",
    flavor = "It has been ready for some time.",
    sprite = "assets/items/utility_patient_blade.png",
    type = "utility",
    class = "knight",
    unlockLevel = 10,
    unstocked = true,
    tags = { "offensive" },
traits = { "trait_patient_blade" },
}
