-- Immune: Holy -- for a short breath, holy simply does not land. Declares `immune = { holy = true }`, which
-- Status.immuneToDamage reads and Combat.mitigatedDamage / Combat.dealFlatDamage honour by voiding any
-- `holy`-tagged hit to a true 0 -- before armor, before resist, before the raw path, and without spending
-- anything (unlike a barrier). The categorical cousin of Resistant: Holy, and deliberately NOT reachable
-- by stacking it: resistance floors at 1 (a scratch is still a hit), immunity is the true 0. A short,
-- premium BUFF. See data/status/status_immune_fire.lua and docs/vulnerability.md.
return {
    name = "Immune: Holy",
    abbr = "Iho",
    description = "Holy-sealed: holy damage is voided entirely for a short time.",
    color = { 0.910, 0.816, 0.541 }, -- badge tint (holy's own hue; the abbr marks the state)
    duration = 6,            -- ~1 turn: the answer to a telegraphed blow, gone before it is a stance
    immune = { holy = true },
}
