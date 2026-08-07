-- Resistant: Pierce -- a warded ally sheds the worst of it: a flat pre-mitigation REDUCTION to any
-- `pierce`-tagged hit, expressed as a NEGATIVE `vulnerable` (Status.vulnerability sums the bag, so a
-- resistance is a vulnerability with a minus sign). A BUFF, not a debuff -- a Cure does not strip it; it
-- runs its duration. It FLOORS at 1 like any mitigation and never reaches immunity, which is a different
-- ward (status_immune_pierce). See data/status/status_resistant_fire.lua and docs/vulnerability.md.
return {
    name = "Resistant: Pierce",
    abbr = "Rpi",
    description = "Pierce-warded: takes less damage from pierce.",
    color = { 0.769, 0.345, 0.431 }, -- badge tint (pierce's own hue; the abbr marks the state)
    duration = 15,           -- ~3 turns: long enough to sit through the fight it was cast to answer
    vulnerable = { pierce = -4 },
}
