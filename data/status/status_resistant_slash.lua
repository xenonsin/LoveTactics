-- Resistant: Slash -- a warded ally sheds the worst of it: a flat pre-mitigation REDUCTION to any
-- `slash`-tagged hit, expressed as a NEGATIVE `vulnerable` (Status.vulnerability sums the bag, so a
-- resistance is a vulnerability with a minus sign). A BUFF, not a debuff -- a Cure does not strip it; it
-- runs its duration. It FLOORS at 1 like any mitigation and never reaches immunity, which is a different
-- ward (status_immune_slash). See data/status/status_resistant_fire.lua and docs/vulnerability.md.
return {
    name = "Resistant: Slash",
    abbr = "Rsl",
    description = "Slash-warded: takes less damage from slash.",
    color = { 0.714, 0.737, 0.776 }, -- badge tint (slash's own hue; the abbr marks the state)
    duration = 15,           -- ~3 turns: long enough to sit through the fight it was cast to answer
    vulnerable = { slash = -4 },
}
