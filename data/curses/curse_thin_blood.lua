-- THIN BLOOD: everything lands a little deeper than it should.
--
-- A NEGATIVE `resist`, which is the vulnerability axis rather than the armour one -- docs/vulnerability.md
-- states the split: `resist` is per-tag and pre-mitigation, and a negative one is a weakness. Three
-- against a reference blow of about nine (Grade.turnValue at Grade.PRESTIGE) is a third again on every
-- physical hit the bearer takes: enough to move the arithmetic on whether a body survives the turn,
-- nowhere near the -8 that doc records as having turned a resistance into an immunity when the same
-- number was pointed the other way.
--
-- `physical` RATHER THAN A DAMAGE FAMILY, because the bearer is a body and not a puzzle. A hex that only
-- bit against fire would be inert on nine floors out of fifteen and lethal on the tenth, which reads as
-- the rift being unfair rather than as the piece being cursed.
return {
    name = "Thin Blood",
    description = "-2 defense, and physical blows land 3 harder on the bearer.",
    binds = true,
    depth = 5,
    fee = 180,
    bonus = { defense = -2 },
    resist = { physical = -3 },
}
