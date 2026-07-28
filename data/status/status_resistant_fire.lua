-- Resistant: Fire -- a warded ally sheds the worst of a flame. A flat pre-mitigation REDUCTION to any
-- `fire`-tagged hit on the bearer, expressed as a NEGATIVE `vulnerable` (Status.vulnerability sums the
-- bag, so a resistance is a vulnerability with a minus sign -- the very trick Wet uses for its own
-- `fire = -6`, needing no new field and no new code path).
--
-- The ACTIVE, reactive mirror of the Vulnerable openers. Permanent fire-resistance already lives on
-- armor (the Crucible's Salamander Hide and its kin, via the `resist` tables), but nothing could grant
-- it in the moment -- the turn before the enemy fire mage casts. This is that pre-emptive counter: read
-- the intent telegraph, ward the target of the incoming blast. A BUFF (no `debuff` flag), so a Cure
-- does not strip it; it simply runs its duration. It FLOORS at 1 like any mitigation -- it never reaches
-- immunity, which is a different thing you buy (see status_immune_fire). See docs/vulnerability.md.
return {
    name = "Resistant: Fire",
    abbr = "Rfi",
    description = "Fire-warded: takes less damage from fire.",
    color = { 0.878, 0.541, 0.235 }, -- badge tint (fire's own amber; the abbr marks the state)
    duration = 15,           -- ~3 turns: long enough to sit through the fight it was cast to answer
    vulnerable = { fire = -8 },
}
