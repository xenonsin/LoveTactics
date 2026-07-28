-- Immune: Pierce -- for a short breath, pierce simply does not land. Declares `immune = { pierce = true }`, which
-- Status.immuneToDamage reads and Combat.mitigatedDamage / Combat.dealFlatDamage honour by voiding any
-- `pierce`-tagged hit to a true 0 -- before armor, before resist, before the raw path, and without spending
-- anything (unlike a barrier). The categorical cousin of Resistant: Pierce, and deliberately NOT reachable
-- by stacking it: resistance floors at 1 (a scratch is still a hit), immunity is the true 0. A short,
-- premium BUFF. See data/status/status_immune_fire.lua and docs/vulnerability.md.
return {
    name = "Immune: Pierce",
    abbr = "Ipi",
    description = "Pierce-sealed: pierce damage is voided entirely for a short time.",
    color = { 0.769, 0.345, 0.431 }, -- badge tint (pierce's own hue; the abbr marks the state)
    duration = 6,            -- ~1 turn: the answer to a telegraphed blow, gone before it is a stance
    immune = { pierce = true },
}
