-- Magical Barrier: the arcane twin of physical_barrier. Swallows the next MAGICAL hit whole and is
-- then spent (Combat.dealFlatDamage reads Status.barrierAgainst with the incoming school and deals 0
-- on a match). A physical hit passes straight through it -- the two barriers are deliberately
-- single-school, so covering an ally against both takes both wards.
return {
    name = "Magical Barrier",
    abbr = "MBar",
    description = "Warded: the next magical attack is negated.",
    color = { 0.80, 0.70, 0.92 }, -- badge tint (arcane violet)
    duration = 14,
    negates = "magical",
}
