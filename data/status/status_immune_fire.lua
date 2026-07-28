-- Immune: Fire -- for a short breath, fire simply does not land. Declares `immune = { fire = true }`,
-- which Status.immuneToDamage reads and Combat.mitigatedDamage / Combat.dealFlatDamage honour by voiding
-- any `fire`-tagged hit to 0 outright -- before armor, before resist, before the raw path, and without
-- spending anything (unlike a barrier, which eats a charge).
--
-- The CATEGORICAL cousin of Resistant: Fire, and deliberately not reachable by stacking it. Resistance
-- is a subtraction that floors at 1 -- a scratch is still a hit, so it still counters, still feeds
-- Rimebitten, still wakes a sleeper -- and no pile of it ever reaches a true 0. Immunity is the true 0,
-- and it is bought as its own thing: a brief, premium ward for the one big elemental blow, not a stance
-- you live in. It is a BUFF (no `debuff` flag) and stays SHORT on purpose -- that window IS the balance,
-- not the mechanic. See docs/vulnerability.md for the whole matrix.
return {
    name = "Immune: Fire",
    abbr = "Ifi",
    description = "Fireproof: fire damage is voided entirely for a short time.",
    color = { 0.878, 0.541, 0.235 }, -- badge tint (fire's own amber; the abbr marks the state)
    duration = 6,            -- ~1 turn: the answer to a telegraphed nuke, gone before it is a stance
    immune = { fire = true },
}
