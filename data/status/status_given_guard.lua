-- Given Guard: the other half of a Lent Aegis. The bearer has handed their armour to somebody else
-- and is standing there without it -- a NEGATIVE magnitude routed into defense through the same
-- `magnitudeStat` fold that the gift half uses.
--
-- A negative magnitude is unusual in this catalog and entirely intentional: Status.statBonus simply
-- sums whatever it finds, so a debuff expressed this way needs no machinery of its own, and the
-- damage-breakdown tooltip lists it as its own signed line beside every other modifier
-- (Status.statBonusParts). The player sees "Given Guard -10" in the same column as their plate.
--
-- A DEBUFF, so a Cure lifts it -- which is a real and slightly funny interaction: the lender can be
-- cured out of their own generosity while the ally keeps the armour, because the two statuses are
-- genuinely separate instances on separate bodies. That asymmetry is left in on purpose. It costs a
-- cast, and a party that wants to spend a cure that way has earned it.
--
-- Not resistible: you agreed to this.
return {
    name = "Given Guard",
    abbr = "Givn",
    description = "Guard given away: defense is lowered while it holds.",
    color = { 0.58, 0.54, 0.50 }, -- badge tint (bare, unarmoured)
    duration = 12,
    magnitude = -6,
    magnitudeStat = "defense",
    debuff = true,
}
