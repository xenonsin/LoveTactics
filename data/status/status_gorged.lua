-- GORGED: the Chimera's lion, having eaten one of its own heads (trait_eats_what_is_cut). Sharper for a
-- couple of turns, then settled. Its own status rather than status_enraged, which the review line named:
-- that one is Wrath's battle-long tally of wounds and never cools, and this is a spike that has to end.
return {
    name = "Gorged",
    abbr = "Grg",
    description = "Has just eaten: increase damage by 6.",
    color = { 0.580, 0.400, 0.110 }, -- badge tint (the lion's)
    duration = 10, -- ~2 turns at Status.TICKS_PER_TURN
    statBonus = { damage = 6 },
}
