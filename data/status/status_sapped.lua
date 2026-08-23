-- Sapped: the strength is out of the arm. A flat cut to the bearer's Damage for as long as it holds,
-- routed through `magnitudeStat` -- the same fold Defending's +defense and Given Guard's -defense use
-- (Status.statBonus), so it shows as its own signed row in the damage breakdown and needs no machinery
-- of its own.
--
-- HALF OF A PAIR, and the pair is the item. data/items/ability/ability_sap.lua takes exactly this much
-- Damage off the victim and hands exactly this much to the thief as status_stolen_strength, at the same
-- magnitude with the sign flipped and for the same duration. Two statuses rather than one, for the
-- reason the Lent Guard / Given Guard pair gives: both bodies carry a badge that says what happened to
-- them, so the player can read the trade off the board without remembering who swung at whom.
--
-- The magnitude is ALWAYS handed in by the deliverer (Sap caps its theft at what the victim's arm
-- actually holds), so the -4 below is only the fallback for a source that names none.
--
-- A REFRESH REPLACES rather than stacks: Status.apply overwrites `magnitude` on an existing instance,
-- so a second Sap on the same body re-cuts the same arm instead of compounding toward a swordsman who
-- swings for the floor of 1. That ceiling is deliberate and it is where the ability's power stops.
--
-- A DEBUFF, so a Cure lifts it -- and lifts only this half, leaving the thief wearing what it took.
-- The asymmetry is the same one Given Guard documents, and it is left in for the same reason: it costs
-- the party a whole cast to undo one body's share of a theft.
--
-- Not resistible: a cosh to the arm is not an argument, and a warded victim whose half of the ledger
-- ran short while the thief's ran full would be a theft that created strength out of nothing.
return {
    name = "Sapped",
    abbr = "Sapd",
    description = "Strength taken: Damage is lowered while it holds.",
    color = { 0.639, 0.612, 0.451 }, -- badge tint (wrung-out, bloodless olive)
    duration = 12,
    magnitude = -4,
    magnitudeStat = "damage", -- the flat stat this instance's (negative) magnitude moves
    debuff = true,
}
