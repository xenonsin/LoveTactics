-- Resistant: Lightning -- a warded ally sheds the worst of it: a flat pre-mitigation REDUCTION to any
-- `lightning`-tagged hit, expressed as a NEGATIVE `vulnerable` (Status.vulnerability sums the bag, so a
-- resistance is a vulnerability with a minus sign). A BUFF, not a debuff -- a Cure does not strip it; it
-- runs its duration. It FLOORS at 1 like any mitigation and never reaches immunity, which is a different
-- ward (status_immune_lightning). See data/status/status_resistant_fire.lua and docs/vulnerability.md.
return {
    name = "Resistant: Lightning",
    abbr = "Rli",
    description = "Lightning-warded: takes less damage from lightning.",
    color = { 0.902, 0.765, 0.302 }, -- badge tint (lightning's own hue; the abbr marks the state)
    duration = 15,           -- ~3 turns: long enough to sit through the fight it was cast to answer
    vulnerable = { lightning = -8 },
}
