-- Vulnerable: Impact -- the stance is cracked and never resets, so every following hammer-fall lands
-- on a body that cannot brace. A flat pre-mitigation bonus to any `impact`-tagged hit on the bearer
-- (`vulnerable`, folded into Combat.mitigatedDamage exactly as Frozen's brittleness is).
--
-- One tag on purpose (see status_vulnerable_slash for the argument). Until this, impact was amplified
-- ONLY while a target was Frozen -- so a mace or a hammer could never set up its own follow-up without
-- an ice mage standing by. This unbundles the brittleness from the freeze: the blunt line rewards
-- stacking impact on its own terms now. The blunt tag is `impact`, not `crush` (see status_freeze for
-- why that split was collapsed). See docs/vulnerability.md for the family.
return {
    name = "Vulnerable: Impact",
    abbr = "Vim",
    description = "Guard cracked: takes extra damage from impact hits.",
    color = { 0.788, 0.604, 0.388 }, -- badge tint (struck bronze)
    fx = { field = true },
    duration = 12,
    debuff = true,
    vulnerable = { impact = 8 },
}
