-- HARRIED: left open by a Scurry (data/traits/trait_scurry.lua). Round 2 (2026-09-25), "Harry": -3 Defense
-- until the next blow lands on it, or about a turn. It is the kobold's hit-and-run handed to the NEXT body
-- in the turn order -- the Skulker steps back, and whoever strikes next finds the guard already down.
--
-- ENDS ON THE NEXT BLOW (onDamaged, which fires for a survivor). The blow that APPLIED it cannot end it:
-- the status lands after that swing has resolved, and Status.onDamaged skips an instance newer than the
-- blow it is hearing about.
return {
    name = "Harried",
    abbr = "Harr",
    description = "Left open: reduce defense until the next blow lands.",
    color = { 0.720, 0.560, 0.380 }, -- badge tint (dust)
    duration = 5, -- ~one turn
    debuff = true,
    statBonus = { defense = -3 },
    onDamaged = function(ctx) ctx.expire() end,
}
