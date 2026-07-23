-- Lent Guard: somebody else's armour, worn for a while. A flat defense bonus whose size the granting
-- item decides (`magnitudeStat`, the same routing Defending's +defense uses -- see Status.statBonus).
--
-- Half of a pair, and the pair is the item: this is what the ally gains, and status_given_guard is the
-- identical debuff the lender wears for the same duration at the same magnitude with the sign flipped.
-- Two statuses rather than one, so both bodies carry a badge that says what happened to them -- the
-- player can read the trade off the board without remembering who cast what.
--
-- Not resistible and not a debuff: it is a gift, and a gift the recipient's own magic defense argued
-- with would be a strange thing indeed.
return {
    name = "Lent Guard",
    abbr = "Lent",
    description = "Wearing somebody else's guard: defense is raised while it holds.",
    color = { 0.72, 0.78, 0.90 }, -- badge tint (borrowed steel)
    duration = 12,
    magnitude = 6,
    magnitudeStat = "defense", -- routes the instance's magnitude straight into the defense fold
}
