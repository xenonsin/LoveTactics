-- Resistant: Ice -- a warded ally sheds the worst of it: a flat pre-mitigation REDUCTION to any
-- `ice`-tagged hit, expressed as a NEGATIVE `vulnerable` (Status.vulnerability sums the bag, so a
-- resistance is a vulnerability with a minus sign). A BUFF, not a debuff -- a Cure does not strip it; it
-- runs its duration. It FLOORS at 1 like any mitigation and never reaches immunity, which is a different
-- ward (status_immune_ice). See data/status/status_resistant_fire.lua and docs/vulnerability.md.
return {
    name = "Resistant: Ice",
    abbr = "Ric",
    description = "Ice-warded: takes less damage from ice.",
    color = { 0.629, 0.815, 0.899 }, -- badge tint (ice's own hue; the abbr marks the state)
    duration = 15,           -- ~3 turns: long enough to sit through the fight it was cast to answer
    vulnerable = { ice = -4 },
}
