-- Immune: Impact -- for a short breath, impact simply does not land. Declares `immune = { impact = true }`, which
-- Status.immuneToDamage reads and Combat.mitigatedDamage / Combat.dealFlatDamage honour by voiding any
-- `impact`-tagged hit to a true 0 -- before armor, before resist, before the raw path, and without spending
-- anything (unlike a barrier). The categorical cousin of Resistant: Impact, and deliberately NOT reachable
-- by stacking it: resistance floors at 1 (a scratch is still a hit), immunity is the true 0. A short,
-- premium BUFF. See data/status/status_immune_fire.lua and docs/vulnerability.md.
return {
    name = "Immune: Impact",
    abbr = "Iim",
    description = "Impact-sealed: impact damage is voided entirely for a short time.",
    color = { 0.788, 0.604, 0.388 }, -- badge tint (impact's own hue; the abbr marks the state)
    duration = 6,            -- ~1 turn: the answer to a telegraphed blow, gone before it is a stance
    immune = { impact = true },
}
