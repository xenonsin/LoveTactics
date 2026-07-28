-- Vulnerable: Fire -- the body is slicked with oil, and fire bites far deeper for it. A flat
-- pre-mitigation bonus to any `fire`-tagged hit on the bearer (`vulnerable`, folded into
-- Combat.mitigatedDamage exactly as Wet's lightning weakness is -- and as the exact INVERSE of Wet's
-- own `fire = -6`, which resists it).
--
-- The clean read-forwards of the Rain-then-Jolt combo the game already loves: douse a cluster, then
-- torch it. The magnitude runs a little higher than the physical openers (10 against 8) because it is
-- the one delivered by a thrown consumable that does no damage of its own -- the whole payload is what
-- the fire mage lands next. One tag, the argument for which is in status_vulnerable_slash. See
-- docs/vulnerability.md for the family.
return {
    name = "Vulnerable: Fire",
    abbr = "Vfi",
    description = "Oil-slicked: takes extra damage from fire.",
    color = { 0.878, 0.541, 0.235 }, -- badge tint (kindling amber)
    fx = { field = true },
    duration = 12,
    debuff = true,
    vulnerable = { fire = 10 },
}
