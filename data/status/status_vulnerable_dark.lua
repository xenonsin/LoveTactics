-- Vulnerable: Dark -- the ward against shadow is picked loose, and grief and dark magic pour into the
-- gap. A flat pre-mitigation bonus to any `dark`-tagged hit on the bearer (`vulnerable`, folded into
-- Combat.mitigatedDamage).
--
-- The dark twin of Vulnerable: Holy, and the piece that completes the pair -- both sacred schools now
-- have a matching opener. One tag, on purpose (see status_vulnerable_slash): it asks the party whether
-- it brought anything that bites in the dark -- a dark censer, the demon shelf's kit, a shadow caster.
-- See docs/vulnerability.md for the family.
return {
    name = "Vulnerable: Dark",
    abbr = "Vda",
    description = "Forsaken: takes extra damage from dark attacks.",
    color = { 0.627, 0.455, 0.784 }, -- badge tint (picked-loose violet)
    fx = { field = true },
    duration = 12,
    debuff = true,
    vulnerable = { dark = 8 },
}
