-- FLAWLESS FORM: Superbia's perfection, and the rule Perfect Plate carries (reviewed over three rounds, "Pride's
-- Generals"). No single blow takes more than `woundCap` of the bearer's max health -- a tenth for her, a quarter
-- through the plate (its `traitParams`).
--
-- A FLAG AND NOTHING ELSE. Combat.dealFlatDamage clamps the wound past the crit, and Combat.computeDamage clamps
-- the hover the same way (models/morning_star.lua's woundCap), so the number quoted is the number taken. What it
-- answers is the burst: she is killed in ten blows or more, whoever throws them.
return {
    name = "Flawless Form",
    description = "No single blow can take more than a tenth of your max health.",
    woundCap = 0.1,
}
